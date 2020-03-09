#!/usr/bin/env ruby
# Thank you to https://github.com/zfletch/ncurses-chat-rb for helping with the curses

require 'ncurses'
require 'socket'
require 'tty'

require_relative 'lib/protocol'
require_relative 'lib/world'


def interpret(three, connected, msg)
  draw_room(three, connected)
  msg
end

# draws the users in the room
def draw_room(three, connected, start = 0)
  three.clear
  three.border(*([0] * 8))
  three.wrefresh
  width = (three.getmaxx - 4)
  top = 1
  start.upto(three.getmaxy - 4) do |i|
    three.wmove(top, 2)
    if connected[i]
      three.addstr(connected[i])
    else
      break
    end
    top += 1
  end
  three.wrefresh
end

# control the cursor and return the line of input when the
# user presses 'enter'
def read_line(y, x, window = Ncurses.stdscr, max_len = (window.getmaxx - x - 1), string = '', cursor_pos = 0)
  window.clear
  window.border(*([0] * 8))
  loop do
    window.mvaddstr(y, x, string)
    window.move(y, x + cursor_pos)
    ch = window.getch
    case ch
    when Ncurses::KEY_LEFT
      cursor_pos = [0, cursor_pos - 1].max
    when Ncurses::KEY_RIGHT
      cursor_pos = [string.size, cursor_pos + 1].min
    when Ncurses::KEY_ENTER, "\n".ord, "\r".ord
      cursor_pos = 0
      return string
    when Ncurses::KEY_BACKSPACE, 127
      string = string[0...([0, cursor_pos - 1].max)] + string[cursor_pos..-1]
      cursor_pos = [0, cursor_pos - 1].max
      window.mvaddstr(y, x + string.length, ' ')
    when Ncurses::KEY_DC
      string = cursor_pos == string.size ? string : string[0...([0, cursor_pos].max)] + string[(cursor_pos + 1)..-1]
      window.mvaddstr(y, x + string.length, ' ')
    when 0..255 # remaining printables
      if string.size < (max_len - 1)
        string[cursor_pos, 0] = ch.chr
        cursor_pos += 1
      end
    when Ncurses::KEY_UP
      # needs to be implemented, moves the screen up
    else
      #Ncurses.beep
    end
  end
end


def write_all(window, max, bottom, disp, start)
  width = (window.getmaxx - 4)
  i = start
  carry = 0
  carry_print = []
  max.times do
    if disp[i].size > width
      carry_print << (disp[i][(carry...(carry + width))])
      if (disp[i].size - carry) > width
        carry = carry + width
        next
      else
        carry_print.reverse.each do |p|
          window.wmove(bottom, 2)
          window.addstr p
          bottom -= 1
        end
        i = (i == disp.size - 1) ? 0 : i + 1
        carry = 0
        carry_print = []
        next
      end
    end
    window.wmove(bottom, 2)
    window.addstr(disp[i])
    i = (i == disp.size - 1) ? 0 : i + 1
    bottom -= 1
  end
  carry_print.reverse.each do |p|
    window.move(bottom, 2)
    window.addstr p
    bottom -= 1
  end
end


def draw_windows(server, disp, start, connected)
  top = Ncurses::WINDOW.new(3, Ncurses.COLS, 0, 0)
  one = Ncurses::WINDOW.new(Ncurses.LINES - 6, Ncurses.COLS - 30, 3, 0)
  two = Ncurses::WINDOW.new(3, 0, Ncurses.LINES - 3, 0)
  three = Ncurses::WINDOW.new(Ncurses.LINES - 6, 0, 3, Ncurses.COLS - 30)

  one.border(*([0] * 8))
  two.border(*([0] * 8))
  three.border(*([0] * 8))
  top.border(*([0] * 8))
  Ncurses.leaveok(one, true)
  one.nodelay(true)
  two.nodelay(true)
  top.nodelay(true)
  two.move(1, 2)
  three.wrefresh

  status = Array.new
  status[0] = 'Welcome'

  Thread.new do
    loop do
      write_all(one, Ncurses.LINES - 5, Ncurses.LINES - 8, disp, start)
      write_all(top, 1, 1, status, 0)
      two.move(1, 2)
      one.border(*([0] * 8))
      one.wrefresh
      top.wrefresh
      one.clear

      type = server.recv(1).unpack('C*')[0]

      case type
      when 1 # Message
        pm = Lurk::Message.read(server)
        msg = "@#{pm.sender.strip} <- #{pm.msg.strip}"
      when 7 # error
        error = Lurk::Error.read(server)
        msg = "<> ERROR <> (#{error.code}) #{error.msg.strip}"
      when 8 # Server ACK
        response = Lurk::Accept.read(server)

        if response.action == 10
          $world.creation_mode = false
        end
        $world.last_accepted_command = response.action
        msg = ""
      when 9 # Room
        room = Lurk::Room.read(server)
        connected.clear
        $world.room = room.number
        $world.room_name = room.name.strip
        # connected.clear
        msg = ">>>>> As you enter [#{room.name.strip}] the room appears to be #{room.desc.strip}"
      when 10 # Characters
        char = Lurk::Character.read(server)
        if char.health > 0
          char_status = "♥️  #{char.health}"
        else
          char_status = "💀 "
        end

        if (char.monster == 1)
          $world.monsters[char.name.strip] = char
          connected << "(#{char_status}) [M]#{char.name.strip}"
        else
          $world.players[char.name.strip] = char
          connected << "(#{char_status}) #{char.name.strip} "
        end
        if char.name.strip == $world.name
          $world.health = char.health
          $world.me = char
          $world.gold = char.gold
          $world.attack = char.attack
          $world.defense = char.defense
          $world.regen = char.regen
          $world.alive = char.alive
          $world.ready = char.ready
          $world.monster = char.monster
          $world.started = char.started
          $world.autojoin = char.join_battles
        end

        msg = ""
      when 11 # Initial Game
        $world.game = Lurk::Game.read(server)
        msg = "#{$world.game.desc.strip}"
        start = 1
      when 13 # Connection
        conn = Lurk::Connection.read(server)
        msg = "You notice a path to [#{conn.name.strip}](##{conn.number}) it appears to be #{conn.desc.strip}"
      when 14 # Version
        $world.version = Lurk::Version.read server

        msg = "Lurk v#{$world.version.major}.#{$world.version.minor} #{"- Extensions: #{$world.version.extensions}" if $world.version.extensions}"
      else
        msg = ""
      end

      $world.update_hud
      status[0] = $world.hud
      if msg == ""
        connected.uniq!
        draw_room(three, connected)
      else
        connected.uniq!
        start = (start == 0) ? (disp.size - 1) : start - 1
        disp[start] = interpret(three, connected, msg)
      end
    end
  end

  two.keypad(true)

  loop do
    inp = read_line(1, 2, two)
    # next unless $world.started?
    if $world.creation_mode
      stat_limit = $world.game.stat_allowed

      prompt = TTY::Prompt.new

      loop do
        name = prompt.ask(" Name?")
        if name && (name.length > 0 && name.length < 32)
          $world.name = name
          break
        end
      end

      $world.autojoin = prompt.yes?("Auto Join Battle?")
      loop do
        attack = prompt.ask("Attack Power out of #{stat_limit} allowed?", default: 50, convert: :int)
        if attack && (attack <= stat_limit && attack >= 0)
          $world.attack = attack
          stat_limit -= attack
          break
        end
      end
      loop do
        defense = prompt.ask("Defense out of #{stat_limit} allowed?", default: 50, convert: :int)
        if defense && (defense <= stat_limit && defense >= 0)
          $world.defense = defense
          stat_limit -= defense
          break
        end
      end
      loop do
        regen = prompt.ask("Regeneration rate out of #{stat_limit} allowed?", default: 0, convert: :int)
        if regen && (regen <= stat_limit && regen >= 0)
          $world.regen = regen
          break
        end
      end

      $world.desc = prompt.ask("Description?", default: $world.name)
      $world.create_char()
    else
      if (target = inp.match(/goto (.*)/))
        $world.goto(target[1].to_i)
      elsif (target = inp.match(/cd (.*)/))
        $world.goto(target[1].to_i)
      elsif (name = inp.match(/login (.*)/))
        $world.create_char(login = true, name = name[1].strip)
      elsif (target = inp.match(/pvp (.*)/))
        $world.pvp(target[1].strip)
      elsif (target = inp.match(/loot (.*)/))
        $world.loot(target[1].strip)
      elsif inp == 'start'
        $world.start
      elsif inp == 'quit' || inp == 'exit'
        $world.quit
        break
      elsif inp == 'attack' || inp == 'fight' || inp == 'a'
        $world.fight
      elsif inp == 'create'
        $world.creation_mode = true
      elsif inp == 'test'
        $world.name = 'manwar'
      elsif (message = inp.match(/wall (.*)/))
        $world.players.each do |_, v|
          next if v.name.strip == $world.name.strip
          $world.pm(v.name.strip, message[1])
        end
      elsif inp == 'refresh'
        $world.update_hud
        top.wrefresh
        two.wrefresh
        connected = Array.new
        $world.monsters.each do |k, v|
          next unless v.room == $world.room
          if v.health > 0
            mon_status = "♥️  #{v.health}"
          else
            mon_status = "💀 "
          end
          connected << "(#{mon_status}) [M]#{k}"
        end
        $world.players.each do |k, v|
          next unless v.room == $world.room
          if v.health > 0
            pstatus = "♥️  #{v.health}"
          else
            pstatus = "💀 "
          end
          connected << "(#{pstatus}) #{k}"
        end
        draw_room three, connected
      elsif inp == 'debug'
        $world.name = "Lio"
        $world.attack = 50
        $world.defense = 50
        $world.regen = 50
        $world.desc = "Lio"
        $world.create_char()
      elsif inp == 'reconnect'
        server = $world.reconnect
      elsif (m = inp.match(/@(\w{1,32}) (.*)/))
        $world.pm(m[1], m[2])
      end
    end
  end
end

begin
  # initialize ncurses
  Ncurses.initscr
  Ncurses.cbreak
  Ncurses.noecho
  Ncurses.start_color

  # Setup the connection
  prompt = TTY::Prompt.new

  # Prompt for information
  remote_hostname = prompt.ask('What server do you want to connect to?', default: 'isoptera.lcsc.edu')
  remote_port = prompt.ask('What port is lurk running on?', default: 5190)


  $world = World.new
  server = $world.connect(remote_hostname, remote_port)

  disp = [''] * 500
  start = 0
  connected = Array.new

  draw_windows(server, disp, start, connected)

ensure
  Ncurses.endwin rescue ''
end


#!/usr/bin/env ruby
# Thank you to https://github.com/zfletch/ncurses-chat-rb for helping with the curses

require 'ncurses'
require 'socket'
require 'optparse'


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
  # one = Ncurses::WINDOW.new(Ncurses.LINES - 3, Ncurses.COLS - 12, 0, 0)
  # two = Ncurses::WINDOW.new(3, 0, Ncurses.LINES - 3, 0)
  # three = Ncurses::WINDOW.new(Ncurses.LINES - 3, 0, 0, Ncurses.COLS - 12)
  top = Ncurses::WINDOW.new(3,Ncurses.COLS,0,0)
  one = Ncurses::WINDOW.new(Ncurses.LINES - 6, Ncurses.COLS - 12, 3, 0)
  two = Ncurses::WINDOW.new(3, 0, Ncurses.LINES - 3, 0)
  three = Ncurses::WINDOW.new(Ncurses.LINES - 6, 0, 3, Ncurses.COLS - 12)

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

  Thread.new do
    loop do
      statusbar = Array.new
      status = statusbar[0]
      # hac << 't'
      # write_all(one, Ncurses.LINES - 5, Ncurses.LINES - 5, disp, start)
      write_all(one, Ncurses.LINES - 5, Ncurses.LINES - 8, disp, start)
      write_all(top, 1, 1, statusbar, start)
      two.move(1, 2)
      one.border(*([0] * 8))
      one.wrefresh
      top.wrefresh
      one.clear

      type = server.recv(1).unpack('C*')[0]

      if type == 2
        sender = server.recv(32).strip
        length = server.recv(2).unpack('S')[0]
        content = server.recv(length)
        msg =  "#{sender} -> #{content}"
      elsif type == 5
        puts 'PM incomming'
        length = server.recv(2).unpack('S')[0]
        recipient = server.recv(32).strip
        sender = server.recv(32).strip
        content = server.recv(length).strip
        msg = "(#{sender}) <- #{content}"
      elsif type == 4
        msg =  'Username in use'.red
      elsif type == 3
        sender = server.recv(32).strip
        connected.delete sender
        puts "#{sender} has left the channel"
      elsif type == 1
        sender = server.recv(32).strip
        connected << sender
        msg = "#{sender} has joined the channel"
      end



      # start = (start == 0) ? (disp.size - 1) : start - 1
      start = (start == 0) ? (disp.size - 1) : start - 1
      disp[start] = interpret(three, connected, msg)
    end
  end

  two.keypad(true)
  @username = 'liothen'
  loop do
    inp = read_line(1, 2, two)

    if (@login = inp.match(/\/login (\w{1,32})/))
      server.write [1].pack('C')
      server.write @login[1].to_s.ljust(32, "\0")
      @username = @login[1]
    elsif inp == '/quit'
      server.write [3].pack('C')
      server.write @username.ljust(32, "\0")
      break
    elsif inp == '/reconnect'
      server = TCPSocket.open(options[:hostname], options[:port])
    elsif (m = inp.match(/@(\w{1,32}) (.*)/))
      puts "send pm"
      pm = m[2].to_s
      recipient = m[1].to_s
      server.write [5].pack('C')
      server.write [pm.length + 1].pack('S')
      server.write recipient.ljust(32, "\0")
      server.write @username.ljust(32, "\0")
      server.write pm + "\0"
    else
      server.write [2].pack('C')
      server.write @username.ljust(32, "\0")
      server.write [inp.length].pack('S')
      server.write inp
      # puts "test"
    end
  end
end

begin

  options = {
      :hostname => 'localhost',
      :port => '9281',
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
    opts.on('-h', '--hostname HOSTNAME', 'Hostname to connect to (defaults to localhost)') { |h| options[:hostname] = h }
    opts.on('-p', '--port PORT', 'Port to connect to (defaults to 9281)') { |p| options[:port] = p }
    opts.on('-n', '--nick NICK', 'Nick name to use (if left blank, you can choose on login)') { |n| options[:nick] = n }
    opts.on('--help', 'Show this message') { puts opts; exit }
    opts.parse!
  end

  # initialize ncurses
  Ncurses.initscr
  Ncurses.cbreak
  Ncurses.noecho

  server = TCPSocket.open(options[:hostname], options[:port])
  server.puts options[:nick] if options[:nick]

  disp = [''] * 500
  start = 0
  connected = []

  draw_windows(server, disp, start, connected)

ensure
  Ncurses.endwin rescue ''
end


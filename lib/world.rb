ACTION = %w{void Message ChangeRoom Fight PVP LOOT Start Error Accept Room Character Game Leave Connection Version}

class World
  attr_accessor :version
  attr_accessor :game
  attr_accessor :remote_hostname
  attr_accessor :remote_port
  attr_accessor :creation_mode
  attr_accessor :started
  attr_accessor :hud


  # User
  attr_accessor :name
  attr_accessor :attack
  attr_accessor :defense
  attr_accessor :regen
  attr_accessor :health
  attr_accessor :gold
  attr_accessor :desc

  attr_accessor :room
  attr_accessor :room_name

  attr_accessor :available_rooms

  attr_accessor :last_accepted_command

  # Me
  attr_accessor :me

  # Auto Join Battles
  attr_accessor :autojoin
  attr_accessor :ready
  attr_accessor :monster
  attr_accessor :started
  attr_accessor :alive

  # players
  attr_accessor :players
  attr_accessor :monsters

  @server = TCPSocket


  def initialize
    self.players = Hash.new
    self.creation_mode = false
    self.name = "Default"
    self.me = Lurk::Character.new
    self.monsters = Hash.new
    self.health = 0
    self.room = 0
    self.room_name = "The Void"
    self.available_rooms = Hash.new
    self.gold = 0
    self.last_accepted_command = 0
    self.autojoin = 0
    self.alive = 0
    self.ready = 0
    self.monster = 0
    self.started = 0
    # self.game = Lurk::Game.new
    # self.game.stat_allowed = 0
  end

  def connect(hostname, port)
    @server = TCPSocket.open(hostname, port)
    self.remote_hostname = hostname
    self.remote_port = port
    return @server
  end

  def reconnect
    @server = TCPSocket.open(self.remote_hostname, self.remote_port)
    return @server
  end

  def quit
    @server.write [12].pack('C')
  end

  def pm(recipient, msg)
    recipient = recipient[0..30]
    @server.write [1].pack('C')
    @server.write [msg.length + 1].pack('S')
    @server.write recipient.ljust(32, "\0")
    @server.write self.name.ljust(32, "\0")
    @server.write msg + "\0"
  end

  def create_char(login = false, name=nil)
    if login
      self.name = name
      self.attack = 50
      self.defense = 50
      self.autojoin = true
      self.regen = 0
      self.desc = name
    end


    @server.write [10].pack('C')
    @server.write self.name.ljust(32, "\0")
    if self.autojoin
      @server.write [255].pack('C')
    else
      @server.write [0].pack('C')
    end
    @server.write [self.attack].pack('S')
    @server.write [self.defense].pack('S')
    @server.write [self.regen].pack('S')
    @server.write [100].pack('s') #health
    @server.write [0].pack('S') #gold
    @server.write [0].pack('S') #room
    @server.write [self.desc.length + 1].pack('S')
    @server.write self.desc + "\0"
  end

  def start
    @server.write [6].pack('C')
    self.started = true
  end

  def loot(target)
    target = target[0..30]
    @server.write [5].pack('C')
    @server.write target.ljust(32, "\0")
  end

  def pvp(target)
    target = target[0..30]
    @server.write [4].pack('C')
    @server.write target.ljust(32, "\0")
  end

  def fight
    @server.write [3].pack('C')
  end

  def goto(room)
    @server.write [2].pack('C')
    @server.write [room].pack('S')
  end

  def update_hud
    if self.players.key?(self.name)
      self.me = self.players[self.name]
      self.health = self.me.health
      self.gold = self.me.gold
    end
    if self.health < 1
      status = "💀"
    else
      status = "#{self.health}♥️"
    end

    # self.hud = "#{self.name} #{status} | #{self.attack}⚔️️ | #{self.defense}🛡 | #{self.regen}♻️ | $#{self.gold}" \
    #            " | Current Room: (#{self.room})#{self.room_name} | ACK #{ACTION[self.last_accepted_command].ljust(25, " ")}"
    #
    self.hud = "👨🏻#{self.name} #{status} "\
               " | #{self.attack}🥋  | #{self.defense}🛡  | #{self.regen}♻️  | $#{self.gold}"  \
               " | 🏘  Current Room: (#{self.room})[#{self.room_name}]" \
               " | Flags A:#{"❣️" if self.alive == 1}  B:#{"✅" if self.autojoin == 1}  "\
                  "M:#{"🐒" if self.monster == 1}  S:#{"🚗" if self.started == 1}  R:#{"👍" if self.ready == 1}"  \
               " | ACK: #{ACTION[self.last_accepted_command].ljust(25, " ")}"
  end
end

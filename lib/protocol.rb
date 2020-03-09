# frozen_string_literal: true
require 'bindata'

module Lurk
  # Ignore the first byte for record type

  class Game < BinData::Record
    endian :little

    uint16 :stat_allowed
    uint16 :stat_limit
    uint16 :len
    string :desc, read_length: :len
  end

  class Version < BinData::Record
    endian :little

    uint8 :major
    uint8 :minor
    uint16 :ext_len
    string :extensions, read_length: :ext_len
  end

  class Message < BinData::Record
    endian :little

    uint16 :len
    string :recipient, read_length: 32
    string :sender, read_length: 32
    string :msg, read_length: :len
  end

  class Error < BinData::Record
    endian :little

    uint8 :code
    uint16 :len
    string :msg, read_length: :len
  end

  class Accept < BinData::Record
    endian :little

    uint8 :action
  end

  class Room < BinData::Record
    endian :little

    uint16 :number
    string :name, read_length: 32
    uint16 :desc_len
    string :desc, read_length: :desc_len
  end

  class Character < BinData::Record
    endian :little

    string :name, read_length: 32
    bit1 :alive
    bit1 :join_battles
    bit1 :monster
    bit1 :started
    bit1 :ready
    bit1 :reserved1
    bit1 :reserved2
    bit1 :reserved3
    uint16 :attack
    uint16 :defense
    uint16 :regen
    int16 :health
    uint16 :gold
    uint16 :room
    uint16 :desc_len
    string :desc, read_length: :desc_len
  end

  class Connection < BinData::Record
    endian :little

    uint16 :number
    string :name, read_length: 32
    uint16 :desc_len
    string :desc, read_length: :desc_len
  end

end





# class Lurk
#   @server = TCPSocket
#   @username = ''
#
#   def msg(recipient, msg)
#     @server.write [1].pack('C')
#     @server.write [msg.length].pack('S')
#     @server.write recipient.ljust(32, "\0")
#     @server.write @username.ljust(32, "\0")
#     @server.write msg
#   end
#
#   def fight!
#     @server.write [3].pack('C')
#   end
#
#   def changeroom(room)
#     @server.write [2].pack('C')
#     @server.write [room].pack('S')
#   end
#
#   def pvp(player)
#     @server.write [4].pack('C')
#     @server.write player.ljust(32, "\0")
#   end
#
#   def loot(entity)
#     @server.write [4].pack('C')
#     @server.write entity.ljust(32, "\0")
#   end
#
#   def start!
#     @server.write [6].pack('C')
#   end
#
#   def new_character(name, attack, defense,regen, description)
#     @server.write [10].pack('C')
#     @server.write name.ljust(32, "\0")
#     #flags
#     @server.write [attack].pack('C')
#     @server.write [defense].pack('C')
#     @server.write [regen].pack('C')
#     @server.write [100].pack('C') # Health
#     @server.write [0].pack('C') # gold
#     @server.write [0].pack('C') #room
#     @server.write [description.length + 1].pack('S')
#     @server.write description
#   end
#
# end

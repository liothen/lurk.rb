#!/usr/bin/env ruby
# Thank you to https://github.com/zfletch/ncurses-chat-rb
#
require 'socket'
require 'optparse'
require 'colorize'

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
me = 'Liothen'
server = TCPSocket.open(options[:hostname], options[:port])

server.puts options[:nick] if options[:nick]

Thread.new do
  loop do
    # puts server.recv(1).to_i
    type = server.recv(1).unpack('C*')[0]
    if type == 2
      sender = server.recv(32).strip
      length = server.recv(2).unpack('S')[0]
      msg = server.recv(length)
      puts "#{sender.green} -> #{msg}"
    elsif type == 5
      length = server.recv(2).unpack('S')[0]
      recipient = server.recv(32).strip
      sender = server.recv(32).strip
      msg = server.recv(length).strip
      puts "(#{sender.yellow}) <- #{msg}"
    elsif type == 4
      puts 'Username in use'.red
    elsif type == 3
      sender = server.recv(32).strip
      puts "#{sender} has left the channel".red
    elsif type == 1
      sender = server.recv(32).strip
      puts "#{sender} has joined the channel".red
    end
  end
end

loop do
  inp = STDIN.gets.chomp

  # server.puts inp

  if (username = inp.match(/\/login (\w{1,32})/))
    server.write [1].pack('C')
    server.write username[1].ljust(32, "\0")
  elsif inp == '/quit'
    server.write [3].pack('C')
    server.write me.ljust(32, "\0")
    break
  elsif inp == '/reconnect'
    server = TCPSocket.open(options[:hostname], options[:port])
  elsif (m = inp.match(/@(\w{1,32}) (.*)/))
    pm = m[2]
    recipient = m[1]
    server.write [5].pack('C')
    server.write [pm.length + 1].pack('S')
    server.write recipient.ljust(32, "\0")
    server.write me.ljust(32, "\0")
    server.write pm + "\0"
  else
    server.write [2].pack('C')
    server.write me.ljust(32, "\0")
    server.write [inp.length].pack('S')
    server.write inp
    # puts "test"
  end
end

server.close

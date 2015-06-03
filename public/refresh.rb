#!/usr/bin/env ruby

require 'cgi'
require 'json'
require_relative '../server-status'

# Tries to call a method on the server status object.
# If the method doesn't exist, just return nil.
def try_method(method, *args)
  if $status.respond_to? method then
    $status.send(method, *args)
  end
end

cgi = CGI.new('html5')

server_status = {}
servers = []
all_stats = false

begin
  if cgi['server'].length > 0 then # Loading a specific server's info
    servers << cgi['server']
    all_stats = true
    $status = ServerStatus.new(cgi['server'])
  else # Loading the basic info for *all* servers
    servers << 'minecraft'
    servers << 'starbound'
    servers << 'kerbal'
    servers << 'sevendays'
    servers << 'mumble'
    $status = ServerStatus.new
  end

  servers.each do |type|
    server_status[type] = {}
    server_status[type]['online'] = try_method("#{type}_status")
    server_status[type]['player count']  = try_method("#{type}_player_count")
    if all_stats then # For individual servers, load a little more info
      server_status[type]['motd'] = try_method("#{type}_motd")
      server_status[type]['player list'] = try_method("#{type}_player_list")
    end
  end

# All sorts of invalid input can potentially cause an error. Whatever it is, just make sure we return a valid object.
rescue
  server_status = {}
end

cgi.out do
  JSON.generate(server_status)
end

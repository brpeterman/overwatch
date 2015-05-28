#!/usr/bin/env ruby

require 'cgi'
require 'json'
require_relative '../server-status'

def try_method(method, *args)
  if $status.respond_to? method then
    $status.send(method, *args)
  end
end

cgi = CGI.new('html5')

$status = ServerStatus.new
server_status = {}
servers = []
all_stats = false
if cgi['server'].length > 0 then
  servers << cgi['server']
  all_stats = true
else
  servers << 'minecraft'
  servers << 'starbound'
  servers << 'kerbal'
  servers << 'sevendays'
  servers << 'mumble'
end

begin
  servers.each do |type|
    server_status[type] = {}
    server_status[type]['online'] = try_method("#{type}_status")
    server_status[type]['player count']  = try_method("#{type}_player_count")
    if all_stats then
      server_status[type]['motd'] = try_method("#{type}_motd")
      server_status[type]['player list'] = try_method("#{type}_player_list")
    end
  end
rescue
  server_status = {}
end

cgi.out do
  JSON.generate(server_status)
end

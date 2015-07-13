#!/usr/bin/env ruby

#TODO: Build infrastructure to sleep and wake up on demand, keep track of when we were last asked to wake up

require_relative 'server-status'
require 'json'

# Tries to call a method on the server status object.
# If the method doesn't exist, just return nil.
def try_method(method, *args)
  if $status.respond_to? method then
    $status.send(method, *args)
  end
end

# Allow Ctrl+C and SIGTERM to trigger an exit
Signal.trap("INT") do
  $stderr.puts "Shutting down..."
  $do_query = false
end

Signal.trap("TERM") do
  $stderr.puts "Shutting down..."
  $do_query = false
end

previous_status, latest_status = ""

server_status = {}
servers = []

servers << 'minecraft'
servers << 'starbound'
servers << 'kerbal'
servers << 'sevendays'
servers << 'mumble'
servers << 'terraria'
$status = ServerStatus.new(nil, true)

$do_query = true
last_state = :sleep
state = :sleep

while $do_query do
  # Check if anybody actually wants an update
  last_request = File.mtime('tickler')
  if Time.now.to_i - last_request.to_i < 2*60
    last_state = state
    state = :awake
    $stderr.puts "[#{Time.now}] Sending queries"
    begin
      servers.each do |type|
        break unless $do_query
        $status.send("#{type}_reinitialize") # re-ping the server
        server_status[type] = {}
        server_status[type]['online'] = try_method("#{type}_status")
        server_status[type]['player count']  = try_method("#{type}_player_count")
        server_status[type]['motd'] = try_method("#{type}_motd")
        server_status[type]['player list'] = try_method("#{type}_player_list")
      end

      # All sorts of invalid input can potentially cause an error. Whatever it is, just make sure we return a valid object.
    rescue Exception => e
      $stderr.puts e.inspect
      $stderr.puts e.backtrace
      server_status = {}
    end

    latest_status = JSON.generate(server_status)
    if latest_status != previous_status then
      # write an update
      File.open("status.json", "w") do |file|
        file.flock(File::LOCK_EX) # block until we have the lock
        file.print latest_status
        file.flock(File::LOCK_UN)
      end
      previous_status = latest_status
    end
  else
    last_state = state
    state = :sleep
  end

  if state != last_state and state == :sleep
    $stderr.puts "[#{Time.now}] Going to sleep"
  end

  # Hacky way to sleep for a while but still terminate reasonably fast after getting a signal
  10.times do
    break unless $do_query
    sleep 1
  end
end


#!/usr/bin/env ruby

#TODO: Build infrastructure to sleep and wake up on demand, keep track of when we were last asked to wake up

require_relative 'server-status'
require 'json'
require 'drb/drb'

# Allow Ctrl+C and SIGTERM to trigger an exit
Signal.trap("INT") { terminate }
Signal.trap("TERM") { terminate }

def run!
  uri = 'druby://localhost:8787'
  $daemon = Overwatch::StatusDaemon.new
  
  DRb.start_service(uri, $daemon)
  $daemon.start # this line blocks

  DRb.thread.join if DRb.thread
end

def terminate
  $daemon.stop
  DRb.stop_service
end


module Overwatch

  class StatusDaemon
    attr_reader :status, :last_update

    def initialize
      @status = {}
      @last_update = nil
      @last_request = Time.now
      @server_status = Overwatch::ServerStatus.new nil, true
    end

    # Tries to call a method on the server status object.
    # If the method doesn't exist, just return nil.
    def try_method(method, *args)
      if @server_status.respond_to? method then
        @server_status.send(method, *args)
      end
    end

    def start
      servers = []
      servers << 'minecraft'
      servers << 'starbound'
      servers << 'kerbal'
      servers << 'sevendays'
      servers << 'mumble'
      servers << 'terraria'

      @do_query = true
      last_state = :sleep
      state = :sleep

      while @do_query do
        # Check if anybody actually wants an update
        if Time.now.to_i - @last_request.to_i < 2*60
          last_state = state
          state = :awake
          $stderr.puts "[#{Time.now}] Sending queries"
          begin
            servers.each do |type|
              break unless @do_query
              @server_status.send("#{type}_reinitialize") # re-ping the server
              @status[type] = {}
              @status[type]['online'] = try_method("#{type}_status")
              @status[type]['player count']  = try_method("#{type}_player_count")
              @status[type]['motd'] = try_method("#{type}_motd")
              @status[type]['player list'] = try_method("#{type}_player_list")
            end

            # All sorts of invalid input can potentially cause an error. Whatever it is, just make sure we return a valid object.
          rescue Exception => e
            $stderr.puts e.inspect
            $stderr.puts e.backtrace
            @status = {}
          end

        else # Nobody wants an update, so go to sleep
          last_state = state
          state = :sleep
        end

        if state != last_state and state == :sleep
          $stderr.puts "[#{Time.now}] Going to sleep"
        end

        # Hacky way to sleep for a while but still terminate reasonably fast after getting a signal
        10.times do
          break unless @do_query
          sleep 1
        end
      end
    end

    def stop
      @do_query = false
    end

    def status
      @last_request = Time.now
      @status
    end
  end
end

run! if __FILE__ == $0

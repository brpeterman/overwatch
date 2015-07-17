#!/usr/bin/env ruby

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
  DRb.thread.join if DRb.thread
end

def terminate
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

      @servers = []
      @servers << 'minecraft'
      @servers << 'starbound'
      @servers << 'kerbal'
      @servers << 'sevendays'
      @servers << 'mumble'
      @servers << 'terraria'
    end

    # Tries to call a method on the server status object.
    # If the method doesn't exist, just return nil.
    def try_method(method, *args)
      if @server_status.respond_to? method then
        @server_status.send(method, *args)
      end
    end

    def update_status
      begin
        $stderr.puts "[#{Time.now}] Sending queries"
        @servers.each do |type|
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
    end

    def status
      # If the data is over 10 seconds old, refresh it
      if !@last_update or (Time.now.to_i - @last_update.to_i > 10)
        update_status
        @last_update = Time.now
      end
      @status
    end
  end
end

run! if __FILE__ == $0

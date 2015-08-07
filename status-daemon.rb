#!/usr/bin/env ruby

require_relative 'server-status'
require 'json'
require 'drb/drb'
require 'thread'
require 'sys/proctable'

# Allow Ctrl+C and SIGTERM to trigger an exit
Signal.trap("INT") { terminate! }
Signal.trap("TERM") { terminate! }

##
# Process command line parameters.
def run!
  if ARGV.empty?
    show_help
  else
    command = ARGV.first.downcase
    if command.downcase == "start"
      try_start_daemon
    
    elsif command == "stop"
      try_stop_daemon

    elsif command == "fg"
      try_start_daemon fg: true

    else
      show_help
    end
  end
end

##
# Output some instructions.
def show_help
  puts "Usage:"
  puts "  status-daemon.rb COMMAND"
  puts ""
  puts "Commands:"
  puts "  start - start the daemon"
  puts "  stop  - stop the daemon"
  puts "  fg    - start in foreground"
end

##
# Try to start the daemon. Warns if the daemon is running already.
def try_start_daemon(fg: false)
  if daemon_process
    warn "The daemon is already running."
  else
    $daemon = Overwatch::StatusDaemon.new
    server_uri = 'druby://localhost:8787'
    
    puts "Starting daemon"
    if !fg
      job = fork do
        STDERR.reopen(File.open('daemon-error.log', 'w+'))
        DRb.start_service(server_uri, $daemon)
        DRb.thread.join if DRb.thread
      end
      Process.detach job
    else
      DRb.start_service(server_uri, $daemon)
      DRb.thread.join if DRb.thread
    end
  end
end
##
# Try to stop the daemon. Warns if the daemon is not running.
def try_stop_daemon
  pid = daemon_process
  if !pid
    warn "The daemon is not running."
  else
    puts "Stopping daemon"
    Process.kill "TERM", pid
  end
end

##
# Get the PID of the daemon process.
def daemon_process
  pid = nil
  Sys::ProcTable.ps do |process|
    if process.cmdline =~ /#{__FILE__}/ and process.pid != Process.pid
      pid = process.pid
      break
    end
  end
  pid
end

##
# Shut down the DRb service, allowing the daemon to exit gracefully.
def terminate!
  DRb.stop_service
end


module Overwatch

  ##
  # This class queries all the servers it knows about for their current status.
  class StatusDaemon
    attr_reader :last_update

    ##
    # Initialize the object. No surprises here.
    def initialize
      @status = {}
      @last_update = nil
      @server_status = Overwatch::ServerStatus.new skip_query: true
      @mutex = Mutex.new

      populate_servers
    end

    ##
    # Populate @servers from the config file.
    # For details about the config file, see Overwatch::ServerStatus.
    def populate_servers
      File.open('config.json', 'r') do |file|
        @servers = JSON.load(file.readlines.join "\n").keys
      end
    end
    private :populate_servers

    ##
    # Tries to call a method on the server status object.
    # If the method doesn't exist, just return nil.
    def try_method(method, *args)
      if @server_status.respond_to? method then
        @server_status.send(method, *args)
      end
    end
    private :try_method

    ##
    # Query the servers for their status
    def update_status
      @servers.each do |type|
        begin
          @server_status.send("#{type}_reinitialize") # re-ping the server
          @status[type] = {}
          @status[type]['online'] = try_method("#{type}_status")
          @status[type]['player count']  = try_method("#{type}_player_count")
          @status[type]['motd'] = try_method("#{type}_motd")
          @status[type]['player list'] = try_method("#{type}_player_list")
          @status[type]['turn'] = try_method("#{type}_turn")

        # All sorts of invalid input can potentially cause an error. Whatever it is, just make sure we return a valid object.
        rescue Exception => e
          warn "[#{Time.now}] #{e.inspect}"
          e.backtrace.each do |msg|
            warn "[#{Time.now}] #{msg}"
          end
          @status[type] = {}
        end
      end
    end
    private :update_status

    ##
    # Get the latest status.
    # Status may be up to 10 seconds old.
    def status
      # If the data is over 10 seconds old, refresh it
      @mutex.synchronize do
        if !@last_update or (Time.now.to_i - @last_update.to_i > 10)
          update_status
          @last_update = Time.now
        end
      end
      @status
    end
  end
end

run! if __FILE__ == $0

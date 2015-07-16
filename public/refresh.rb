#!/usr/bin/env ruby

require 'cgi'
require 'json'
require 'fileutils'
require 'drb/drb'
require_relative '../server-status'

SERVER_URI = 'druby://localhost:8787'
$daemon = DRbObject.new_with_uri SERVER_URI

Signal.trap("TERM") { terminate }
def terminate
  $connected = false
end

# Send headers to indicate that this is an event stream
$stdout.print "Content-Type: text/event-stream\n"
$stdout.print "Cache-Control: no-cache\n\n"
$stdout.flush

# As long as there's a client, keep sending data
$connected = true
last_update = nil
while $connected do
  begin

    #skip_once = ($daemon.last_update.to_i < Time.now.to_i - 5*60)

    #if !skip_once
      # Check if there has been a change since we last read the status
      current_update = $daemon.last_update
      #if current_update != last_update
        # There shouldn't be multiple lines, but if there are, make sure they send as part of the same data message
        status_json = JSON.generate($daemon.status)
        status_data = status_json.gsub "\n", "\ndata: "
        $stdout.print "data: #{status_data}\n\n"
        $stdout.flush
        last_update = current_update
      #end
    #end
    sleep 3
  rescue Exception => e
    # If we fail to write to the stream, that means it's closed and we need to stop looping
    $stderr.puts e.inspect
    $stderr.puts e.backtrace
    terminate
  end
end

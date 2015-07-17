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
last_status = ""
while $connected do
  begin
    status_json = JSON.generate($daemon.status)
    if status_json != last_status
      last_status = status_json
      # There shouldn't be multiple lines, but if there are, make sure they send as part of the same data message
      status_data = status_json.gsub "\n", "\ndata: "
      $stdout.print "data: #{status_data}\n\n"
      $stdout.flush
    end
    sleep 3
  rescue Exception => e
    # If we fail to write to the stream, that means it's closed and we need to stop looping
    $stderr.puts e.inspect
    $stderr.puts e.backtrace
    terminate
  end
end

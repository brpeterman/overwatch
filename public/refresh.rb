#!/usr/bin/env ruby

require 'cgi'
require 'json'
require_relative '../server-status'

# Make sure any kind of force termination releases the file lock
Signal.trap("INT") { terminate }
Signal.trap("TERM") { terminate }
def terminate
  $connected = false
  File.open("../status.json", "r") do |file|
    file.flock(FILE::LOCK_UN)
  end
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
    File.open("../status.json", "r") do |file|
      file.flock(File::LOCK_SH) # block until file is available (shouldn't be long)
      # Check if there has been a change since we last read the status
      current_update = File.mtime(file.path)
      if current_update != last_update
        # There shouldn't be multiple lines, but if there are, make sure they send as part of the same data message
        status_data = file.readlines.join "data: \n"
        $stdout.print "data: #{status_data}\n\n"
        $stdout.flush
        last_update = current_update
      end
      file.flock(File::LOCK_UN)
    end
    sleep 10
  rescue
    # If we fail to write to the stream, that means it's closed and we need to stop looping
    $connected = false
  end
end

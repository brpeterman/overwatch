#!/usr/bin/env ruby

require 'cgi'
require 'json'
require 'fileutils'
require_relative '../server-status'

# Make sure any kind of forced termination releases the file lock
# Conflicting information on the Internet says that Apache will send a TERM to processes that are timing out, but others say it's a KILL.
# Since I can't catch a KILL, I'm hoping it's a TERM.
Signal.trap("TERM") { terminate }
def terminate
  $connected = false
  if $have_lock
    File.open("../status.json", "r") do |file|
      file.flock(FILE::LOCK_UN)
      $have_lock = false
    end
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
    # If nobody has touched the tickler in a while, skip an iteration so that the data can be refreshed
    skip_once = (File::mtime('../tickler').to_i < Time.now.to_i - 5*60)

    # Notify the daemon that we're interested in an update
    FileUtils.touch "../tickler"

    if !skip_once
      File.open("../status.json", "r") do |file|
        file.flock(File::LOCK_SH) # block until file is available (shouldn't be long)
        $have_lock = true
        # Check if there has been a change since we last read the status
        current_update = File.mtime(file.path)
        if current_update != last_update
          # There shouldn't be multiple lines, but if there are, make sure they send as part of the same data message
          status_data = file.readlines.join "\ndata: "
          $stdout.print "data: #{status_data}\n\n"
          $stdout.flush
          last_update = current_update
        end
        file.flock(File::LOCK_UN)
        $have_lock = false
      end
    end
    sleep 3
  rescue Exception => e
    # If we fail to write to the stream, that means it's closed and we need to stop looping
    $stderr.puts e.inspect
    $stderr.puts e.backtrace
    terminate
  end
end

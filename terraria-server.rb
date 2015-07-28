require 'json'
require 'net/http'
require_relative 'server-shared'

module Overwatch
  #=== Terraria ===

  class TerrariaServer
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: nil)
      reinitialize(config, skip_query: skip_query)
    end

    def reinitialize(config = nil, skip_query: nil)
      @config = config["terraria"] if config

      return if skip_query
      update_terraria_status
    end

    def status
      @status != nil
    end

    def player_list
      if @status
        @status['players'].split(', ')
      end
    end

    def player_count
      if @status
        "#{@status['playercount']}/8"
      else
        "0/0"
      end
    end

    def update_terraria_status
      uri = URI("http://#{@config['queryaddr']}:#{@config['queryport']}/status")
      begin
        @status = JSON.load(Net::HTTP.get(uri))
      rescue Exception => e # error = server down
        $stderr.puts "Error: #{e.inspect}"
      end
    end

    Overwatch::ServerShared::register_server(:terraria, self.name)
  end
end

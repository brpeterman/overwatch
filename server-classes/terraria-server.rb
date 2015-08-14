require 'json'
require 'net/http'
require_relative 'server-shared'
require_relative 'server-query'

module Overwatch
  #=== Terraria ===
  # Requires TShock
  class TerrariaServer < ServerQuery
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: nil)
      add_info_methods
      reinitialize(config, skip_query: skip_query)
    end

    def reinitialize(config = nil, skip_query: nil)
      @config = config["terraria"] if config

      return if skip_query
      update_terraria_status
    end

    def add_info_methods
      define_info :status do
        @status != nil
      end

      define_info :player_list do
        if @status
          @status['players'].split(', ')
        else
          []
        end
      end

      define_info :player_count do
        if @status
          "#{@status['playercount']}/8"
        else
          "0/0"
        end
      end
    end

    def update_terraria_status
      uri = URI("http://#{@config['queryaddr']}:#{@config['queryport']}/status")
      begin
        @status = JSON.load(Net::HTTP.get(uri))
      rescue Exception => e # error = server down
      end
    end
  end
end

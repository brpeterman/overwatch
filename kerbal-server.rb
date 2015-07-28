require 'json'
require 'net/http'
require_relative 'server-shared'

module Overwatch
  #=== Kerbal Space Program ===

  class KerbalServer
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: nil)
      reinitialize(config, skip_query: skip_query)
    end

    def reinitialize(config = nil, skip_query: nil)
      @config = config["kerbal"] if config

      return if skip_query
      begin
        @status = JSON.load(Net::HTTP.get(@config['queryaddr'], @config['querystring'], @config['queryport']))
      rescue
        @status = nil
      end
    end

    def status
      @status != nil
    end

    def player_count
      if @status then
        "#{@status['player_count']}/#{@status['max_players']}"
      else
        "0/0"
      end
    end

    def player_list
      if @status
        @status['players'].split /,\w*/
      else
        []
      end
    end

    Overwatch::ServerShared::register_server(:kerbal, self.name)
  end
end

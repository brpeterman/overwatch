require 'json'
require 'net/http'
require_relative 'server-shared'
require_relative 'server-query'

module Overwatch
  #=== Kerbal Space Program ===

  class KerbalServer < ServerQuery
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: nil)
      add_info_methods
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
    
    def add_info_methods
      define_info :status do
        @status != nil
      end

      define_info :player_count do
        if @status then
          "#{@status['player_count']}/#{@status['max_players']}"
        else
          "0/0"
        end
      end

      define_info :player_list do
        if @status
          @status['players'].split /,\w*/
        else
          []
        end
      end
    end
  end
end

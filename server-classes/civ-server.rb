require 'net/http'
require 'json'
require_relative 'server-shared'
require_relative 'server-query'

module Overwatch
  class CivServer < ServerQuery
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: nil)
      add_info_methods
      reinitialize(config, skip_query: skip_query)
    end

    def reinitialize(config = nil, skip_query: nil)
      if config
        @config = config["civ"]
      end

      if @config && !skip_query
        begin
          @status = JSON.load(Net::HTTP.get(@config["queryaddr"], @config["querystring"]))
        rescue
          @status = nil
        end
      end
    end

    def add_info_methods
      define_info :status do
        @status != nil
      end

      define_info :turn do
        if @status
          @status["turn"].to_i
        end
      end

      define_info :player_list do
        if @status
          @status["players"].reject {|p| p["connected"] != 1}.map {|player| player["name"]}
        else
          []
        end
      end

      define_info :player_count do
        if @status
          maxplayers = @status["players"].count
          online = @status["players"].reduce(0) do |acc, player|
            if player["connected"] == 1
              acc += 1
            else
              acc
            end
          end
          "#{online}/#{maxplayers}"
        else
          "0/0"
        end
      end

      define_info :players_unsubmitted do
        if @status
          players = @status["players"]
          players.reject{|player| player["status"] != 1}.map{|player| player["name"]}
        else
          []
        end
      end
    end
  end
end

require 'net/http'
require 'json'
require_relative 'server-shared'

module Overwatch
  class CivServer
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: nil)
      reinitialize(config, skip_query: skip_query)
    end

    def reinitialize(config = nil, skip_query: nil)
      uri = URI('http://civ.ngrok.io/status.json')
      begin
        @status = JSON.load(Net::HTTP.get(uri))
      rescue
        @status = nil
      end
    end

    def status
      @status != nil
    end

    def turn
      if @status
        @status["turn"].to_i
      end
    end

    def player_list
      if @status
        @status["players"].reject {|p| p["online"] != 1}.each_index.map {|i| "Player #{i}"}
      else
        []
      end
    end

    def player_count
      if @status
        maxplayers = @status["players"].count
        online = @status["players"].reduce(0) do |acc, player|
          if player["online"] == 1
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
  end
end

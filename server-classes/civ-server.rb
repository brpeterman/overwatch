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
        @status = {}
      end
    end

    def status
      @status != nil
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

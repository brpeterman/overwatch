require 'minecraft-query'
require_relative 'server-shared'

module Overwatch
  #=== Minecraft ===

  class MinecraftServer
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: nil)
      reinitialize(config, skip_query: skip_query)
    end

    def reinitialize(config = nil, skip_query: nil)
      @config = config["minecraft"] if config

      return if skip_query
      @status = Query::simpleQuery(@config['serveraddr'], @config['serverport'])
      if @status.kind_of? Exception then
        @status = nil
      end
    end

    def status
      @status != nil
    end

    def player_count
      if @status
        "#{@status[:numplayers]}/#{@status[:maxplayers]}"
      else
        "0/0"
      end
    end

    def motd
      if @status
        @status[:motd]
      else
        ""
      end
    end
  end
end

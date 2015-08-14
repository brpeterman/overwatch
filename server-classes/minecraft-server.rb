require 'minecraft-query'
require_relative 'server-shared'
require_relative 'server-query'

module Overwatch
  #=== Minecraft ===

  class MinecraftServer < ServerQuery
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: nil)
      add_info_methods
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

    def add_info_methods
      define_info :status do
        @status != nil
      end

      define_info :player_count do
        if @status
          "#{@status[:numplayers]}/#{@status[:maxplayers]}"
        else
          "0/0"
        end
      end

      define_info :motd do
        if @status
          @status[:motd]
        else
          ""
        end
      end
    end
  end
end

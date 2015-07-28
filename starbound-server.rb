require_relative 'server-shared'

module Overwatch
  #=== Starbound ===

  class StarboundServer
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: nil)
      reinitialize(config, skip_query: skip_query)
    end

    def reinitialize(config = nil, skip_query: nil)
      @config = config["starbound"] if config

      return if skip_query
      processes = `ps -C starbound_server`
      @status = (processes.split("\n")[1] != nil)
    end

    def status
      @status
    end

    def address
      @config['serveraddr']
    end

    Overwatch::ServerShared::register_server(:starbound, self.name)
  end
end

require_relative 'server-shared'

module Overwatch
  #=== 7 Days to Die ===

  class SevendaysServer
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: nil)
      reinitialize(config, skip_query: skip_query)
    end

    def reinitialize(config = nil, skip_query: nil)
      @config = config["sevendays"] if config

      return if skip_query
      processes = `ps -C 7DaysToDie.x86`
      @status = (processes.split("\n")[1] != nil)
    end

    def status
      @status
    end
  end
end

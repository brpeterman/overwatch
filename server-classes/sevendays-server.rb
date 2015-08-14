require_relative 'server-shared'
require_relative 'server-query'

module Overwatch
  #=== 7 Days to Die ===

  class SevendaysServer < ServerQuery
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: nil)
      add_info_methods
      reinitialize(config, skip_query: skip_query)
    end

    def reinitialize(config = nil, skip_query: nil)
      @config = config["sevendays"] if config

      return if skip_query
      processes = `ps -C 7DaysToDie.x86`
      @status = (processes.split("\n")[1] != nil)
    end

    def add_info_methods
      define_info :status do
        @status
      end
    end
  end
end

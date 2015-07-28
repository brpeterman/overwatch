module Overwatch
  #=== Shared methods ===
  # Methods in this module are the same regardless of the specific server implementation.
  # This module is a mixin for the classes below.
  module ServerShared
    self.instance_eval do
      attr_reader :config
    end

    def address
      if !self.config
        return ""
      end

      if self.config['serverport']
        "#{self.config['serveraddr']}:#{self.config['serverport']}"
      else
        self.config['serveraddr']
      end
    end

    def self.register_server(server_type, classname)
      Overwatch.class_eval do
        if !defined? @@registered_servers
          @@registered_servers = {}
          def self.registered_servers; @@registered_servers end
        end
        @@registered_servers[server_type.to_sym] = classname
      end
    end
  end
end

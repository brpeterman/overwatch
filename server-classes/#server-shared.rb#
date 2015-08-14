module Overwatch
  #=== Shared methods ===
  # Methods in this module are the same regardless of the specific server implementation.
  # This module is a mixin for the server classes.
  module ServerShared
    self.instance_eval do
      attr_reader :config
    end

    ##
    # Return the address that players use to connect to the server.
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

    ##
    # Register a server at the module level.
    # Consumers can use Overwatch.registered_servers to access the list of servers.
    # [server_type] string representing the server
    # [classname] Name of the server's class
    def self.register_server(server_type, classname)
      Overwatch.class_eval do
        if !defined? @@registered_servers
          @@registered_servers = {}
          def self.registered_servers; @@registered_servers end
        end
        @@registered_servers[server_type.to_sym] = classname
      end
    end

    ##
    # Return the unqiue part of a server's class name
    # [classname] Class name
    def self.get_server_type(classname)
      classname.split('::').last.sub('Server', '').downcase
    end

    ##
    # Called when another module includes this module.
    # Registers the caller as a server.
    # [mod] module that included this module.
    def self.included(mod)
      register_server get_server_type(mod.to_s), mod.to_s
    end
  end
end

require 'json'
require_relative 'server-classes/minecraft-server'
require_relative 'server-classes/kerbal-server'
require_relative 'server-classes/sevendays-server'
require_relative 'server-classes/terraria-server'
require_relative 'server-classes/starbound-server'
require_relative 'server-classes/mumble-server'
require_relative 'server-classes/civ-server'
require_relative 'server-classes/irc-server'

module Overwatch
  ##
  # This class provides access to details about the various servers that run
  # on Overwatch.
  #
  # Servers are configured in config.json, which has the following format:
  # config := { server, server2, ... }
  # server := {
  #            "serveraddr":  address that players connect to,
  #            "serverport":  port that players connect to,
  #            "queryaddr":   address to query for status,
  #            "queryport":   port to query for status,
  #            "querystring": resource on queryaddr to request to get status
  #            }
  #
  # Only the keys which are required for the specific server implementation
  # need to be populated.
  class ServerStatus
    # type is the type of server to initialize. If nil, we'll initialize every type we know.
    # skip_query indicates whether we should skip querying the server status
    def initialize(type = nil, skip_query: nil)
      reinitialize(type, skip_query: skip_query)
    end

    # type is the type of server to initialize. If nil, we'll initialize every type we know.
    # skip_query indicates whether we should skip querying the server status
    def reinitialize(type = nil, skip_query: nil)
      # Read configuration
      config = {}
      dir = File.dirname(__FILE__)
      File.open("#{dir}/config.json", "r") do |file|
        config = JSON.load(file.readlines.join "\n")
      end

      @servers = {}
      if type == nil then
        Overwatch.registered_servers.each do |server_type, server_class|
          @servers[server_type] = Object.const_get(server_class).new(config, skip_query: skip_query)
        end
      else
        @servers[type.to_sym] = Object.const_get("#{type.capitalize}Server").new(config, skip_query: skip_query)
      end
    end

    # Pass methods on to the individual server status objects
    def method_missing(method, *args, &block)
      server, method_name = parse_method(method)
      if server then
        if method_name == 'status_text' then
          raise ArgumentError, "wrong number of arguments (#{args.length} for 1)" if args.length != 1
          cgi = args[0]
          status_text(server, cgi)
        else
          server.send(method_name, *args, &block)
        end
      else
        super
      end
    end

    # Package a server's online status into a span element
    def status_text(server, cgi)
      if server.status then
        cgi.span({'class' => 'status online'}) do
          'Online'
        end
      else
        cgi.span({'class' => 'status offline'}) do
          'Offline'
        end
      end
    end

    # Pass respond_to? calls on to the server objects
    def respond_to?(method_sym, include_private = false)
      server, method_name = parse_method(method_sym)
      if server then
        server.respond_to? method_name
      else
        super
      end
    end

    # Check if a method call should be passed to one of our server status objects.
    # returns [server, method_name], which is basically just the method passed in split on the first underscore.
    # if we didn't find a server type that matches, returns nil
    def parse_method(method)
      if /\A(?<server_type>[a-z]+?)_(?<method_name>.+)\Z/ =~ method then # {server_type}_{method}
        server = @servers[server_type.to_sym]
        if !server then
          nil
        else
          [server, method_name]
        end
      else
        nil
      end
    end
  end
end

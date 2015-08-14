require 'json'
require 'net/http'
require_relative 'server-shared'
require_relative 'server-query'

module Overwatch
  #=== Mumble ===

  class MumbleServer < ServerQuery
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: nil)
      add_info_methods
      reinitialize(config, skip_query: skip_query)
    end

    def reinitialize(config = nil, skip_query: nil)
      @config = config["mumble"] if config

      return if skip_query
      @max_players = 20

      begin
        @status = JSON.load(Net::HTTP.get(@config['queryaddr'], @config['querystring'], @config['queryport']))
        if @status.count == 0 then
          @status = nil # Mumble server down and CVP server down should look the same
        end
      rescue # if there's an error, the server is probably down
      end
    end

    def add_info_methods
      define_info :status do
        @status != nil
      end

      define_info :player_list do
        if @status != nil then
          channel_tree_users(@status["root"])
        else
          []
        end
      end

      define_info :player_count do
        if @status != nil then
          users = channel_tree_users(@status["root"])
          "#{users.count}/#{@max_players}"
        else
          "0/0"
        end
      end
    end

    # Recursively build a list of all users in the channel tree starting at 'channel'
    def channel_tree_users(channel)
      users = channel["users"].map {|user| MumbleUser.new(user)}
      channel["channels"].each do |subchannel|
        users = users | channel_tree_users(subchannel)
      end
      users
    end
  end

  class MumbleUser
    def initialize(user_data)
      # Drop each of the hash values into an instance variable
      user_data.each { |name, value| instance_variable_set("@#{name}", value) }
    end

    def to_s
      @name
    end

    # For comparison purposes, two MumbleUser objects with the same name should be treated as equal
    # This is important for the array union operator
    def eql?(other)
      @name == other.name
    end

    def hash
      @name.hash
    end
  end
end



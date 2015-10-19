require_relative 'server-shared'
require_relative 'server-query'
require 'discordrb'
require 'drb/drb'
require 'set'
require 'pstore'

module Overwatch
  # Discord
  class DiscordServer < ServerQuery
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: false)
      @config = config['discord']
      @bot = Discordrb::Bot.new @config['email'], @config['password'], true

      add_info_methods
      
      add_handlers

      @connection_thread = Thread.start do
        @connected = true # Assume we've connected
        @bot.run
        @connected = false
      end
    end

    def reinitialize(config = nil, skip_query: false)
      # not used
    end

    def add_info_methods()
      define_info :status do
        @connected
      end
      
      define_info :player_count do
        if @connected
          player_list.count
        else
          "0"
        end
      end

      define_info :player_list do
        if @connected
          discord_player_list
        else
          []
        end
      end

      define_info :motd do
        if !@connected
          return ""
        end
      
        server = @bot.server(@config['serverid'])
        return if !server

        channel_index = server.channels.index {|chan| chan.id == @config['channelid']}
        channel = server.channels[channel_index]
        return if !channel

        channel.topic
      end

      define_info :last_activity do
        @last_activity
      end
    end

    def add_handlers()
      @bot.disconnected do |event|
        @connected = false
      end

      @bot.message do |event|
        handle_message(event)
      end
    end

    def discord_player_list
      server = @bot.server(@config['serverid'])
      return [] if !server

      server.members.reject{|u| u.status == :offline}.map{|u| u.name}.sort
    end

    def handle_message(event)
      list = []
      if (event.content == "!servers")
        config = JSON.load(File.open('config.json'))
        config.keys.reduce(list) do |acc, name|
          c = config[name]
          if name != 'discord'
            addr = c['serveraddr']
            if c['serverport']
              addr = "#{addr}:#{c['serverport']}"
            end
            reply_string = "#{name}: #{addr}" if addr != ""
          end
          acc << reply_string if reply_string != ""
        end
      end
      if list.length > 0
        event.respond list.join("\n")
      end
    end
  end
end

require_relative 'server-shared'
require 'irc-connection'

module Overwatch
  class IRCServer
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: nil)
      @status = {}
      @barriers = {}
      @config = config["irc"]
      @nick = @config["nick"]

      @bot = RubyIRC::IRCConnection.new @config["nicks"].first, @config["username"], @config["realname"]
      #@bot.instance_eval do
      #  @debug = true
      #end

      add_handlers
      @connection_thread = Thread.start do
          @bot.connect @config["serveraddr"], @config["serverport"]
      end
    end

    def reinitialize(config = nil, skip_query: nil)
      # Request users online
      @barriers[:namreply] = true
      @bot.names @config["channel"]
      while @barriers[:namreply] do end
      @status[:player_list]
    end

    def status
      true # If IRC goes down, don't come complaining to me
    end

    def player_list
      @status[:player_list] or []
    end

    def player_count
      if @status[:player_list]
        @status[:player_list].count
      else
        "0"
      end
    end

    def disconnect(msg = nil)
      @bot.quit(msg)
      @connection_thread.join
    end

    def add_handlers
      # namreply
      @bot.add_handler 'namreply' do |event|
        handle_namreply event
      end

      # endofmotd
      @bot.add_handler 'endofmotd' do |event|
        handle_endofmotd event
      end

      # join
      @bot.add_handler 'join' do |event|
        handle_join event
      end

      #part
      @bot.add_handler 'part' do |event|
        handle_part event
      end

      # topic
      @bot.add_handler 'topic' do |event|
        handle_topic event
      end

      @bot.add_handler 'privmsg' do |event|
        handle_privmsg event
      end
    end

    def handle_namreply(event)
      @status[:player_list] = event.params.last.split ' '
      @barriers[:namreply] = nil
    end

    def handle_endofmotd(event)
      @bot.join @config["channel"]
    end

    def handle_join(event)
      # If the bot joined, make sure we know we're in the channel
      if event.nick == @nick
        # Ignore for now
        # Otherwise, request a user list update
      else
        @bot.names event.params.first
      end
    end

    def handle_part(event)
      if event.nick == @bot.nick
        # ignore for now
      else
        @barriers[:namreply] = true
        @bot.names event.params.first
        @barriers[:namreply] = nil
      end
    end

    def handle_topic(event)
      @status[:topic] = event.params.last
    end

    def handle_privmsg(event)
      # nothing happens
    end
  end
end

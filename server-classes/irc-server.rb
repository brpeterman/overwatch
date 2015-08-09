require_relative 'server-shared'
require 'irc-connection'
require 'drb/drb'

module Overwatch
  class IRCServer
    include Overwatch::ServerShared

    def initialize(config = nil, skip_query: nil)
      @status = {}
      @barriers = {}
      @config = config["irc"]
      @nick = @config["nick"]
      @last_turn = 0

      @bot = RubyIRC::IRCConnection.new @config["nicks"].first, @config["username"], @config["realname"]
      #@bot.instance_eval do
      #  @debug = true
      #end

      # Set up bot and connect to server
      add_handlers
      @connection_thread = Thread.start do
          @bot.connect @config["serveraddr"], @config["serverport"]
      end

      reinitialize(skip_query: skip_query)
    end

    def reinitialize(config = nil, skip_query: nil)
      if !skip_query
        # Request users online
        @barriers[:namreply] = true
        @bot.names @config["channel"]
      end
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

    def motd
      @status[:topic] or ""
    end

    def disconnect(msg = nil)
      @bot.quit(msg)
      @connection_thread.join
    end

    def civ_turn
      return if !@daemon

      status = @daemon.status
      if status['civ']
        status['civ']['turn'].to_i
      end
    end

    def poll_civ_updates
      while @bot.connected
        sleep 10
        turn = civ_turn
        if @last_turn != turn && turn != 0
          @bot.privmsg @config['channel'], "[Civ] Turn #{turn} has begun."
          @last_turn = turn
        end
      end
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
      @status[:player_list] = event.params.last.split(' ').map {|name| name.tr('+@~&%', '')}.sort
      @barriers[:namreply] = nil
    end

    def handle_endofmotd(event)
      @bot.join @config["channel"]

      if !@daemon
        # Connect to the status daemon
        server_uri = 'druby://localhost:8787'
        @daemon = DRbObject.new_with_uri server_uri
        @last_turn = civ_turn
      end

      if !@civ_thread
        # Poll for updates to civ turn
        @civ_thread = Thread.start do
          poll_civ_updates
        end
      end
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

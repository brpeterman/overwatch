require_relative 'server-shared'
require 'irc-connection'
require 'drb/drb'
require 'set'

module Overwatch
  # IRC
  class IRCServer
    include Overwatch::ServerShared

    # Set up the IRC bot and connect to the server and channel
    # [config] configuration data. (See ServerStatus)
    # [skip_query] Pass true to skip sending a NAMES query upon connecting.
    def initialize(config = nil, skip_query: nil)
      @status = {}
      @barriers = {}
      @config = config["irc"]
      @nick = @config["nicks"].first
      @last_turn = 0
      @last_active = Set.new []

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

    # Send a NAMES query. If skip_query is not true, this method does nothing.
    # [config] Not used.
    # [skip_query] Pass true to skip sending the NAMES query
    def reinitialize(config = nil, skip_query: nil)
      if !skip_query
        # Request users online
        @barriers[:namreply] = true
        @bot.names @config["channel"]
      end
    end

    # Status of IRC server. Always returns true.
    def status
      true # If IRC goes down, don't come complaining to me
    end

    # List of users connected to the channel.
    def player_list
      @status[:player_list] or []
    end

    # Number of users connected to the channel.
    # Returns a string.
    def player_count
      if @status[:player_list]
        @status[:player_list].count.to_s
      else
        "0"
      end
    end

    # Channel topic.
    def motd
      @status[:topic] or ""
    end

    # Disconnect the bot from the server.
    def disconnect(msg = nil)
      @bot.quit(msg)
      @connection_thread.join
    end

    # Return the current turn in the Civ game.
    def civ_turn
      return if !@daemon

      status = @daemon.status
      if status['civ']
        status['civ']['turn'].to_i
      end
    end

    def active_players
      return if !@daemon

      Set.new []
    end

    # Poll for updates to the Civ game status.
    # When the turn advances, send a message to the channel.
    def poll_civ_updates
      while @bot.connected
        sleep 10
        turn = civ_turn
        if @last_turn != turn && turn != 0
          report_turn
          @last_turn = turn
        end

        active = active_players
        if @last_active != active && !active.empty && !@last_active.empty?
          report_active
          @last_active = active
        end
      end
    end

    def report_turn(dest = nil)
      if dest == nil
        dest = @config['channel']
      end

      if @last_turn == 0
        @bot.privmsg dest, "The current turn is unknown at this time."
      else
        @bot.privmsg dest, "[Civ] Turn #{turn} has begun."
      end
    end

    def report_active(dest = nil)
      if dest == nil
        dest = @config['channel']
      end

      if @last_active.empty?
        @bot.privmsg dest, "No players may play at this time."
      else
        @bot.privmsg dest, "[Civ] The following players may take their turn: #{active.to_a.join(', ')}"
      end
    end

    # Add event handlers to the bot.
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

    # Handle NAMREPLY event.
    # Parses the list of nicknames and places them in @status[:player_list]
    def handle_namreply(event)
      @status[:player_list] = event.params.last.split(' ').map {|name| name.tr('+@~&%', '')}.sort
      @barriers[:namreply] = nil
    end

    # Handle ENDOFMOTD event.
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
      # Report the current civ turn if asked
      if event.params.last == ".turn"
        dest = event.params.first
        if dest == @nick
          dest = event.from
        end

        report_turn(dest)
        report_active(dest)
      end
    end
  end
end

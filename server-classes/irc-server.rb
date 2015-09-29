require_relative 'server-shared'
require_relative 'server-query'
require 'cinch'
require 'drb/drb'
require 'set'
require 'pstore'

module Overwatch
  # IRC
  class IRCServer < ServerQuery
    include Overwatch::ServerShared

    # Set up the IRC bot and connect to the server and channel
    # [config] configuration data. (See ServerStatus)
    # [skip_query] Pass true to skip sending a NAMES query upon connecting.
    def initialize(config = nil, skip_query: nil)
      @status = {}
      @barriers = {}
      @config = config["irc"]
      @nick = @config["nicks"].first
      @store = PStore.new 'irc_state.pstore'
      @store.transaction(true) do
        @last_turn = @store.fetch(:last_turn, 0)
        @last_needed = @store.fetch(:last_needed, Set.new)
        @reported_players = @store.fetch(:reported_players, Set.new)
      end

      add_info_methods

      @bot = Cinch::Bot.new
      @bot.config.server = @config['serveraddr']
      @bot.config.nicks = @config['nicks']
      @bot.config.user = @config['username']
      @bot.config.realname = @config['realname']
      @bot.config.channels = [@config['channel']]

      # Set up bot and connect to server
      add_handlers
      @connection_thread = Thread.start do
        @bot.start
      end

      reinitialize(skip_query: skip_query)
    end

    # Send a NAMES query. If skip_query is not true, this method does nothing.
    # [config] Not used.
    # [skip_query] Pass true to skip sending the NAMES query
    def reinitialize(config = nil, skip_query: nil)
      if !skip_query
        # Request users online
        channel = @bot.channels.first
        if channel
          @status[:player_list] = channel.users.map {|user| user.first.nick }
        end
      end
    end

    def add_info_methods
      # Status of IRC server. Always returns true.
      define_info :status do
        true # If IRC goes down, don't come complaining to me
      end

      # List of users connected to the channel.
      define_info :player_list do
        if @status
          @status[:player_list] or []
        else
          []
        end
      end

      # Number of users connected to the channel.
      # Returns a string.
      define_info :player_count do
        if @status && @status[:player_list]
          @status[:player_list].count.to_s
        else
          "0"
        end
      end

      # Channel topic.
      define_info :motd do
        if @bot.channels.first
          @bot.channels.first.topic
        end
      end

      # Channel
      define_info :channel do
        if @config
          @config["channel"]
        end
      end
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

    # Get a list of players who need to submit their turn before the game
    # can advance.
    # Returns a set.
    def civ_unsubmitted_players
      return if !@daemon

      status = @daemon.status
      if status['civ']
        Set.new status['civ']['players_unsubmitted']
      end
    end

    # Poll for updates to the Civ game status.
    # When the turn advances, send a message to the channel.
    def poll_civ_updates
      while @connected
        sleep 10
        turn = civ_turn
        if @last_turn != turn && turn != 0
          @reported_players = Set.new
          report_turn
        end

        needed = civ_unsubmitted_players
        if (@last_needed != needed) && (!needed.empty?) && (!needed.proper_subset? @reported_players)
          @reported_players |= needed
          report_needed
        end
      end
    end

    def report_turn(dest = nil)
      if dest == nil
        dest = @config['channel']
      end

      save_turn civ_turn
      
      if @last_turn == 0
        @bot.channels.first.send "[Civ] The current turn is unknown right now."
      else
        @bot.channels.first.send "[Civ] Turn #{@last_turn} has begun."
      end
    end

    def save_turn(turn)
      @last_turn = turn

      @store.transaction do
        @store[:last_turn] = @last_turn
      end
    end

    def report_needed(dest = nil)
      if dest == nil
        dest = @config['channel']
      end

      save_players civ_unsubmitted_players

      if @last_needed.empty?
        @bot.privmsg dest, "[Civ] No players need to take their turn right now."
      else
        @bot.privmsg dest, "[Civ] The game is waiting on turns from these players: #{@last_needed.to_a.join(', ')}"
      end
    end
    
    def save_players(players)
      @last_needed = players

      @store.transaction do
        @store[:last_needed] = @last_needed
        @store[:reported_players] = @reported_players
      end
    end

    # Add event handlers to the bot.
    def add_handlers
      #endofmotd
      @bot.on Cinch::Constants::RPL_ENDOFMOTD do |event|
        handle_endofmotd event
      end

      @bot.on :privmsg do |event|
        handle_privmsg event
      end

      @bot.handlers.each do |handler|
        handler.instance_eval do
          @execute_in_callback = false
        end
      end
    end

    def handle_endofmotd(event)
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

    def handle_privmsg(event)
      # Report the current civ turn if asked
      if event.params.last == ".turn"
        dest = event.params.first
        if dest == @nick
          dest = event.user.nick
        end

        report_turn(dest)
        report_needed(dest)
      end
    end
  end
end

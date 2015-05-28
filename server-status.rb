require_relative 'query'
require 'json'
require 'net/http'

class ServerStatus
  def initialize
    reinitialize
  end

  def reinitialize
    @servers = {}
    @servers[:minecraft] = MinecraftServer.new
    @servers[:kerbal] = KerbalServer.new
    @servers[:starbound] = StarboundServer.new
    @servers[:sevendays] = SevenDays.new
    @servers[:mumble] = MumbleServer.new
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

  def status_text(server, cgi)
    if server.send("status") then
      cgi.span({'class' => 'status online'}) do
        'Online'
      end
    else
      cgi.span({'class' => 'status offline'}) do
        'Offline'
      end
    end
  end

  def respond_to?(method_sym, include_private = false)
    server, method_name = parse_method(method_sym)
    if server then
      server.respond_to? method_name
    else
      super
    end
  end

  def parse_method(method)
    if method =~ /\A([a-z]+?)_(.+)\Z/ then # {server_type}_{method}
      server_type = $1
      method_name = $2
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

#=== Minecraft ===

class MinecraftServer
  def initialize
    @status = Query.simpleQuery('mc.bpeterman.com', 25765)
    if @status.kind_of? Exception then
      @status = nil
    end
  end

  def status
    @status != nil
  end

  def player_count
    if @status
      "#{@status[:numplayers]}/#{@status[:maxplayers]}"
    else
      "0/0"
    end
  end

  def motd
    @status[:motd]
  end
end

#=== Kerbal Space Program ===

class KerbalServer
  def initialize
    begin
      @status = JSON.load(Net::HTTP.get('localhost', '/', 4300))
    rescue
      @status = nil
    end
  end

  def status
    @status != nil
  end

  def player_count
    if @status then
      "#{@status['player_count']}/#{@status['max_players']}"
    else
      "0/0"
    end
  end

  def player_list
    @status['players']
  end
end

#=== Starbound ===

class StarboundServer
  def initialize
    processes = `ps -C starbound_server`
    @status = (processes.split("\n")[1] != nil)
  end

  def status
    @status
  end
end

#=== 7 Days to Die ===

class SevenDays
  def initialize
    processes = `ps -C 7DaysToDie.x86`
    @status = (processes.split("\n")[1] != nil)
  end

  def status
    @status
  end
end

#=== Mumble ===

class MumbleServer
  def initialize
    @max_players = 20

    begin
      @status = JSON.load(Net::HTTP.get('bpeterman.com', '/mumble/?view=json&serverId=1', 80))
      if @status.count == 0 then
        @status = nil # Mumble server down and CVP server down should look the same
      end
    rescue # if there's an error, the server is probably down
    end
  end

  def status
    @status != nil
  end

  def player_list
    if @status != nil then
      channel_tree_users(@status["root"]).join ', '
    else
      ""
    end
  end

  # Recursively build a list of all users in the channel tree starting at 'channel'
  def channel_tree_users(channel)
    users = channel["users"].map {|user| user["name"]}
    channel["channels"].each do |subchannel|
      users = users | channel_tree_users(subchannel)
    end
    users
  end

  def player_count
    if @status != nil then
      users = channel_tree_users(@status["root"])
      "#{users.count}/#{@max_players}"
    else
      "0/0"
    end
  end
end

require_relative 'query'
require 'json'
require 'net/http'

# All calls should go through this object. It provides methods to interact with the individual server types.
class ServerStatus
  # type is the type of server to initialize. If nil, we'll initialize every type we know.
  # skip_query indicates whether we should skip querying the server status
  def initialize(type = nil, skip_query = nil)
    reinitialize(type, skip_query)
  end

  # type is the type of server to initialize. If nil, we'll initialize every type we know.
  # skip_query indicates whether we should skip querying the server status
  def reinitialize(type = nil, skip_query = nil)
    # Read configuration
    config = {}
    dir = File.dirname(__FILE__)
    File.open("#{dir}/config.json", "r") do |file|
      config = JSON.load(file.readlines.join "\n")
    end

    @servers = {}
    if type == nil then
      @servers[:minecraft] = MinecraftServer.new(config, skip_query)
      @servers[:kerbal] = KerbalServer.new(config, skip_query)
      @servers[:starbound] = StarboundServer.new(config, skip_query)
      @servers[:sevendays] = SevendaysServer.new(config, skip_query)
      @servers[:mumble] = MumbleServer.new(config, skip_query)
      @servers[:terraria] = TerrariaServer.new(config, skip_query)
    else
      @servers[type.to_sym] = Object.const_get("#{type.capitalize}Server").new(config, skip_query)
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
  def initialize(config = nil, skip_query = nil)
    reinitialize(config, skip_query)
  end

  def reinitialize(config = nil, skip_query = nil)
    @config = config["minecraft"] if config

    return if skip_query
    @status = Query.simpleQuery(@config['serveraddr'], @config['serverport'])
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
    if @status
      @status[:motd]
    else
      ""
    end
  end

  def address
    "#{@config['serveraddr']}:#{@config['serverport']}"
  end
end

#=== Kerbal Space Program ===

class KerbalServer
  def initialize(config = nil, skip_query = nil)
    reinitialize(config, skip_query)
  end

  def reinitialize(config = nil, skip_query = nil)
    @config = config["kerbal"] if config

    return if skip_query
    begin
      @status = JSON.load(Net::HTTP.get(@config['queryaddr'], @config['querystring'], @config['queryport']))
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
    if @status
      @status['players'].split /,\w*/
    else
      []
    end
  end

  def address
    @config['serveraddr']
  end
end

#=== Starbound ===

class StarboundServer
  def initialize(config = nil, skip_query = nil)
    reinitialize(config, skip_query)
  end

  def reinitialize(config = nil, skip_query = nil)
    @config = config["starbound"] if config

    return if skip_query
    processes = `ps -C starbound_server`
    @status = (processes.split("\n")[1] != nil)
  end

  def status
    @status
  end

  def address
    @config['serveraddr']
  end
end

#=== 7 Days to Die ===

class SevendaysServer
  def initialize(config = nil, skip_query = nil)
    reinitialize(config, skip_query)
  end

  def reinitialize(config = nil, skip_query = nil)
    @config = config["sevendays"] if config

    return if skip_query
    processes = `ps -C 7DaysToDie.x86`
    @status = (processes.split("\n")[1] != nil)
  end

  def status
    @status
  end

  def address
    "#{@config['serveraddr']}:#{@config['serverport']}"
  end
end

#=== Mumble ===

class MumbleServer
  def initialize(config = nil, skip_query = nil)
    reinitialize(config, skip_query)
  end

  def reinitialize(config = nil, skip_query = nil)
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

  def status
    @status != nil
  end

  def player_list
    if @status != nil then
      channel_tree_users(@status["root"])
    else
      []
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

  def player_count
    if @status != nil then
      users = channel_tree_users(@status["root"])
      "#{users.count}/#{@max_players}"
    else
      "0/0"
    end
  end

  def address
    "#{@config['serveraddr']}:#{@config['serverport']}"
  end
end

#=== Terraria ===

class TerrariaServer
  def initialize(config = nil, skip_query = nil)
    reinitialize(config, skip_query)
  end

  def reinitialize(config = nil, skip_query = nil)
    @config = config["terraria"] if config

    return if skip_query
    update_terraria_status
  end

  def status
    @status != nil
  end

  def player_list
    if @status
      @status['players'].split(', ')
    end
  end

  def player_count
    if @status
      "#{@status['playercount']}/8"
    else
      "0/0"
    end
  end

  def update_terraria_status
    uri = URI("http://#{@config['queryaddr']}:#{@config['queryport']}/status")
    begin
      @status = JSON.load(Net::HTTP.get(uri))
    rescue Exception => e # error = server down
      $stderr.puts "Error: #{e.inspect}"
    end
  end

  def address
    "#{@config['serveraddr']}:#{@config['serverport']}"
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

  def widget(cgi)
    cgi.div({'class' => 'mumble-user',
              'id' => "mumble-user-#{@name}"}) do
      cgi.div({'class' => 'mumble-user-name'}) do
        @name
      end +
      cgi.div({'class' => 'mumble-user-data'}) do
        ( @mute or @selfMute ?
          cgi.div({'class' => 'mumble-user-mute'}) do
            
          end
          : "" ) +
        ( @deaf or @selfDeaf ?
          cgi.div({'class' => 'mumble-user-deaf'}) do

          end
          : "")
      end
    end
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

module Overwatch
  # This is the parent class for all server query classes.
  # It provides an interface for defining and retrieving discrete
  # data about a server.
  class ServerQuery
    # Define a method as one that provides info about a server.
    # If [block] is passed, defines the method described by [block].
    # Info-providing methods may not take any arguments.
    def define_info(method_name, &block)
      if block != nil
        self.class.send(:define_method, method_name, &block)
      end

      if !defined? @info_providers
        @info_providers = []
      end

      @info_providers << method_name
    end

    # Return all of the info that we know how to provide.
    # Return is in the form of a hash. Keys are the names of the info methods,
    # values are the return values of said methods.
    def all_info
      return {} if !defined? @info_providers

      @info_providers.reduce({}) do |acc, method_name|
        acc[method_name.to_s] = self.send method_name
        acc
      end
    end
  end
end

module Overwatch
  class ServerQuery
    def define_info(method_name, &block)
      if block != nil
        self.class.send(:define_method, method_name, &block)
      end

      if !defined? @info_providers
        @info_providers = []
      end

      @info_providers << method_name
    end

    def all_info
      return {} if !defined? @info_providers

      @info_providers.reduce({}) do |acc, method_name|
        acc[method_name.to_s] = self.send method_name
        acc
      end
    end
  end
end

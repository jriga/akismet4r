begin
  require 'rubygems'
rescue LoadError
end

require 'rest_client'

module Akismet4r
  VERSION = '2009-01-21'

  class MappingError < ::Exception; end
  class FieldMissing < ::Exception; end
  class KeyVerificationFailed < ::Exception; end
  
  module Config
    class << self
      def config
        @config ||= Configuration.new
      end

      def setup      
        yield config
      end

      def [](name)
        config.send(name.to_sym)
      end
    end

    class Configuration
      attr_accessor :host, :port, :version, :api_key, :key_verified, :blog, :log
      attr_reader :user_agent
      def initialize
       @host, @port, @version, @blog, @api_key, @key_verified, @user_agent, @log = 'rest.akismet.com', 80, '1.1', nil, nil, false, "Akismet4r #{VERSION}", 'stdout'
      end
      
      def api_key
        raise FieldMissing.new("You must provide an api-key") unless @api_key
        @api_key
      end

      def blog
        raise FieldMissing.new('You must provide your blog full uri') unless @blog
        @blog
      end
    end
  end
  
  def verify_key
    Config.config.key_verified = (::RestClient.post("#{Config[:host]}:#{Config[:port]}/#{Config[:version]}/verify-key",{:key => Config[:api_key], :blog => Config[:blog]}) == 'valid')
    raise KeyVerificationFailed.new("Your key #{Config[:api_key]} has not been verified") unless Config[:key_verified]
  end

  def akismet
    ::RestClient.log = Config[:log] if ::RestClient.log != Config[:log]
    verify_key unless Config[:key_verified]
    @akismet ||= ::RestClient::Resource.new("#{Config[:api_key]}.#{Config[:host]}:#{Config[:port]}/#{Config[:version]}/")
  end

  def self.included(klass)
    klass.extend(SingletonMethods)
    klass.send(:include, InstanceMethods)
  end

  module SingletonMethods
    def hash
      @hash ||= {}
    end
 
    def map(name, method)
      hash[name.to_sym] = method.to_sym
    end
  end

  module InstanceMethods
    def spam?(attrs={})
      request('comment-check', attrs)
    end

    def spam!(attrs={})
      request('submit-spam', attrs)
    end

    def ham!(attrs={})
      request('submit-ham', attrs)
    end

    private 
    def request(method, attrs={})
      raise FieldMissing.new("user_ip or user_agent missing from #{attrs}") unless attrs[:user_ip] && attrs[:user_agent]
      akismet[method].post(data.merge(attrs), :user_agent => ::Akismet4r::Config[:user_agent]) == 'true'
    end

    def data(server={})
      payload = {
        :blog => ::Akismet4r::Config[:blog],
        :comment_type => self.class.name,
        :comment_author => map_on(:comment_author),
        :comment_author_email => map_on(:comment_author_email),
        :comment_author_url => map_on(:comment_author_url),
        :comment_content => map_on(:comment_content)
      }
      payload.merge(server)
    end

    def map_on(name)
      if self.class.hash.has_key?(name)
        raise Akismet4r::MappingError unless self.respond_to?(self.class.hash[name])
        return self.send(self.class.hash[name])
      end
      self.send(name)
    end
  end
end

begin
  require 'rubygems'
rescue LoadError
end

require 'rest_client'

module Akismet4r
  VERSION = '2009-01-21'
  
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
        raise "You must provide an api-key" unless @api_key
        @api_key
      end

      def blog
        raise 'You must provide your blog full uri' unless @blog
        @blog
      end
    end
  end

  def akismet
    ::RestClient.log = Config[:log] if ::RestClient.log != Config[:log]
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
      akismet['comment-check'].post(data.merge(attrs), :user_agent => ::Akismet4r::Config[:user_agent]) == 'true'
    end

    def spam!(attrs={})
      akismet['submit-spam'].post(data.merge(attrs), :user_agent => ::Akismet4r::Config[:user_agent]) == 'true'
    end

    def ham!(attrs={})
      akismet['submit-ham'].post(data.merge(attrs), :user_agent => ::Akismet4r::Config[:user_agent]) == 'true'
    end

    private 
    def data(server={})
      payload = {
        :blog => ::Akismet4r::Config[:blog],
        :comment_type => self.class.name,
        :comment_author => self.send(self.class.hash[:comment_author]) || comment_author,
        :comment_author_email => self.send(self.class.hash[:comment_author_email]) || comment_author_email,
        :comment_author_url => self.send(self.class.hash[:comment_author_url]) || comment_author_url,
        :comment_content => self.send(self.class.hash[:comment_content]) || comment_content
      }
      payload.merge(server)
    end
  end

end

# Akismet4r::Config.setup do |c|
#   c.host = 'http://akismet.com' 
#   c.port = 8080
#   c.key = 'Der2345nklDF'
#   c.blog_uri = 'http://my_blog.com'
# end

# class Comment
#   include Akismet4r
# end

# user_ip (required)
# user_agent (required)
# referrer (note spelling)
# permalink
# other

# comment = Comment.new
# comment.spam?(:user_ip => '', :user_agent => '') # => true | false | Akismet4r::Error

# comment.spam! # => true | Akismet4r::Error

# comment.ham! # => 

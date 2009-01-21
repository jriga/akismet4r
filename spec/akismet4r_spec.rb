require 'rubygems'
require 'spec'
require File.join(File.expand_path(File.dirname(__FILE__)), '..','lib','akismet4r')

describe "Akismet4r" do
 
  describe "::Config" do
    it "should have default configuration" do
      Akismet4r::Config.config.host.should == 'rest.akismet.com'
      Akismet4r::Config.config.port.should == 80
      Akismet4r::Config.config.version.should == '1.1'
      Akismet4r::Config.config.key_verified.should be_false
      Akismet4r::Config.config.user_agent.should == 'Akismet4r 2009-01-21'

      lambda {Akismet4r::Config.config.api_key}.should raise_error
      lambda {Akismet4r::Config.config.blog}.should raise_error

      Akismet4r::Config[:host].should == 'rest.akismet.com'
      Akismet4r::Config[:port].should == 80
      Akismet4r::Config[:version].should == '1.1'
      Akismet4r::Config[:key_verified].should be_false
      Akismet4r::Config[:user_agent].should == 'Akismet4r 2009-01-21'

      lambda {Akismet4r::Config[:api_key]}.should raise_error
      lambda {Akismet4r::Config[:blog]}.should raise_error
    end

    it "should setup options" do
      Akismet4r::Config.setup do |c|
        c.host = 'test.com'
        c.port = 8080
        c.version = '1.2'
        c.api_key = '112c434vH6OiJjTpyO'
        c.key_verified = true
        c.blog = 'http://example.com'
      end

      Akismet4r::Config[:host].should == 'test.com'
      Akismet4r::Config[:port].should == 8080
      Akismet4r::Config[:version].should == '1.2'
      Akismet4r::Config[:key_verified].should be_true
      Akismet4r::Config[:api_key].should == '112c434vH6OiJjTpyO'
      Akismet4r::Config[:blog].should == 'http://example.com' 
    end
  end

  describe "::SingletonMethods" do
    class Foo
      attr_accessor :author, :email, :text, :url
      include Akismet4r

      map :comment_author, :author
      map :comment_author_email, :email
      map :comment_author_url, :url
      map :comment_content, :text
    end

    it "should use user defined mappings to build payload" do
      Akismet4r::Config.setup {|c| c.blog = 'http://my_blog.com' }

      foo = Foo.new
      foo.author = 'jriga'
      foo.email = 'jriga@lamit.com'
      foo.url = 'http://www.lamit.com'
      foo.text = 'blah '*10

      expected_payload = {
          :blog => 'http://my_blog.com', 
          :comment_type => 'Foo',
          :comment_author => 'jriga',
          :comment_author_email => 'jriga@lamit.com',
          :comment_author_url => 'http://www.lamit.com',
          :comment_content => 'blah '* 10
      }
 
      foo.send(:data).should == expected_payload
    end
  end

  describe "::InstanceMethods" do
    class Foo
      attr_accessor :comment_author, :comment_author_email, :comment_author_url, :comment_content
      include Akismet4r
    end

    before do
      Akismet4r::Config.setup do |c|
        c.api_key = '1234g54w5g54'
        c.blog = 'http://blog.com'
      end

      @akismet = ::RestClient::Resource.new("http://example.com")
      ::RestClient::Resource.should_receive(:new).any_number_of_times.and_return(@akismet)
    end

    describe '#spam?' do
      it "should available" do
        foo = Foo.new
        foo.respond_to?(:spam?).should be_true
      end

      it "should detect spam" do
        @akismet.should_receive(:post).and_return('true')
        foo = Foo.new
        foo.spam?.should be_true
      end

      it "should detect non spam" do
        @akismet.should_receive(:post).and_return('false')
        foo = Foo.new
        foo.spam?.should be_false
      end
    end

    describe '#spam!' do
      it "should provide spam!" do
        foo = Foo.new
        foo.respond_to?(:spam!).should be_true
      end
            it "should detect spam" do
        @akismet.should_receive(:post).and_return('true')
        foo = Foo.new
        foo.spam!.should be_true
      end

      it "should detect non spam" do
        @akismet.should_receive(:post).and_return('false')
        foo = Foo.new
        foo.spam!.should be_false
      end

    end

    describe '#ham!' do
      it "should provide ham!" do
        foo = Foo.new
        foo.respond_to?(:ham!).should be_true
      end

      it "should detect spam" do
        @akismet.should_receive(:post).and_return('true')
        foo = Foo.new
        foo.ham!.should be_true
      end

      it "should detect non spam" do
        @akismet.should_receive(:post).and_return('false')
        foo = Foo.new
        foo.ham!.should be_false
      end

    end

    describe '#data' do
      before do
        Akismet4r::Config.setup {|c| c.blog = 'http://my_blog.com' }

        @foo = Foo.new
        @foo.comment_author = 'jriga'
        @foo.comment_author_email = 'jriga@lamit.com'
        @foo.comment_author_url = 'http://www.lamit.com'
        @foo.comment_content = 'blah '*10
        
        @server = {
          "PATH_INFO"=>"/", 
          "REMOTE_HOST"=>"127.0.0.1", 
          "HTTP_USER_AGENT"=>"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.0.5) Gecko/2008120121 Firefox/3.0.5", 
          "HTTP_HOST"=>"localhost:7000",
          "REMOTE_ADDR"=>"127.0.0.1", 
          "HTTP_KEEP_ALIVE"=>"300", 
          "REQUEST_PATH"=>"/", 
          "HTTP_VERSION"=>"HTTP/1.1", 
          "REQUEST_URI"=>"http://localhost:7000/", 
          "QUERY_STRING"=>"", 
          "REQUEST_METHOD"=>"GET"
        }
      end

      it "should build payload from default fields" do
        expected_payload = {
          :blog => 'http://my_blog.com', 
          :comment_type => 'Foo',
          :comment_author => 'jriga',
          :comment_author_email => 'jriga@lamit.com',
          :comment_author_url => 'http://www.lamit.com',
          :comment_content => 'blah '* 10
        }
 
        @foo.send(:data).should == expected_payload
      end

      it "should build payload with server params" do
        expected_payload = {
          :blog => 'http://my_blog.com', 
          :comment_type => 'Foo',
          :comment_author => 'paul',
          :comment_author_email => 'jriga@lamit.com',
          :comment_author_url => 'http://www.lamit.com',
          :comment_content => 'blah '* 10,
          :user_ip => '192.168.0.1', 
          :user_agent => 'curl-5', 
          :referrer => '', 
          :permalink => 'http://blog.com/posts/2009/01/21/first-entry',
          "PATH_INFO"=>"/", 
          "REMOTE_HOST"=>"127.0.0.1", 
          "HTTP_USER_AGENT"=>"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.0.5) Gecko/2008120121 Firefox/3.0.5", 
          "HTTP_HOST"=>"localhost:7000",
          "REMOTE_ADDR"=>"127.0.0.1", 
          "HTTP_KEEP_ALIVE"=>"300", 
          "REQUEST_PATH"=>"/", 
          "HTTP_VERSION"=>"HTTP/1.1", 
          "REQUEST_URI"=>"http://localhost:7000/", 
          "QUERY_STRING"=>"", 
          "REQUEST_METHOD"=>"GET"
        }

        server = {
          :comment_author => 'paul',
          :user_ip => '192.168.0.1', 
          :user_agent => 'curl-5', 
          :referrer => '', 
          :permalink => 'http://blog.com/posts/2009/01/21/first-entry'
        }.merge(@server)

        @foo.send(:data,server).should == expected_payload
      end
    end
  end

end

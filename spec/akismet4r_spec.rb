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

      lambda {Akismet4r::Config.config.api_key}.should raise_error(Akismet4r::FieldMissing)
      lambda {Akismet4r::Config.config.blog}.should raise_error(Akismet4r::FieldMissing)

      Akismet4r::Config[:host].should == 'rest.akismet.com'
      Akismet4r::Config[:port].should == 80
      Akismet4r::Config[:version].should == '1.1'
      Akismet4r::Config[:key_verified].should be_false
      Akismet4r::Config[:user_agent].should == 'Akismet4r 2009-01-21'

      lambda {Akismet4r::Config[:api_key]}.should raise_error(Akismet4r::FieldMissing)
      lambda {Akismet4r::Config[:blog]}.should raise_error(Akismet4r::FieldMissing)
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

    class BadFoo
      attr_accessor :author
      include Akismet4r

      map :comment_author, :unknown
    end
    
    before do
      Akismet4r::Config.setup {|c| c.blog = 'http://my_blog.com' }

     @foo = Foo.new
     @foo.author = 'jriga'
     @foo.email = 'jriga@lamit.com'
     @foo.url = 'http://www.lamit.com'
     @foo.text = 'blah '*10
    end

    it "should use user defined mappings to build payload" do
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

    it "should use user defined mappings to build payload even when nil" do
      @foo.author = nil

      expected_payload = {
          :blog => 'http://my_blog.com', 
          :comment_type => 'Foo',
          :comment_author => nil,
          :comment_author_email => 'jriga@lamit.com',
          :comment_author_url => 'http://www.lamit.com',
          :comment_content => 'blah '* 10
      }
 
      @foo.send(:data).should == expected_payload
    end


    it "should raise on bogus custom mapping" do
      bad_foo = BadFoo.new
      lambda { bad_foo.send(:data) }.should raise_error(Akismet4r::MappingError)
    end
  end

  describe '#verify_key' do
    class Baz
      include Akismet4r
    end

     before do
      Akismet4r::Config.setup do |c|
        c.api_key = '1234g54w5g54'
        c.blog = 'http://blog.com'
        c.host = 'http://localhost'
        c.port = 6000
        c.version = '1.2'
      end
    end

    it "should verify api-key" do
      ::RestClient.should_receive(:post).with('http://localhost:6000/1.2/verify-key', {:key => '1234g54w5g54', :blog =>'http://blog.com'}).and_return('valid')
      baz = Baz.new
      baz.send(:verify_key)
      Akismet4r::Config[:key_verified].should be_true
    end

    it "should verify api-key" do
      ::RestClient.should_receive(:post).and_return('invalid')
      baz = Baz.new
      lambda {baz.send(:verify_key)}.should raise_error(Akismet4r::KeyVerificationFailed)
      Akismet4r::Config[:key_verified].should be_false
    end

  end

  describe "::InstanceMethods" do
    class Bar 
      attr_accessor :comment_author, :comment_author_email, :comment_author_url, :comment_content
      include Akismet4r
    end

    before do
      Akismet4r::Config.setup do |c|
        c.api_key = '1234g54w5g54'
        c.blog = 'http://blog.com'
        c.key_verified = true
      end

      @akismet = ::RestClient::Resource.new("http://example.com")
      ::RestClient::Resource.should_receive(:new).any_number_of_times.and_return(@akismet)
      @akismet.stub!(:post).and_return('true')
    end
    
    it "should verify key" do
      Akismet4r::Config.setup {|c| c.key_verified = false}
      bar = Bar.new
      bar.should_receive(:verify_key).and_return(true)
      bar.spam?(:user_ip => '212.32.122.45', :user_agent => 'Firefox')
    end

    describe '#request,spam?,spam!,ham!' do
      it "should check user_ip present" do
        bar = Bar.new
        lambda { bar.spam?(:user_agent => 'Firefox') }.should raise_error(Akismet4r::FieldMissing)
      end

      it "should check user_agent present" do
        bar = Bar.new
        lambda { bar.spam?(:user_ip => '212.32.122.45') }.should raise_error(Akismet4r::FieldMissing)
      end


      it "should detect spam" do
        @akismet.should_receive(:post).and_return('true')
        bar = Bar.new
        bar.spam!(:user_ip => '212.32.122.45', :user_agent => 'Firefox').should be_true
      end

      it "should detect non spam" do
        @akismet.should_receive(:post).and_return('false')
        bar = Bar.new
        bar.ham!(:user_ip => '212.32.122.45', :user_agent => 'Firefox').should be_false
      end
    end

    describe '#data' do
      before do
        Akismet4r::Config.setup {|c| c.blog = 'http://my_blog.com' }

        @bar = Bar.new
        @bar.comment_author = 'jriga'
        @bar.comment_author_email = 'jriga@lamit.com'
        @bar.comment_author_url = 'http://www.lamit.com'
        @bar.comment_content = 'blah '*10
        
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
          :comment_type => 'Bar',
          :comment_author => 'jriga',
          :comment_author_email => 'jriga@lamit.com',
          :comment_author_url => 'http://www.lamit.com',
          :comment_content => 'blah '* 10
        }
 
        @bar.send(:data).should == expected_payload
      end

      it "should build payload from default fields even when nil" do
        @bar.comment_author = nil

        expected_payload = {
          :blog => 'http://my_blog.com', 
          :comment_type => 'Bar',
          :comment_author => nil, 
          :comment_author_email => 'jriga@lamit.com',
          :comment_author_url => 'http://www.lamit.com',
          :comment_content => 'blah '* 10
        }
 
        @bar.send(:data).should == expected_payload
      end


      it "should build payload with server params" do
        expected_payload = {
          :blog => 'http://my_blog.com', 
          :comment_type => 'Bar',
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

        @bar.send(:data,server).should == expected_payload
      end
    end
  end

end

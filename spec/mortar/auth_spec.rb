#
# Copyright 2012 Mortar Data Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Portions of this code from heroku (https://github.com/heroku/heroku/) Copyright Heroku 2008 - 2012,
# used under an MIT license (https://github.com/heroku/heroku/blob/master/LICENSE).
#

require "spec_helper"
require "mortar/auth"
require "mortar/helpers"

module Mortar
  describe Auth do
    include Mortar::Helpers

    before do
      ENV['MORTAR_API_KEY'] = nil
      
      @cli = Mortar::Auth
      stub(@cli).display
      @cli.credentials = nil

      FakeFS.activate!
      
      stub(my_mode_output = Object.new).mode {"0600".to_i(8)}
      stub(FakeFS::File).stat {my_mode_output}
      stub(FakeFS::FileUtils).chmod
      stub(FakeFS::File).readlines do |path|
        File.read(path).split("\n").map {|line| "#{line}\n"}
      end
      
      FileUtils.mkdir_p(@cli.netrc_path.split("/")[0..-2].join("/"))

      File.open(@cli.netrc_path, "w") do |file|
        file.puts("machine api.mortardata.com\n  login user\n  password pass\n")
      end
    end

    after do
      FileUtils.rm_rf(@cli.netrc_path)
      FakeFS.deactivate!
    end

    it "asks for credentials when the file doesn't exist" do
      stub(@cli).check
      @cli.delete_credentials
      mock(@cli).ask_for_credentials {["u", "p"]}
      #@cli.should_receive(:check_for_associated_ssh_key)
      @cli.user.should == 'u'
      @cli.password.should == 'p'
    end

    it "writes credentials and uploads authkey when credentials are saved" do
      stub(@cli).credentials
      stub(@cli).check
      stub(@cli).ask_for_credentials.returns("username", "apikey")
      mock(@cli).write_credentials
      #@cli.should_receive(:check_for_associated_ssh_key)
      @cli.ask_for_and_save_credentials
    end

    it "save_credentials deletes the credentials when the upload authkey is unauthorized" do
      stub(@cli).write_credentials
      stub(@cli).retry_login? { false }
      stub(@cli).ask_for_credentials.returns("username", "apikey")
      stub(@cli).check { raise Mortar::API::Errors::Unauthorized.new("Login Failed", Excon::Response.new) }
      mock.proxy(@cli).delete_credentials
      lambda { @cli.ask_for_and_save_credentials }.should raise_error(SystemExit)
    end

    it "asks for login again when not authorized, for three times" do
      stub(@cli).read_credentials
      stub(@cli).write_credentials
      stub(@cli).delete_credentials
      #stub(@cli).ask_for_credentials.returns("username", "apikey")
      stub(@cli).check { raise Mortar::API::Errors::Unauthorized.new("Login Failed", Excon::Response.new) }
      mock(@cli).ask_for_credentials.times(3).returns("username", "apikey")
      lambda { @cli.ask_for_and_save_credentials }.should raise_error(SystemExit)
    end

    it "writes the login information to the credentials file for the 'mortar login' command" do
      stub(@cli).ask_for_credentials.returns(['one', 'two'])
      stub(@cli).check
      #@cli.should_receive(:check_for_associated_ssh_key)
      @cli.reauthorize
      Netrc.read(@cli.netrc_path)["api.#{@cli.host}"].should == (['one', 'two'])
    end

    it "prompts for github_username when user doesn't have one." do
      user_id = "123456789"
      new_github_username = "some_new_github_username"
      task_id = "1a2b3c4d"
      stub(@cli).polling_interval.returns(0.05)

      mock(@cli).ask_for_credentials.returns("username", "apikey")
      stub(@cli).write_credentials
      mock(@cli.api).get_user().times(2) {Excon::Response.new(:body => {"user_id" => user_id, "user_email" => "foo@foo.com"})}
      mock(@cli).ask_for_github_username.returns(new_github_username)

      mock(@cli.api).update_user(user_id,{"user_github_username" => new_github_username}) {Excon::Response.new(:body => {"task_id" => task_id})}

      mock(@cli.api).get_task(task_id).returns(Excon::Response.new(:body => {"task_id" => task_id, "status_code" => "QUEUED"})).ordered
      mock(@cli.api).get_task(task_id).returns(Excon::Response.new(:body => {"task_id" => task_id, "status_code" => "PROGRESS"})).ordered
      mock(@cli.api).get_task(task_id).returns(Excon::Response.new(:body => {"task_id" => task_id, "status_code" => "SUCCESS"})).ordered

      @cli.ask_for_and_save_credentials
    end

    it "remove credentials when call to set github_username fails" do
      user_id = "abcdef"
      new_github_username = "some_new_github_username"
      task_id = "1a2b3c4d5e"
      stub(@cli).polling_interval.returns(0.05)
      mock(@cli).retry_set_github_username?.returns(false)


      mock(@cli).ask_for_credentials.returns("username", "apikey")
      stub(@cli).write_credentials
      mock(@cli.api).get_user().times(2) {Excon::Response.new(:body => {"user_id" => user_id, "user_email" => "foo@foo.com", "github_team_state" => "active"})}
      mock(@cli).ask_for_github_username.returns(new_github_username)

      mock(@cli.api).update_user(user_id,{"user_github_username" => new_github_username}) {Excon::Response.new(:body => {"task_id" => task_id})}

      mock(@cli.api).get_task(task_id).returns(Excon::Response.new(:body => {"task_id" => task_id, "status_code" => "QUEUED"})).ordered
      mock(@cli.api).get_task(task_id).returns(Excon::Response.new(:body => {"task_id" => task_id, "status_code" => "PROGRESS"})).ordered
      mock(@cli.api).get_task(task_id).returns(Excon::Response.new(:body => {"task_id" => task_id, "status_code" => "FAILURE"})).ordered

      mock(@cli).delete_credentials

      lambda { @cli.ask_for_and_save_credentials }.should raise_error(SystemExit)
    end

    it "try 3 times to get github username" do
      user_id = "abcdefghijkl"

      mock(@cli.api).get_user() {Excon::Response.new(:body => {"user_id" => user_id, "user_email" => "foo@foo.com"})}

      stub(@cli).ask_for_and_save_github_username.times(3).returns { raise Mortar::CLI::Errors::InvalidGithubUsername.new }

      lambda { @cli.check }.should raise_error(Mortar::CLI::Errors::InvalidGithubUsername)
    end

    it "encodes the user email as s3 safe" do
      user_email = "myemail+dontspam@somedomain.com"
      stub(@cli).user.returns(user_email)
      @cli.user().should == user_email
      @cli.user_s3_safe.should == 'myemail-dontspam-somedomain-com'
    end

    it "is true if the user is currently logged in" do
      # login (aka writing the auth file) is done in setup
      expect(@cli.has_credentials).to be_true
    end

    it "is false if the user is not logged in" do
     @cli.logout
      expect(@cli.has_credentials).to be_false
    end

    it "uses path from env when specified" do
      netrc_path = '/foo/bar/baz'
      ENV['MORTAR_LOGIN_FILE'] = netrc_path
      expect(@cli.netrc_path).to eq(netrc_path)
      ENV.delete('MORTAR_LOGIN_FILE')
    end

    it "uses the default path when no environment setting" do
      FakeFS do
        expect(@cli.netrc_path).to eq(Netrc.default_path)
      end
    end

    it "does not prompt for username in local mode if user not logged in" do
      @cli.user(true).should == 'notloggedin@user.org'
      @cli.user_s3_safe(true).should == 'notloggedin-user-org'
    end

    it "does not prompt for password in local mode if user not logged in" do
      @cli.password(true).should == 'notloggedin'
    end
  end
end

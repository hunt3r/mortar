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
require "mortar/command/base"

module Mortar::Command
  describe Base do
    before do
      @base = Base.new
      stub(@base).display
      @client = Object.new
      stub(@client).host {'mortar.com'}
    end
    
    context "error message context" do
      it "get context for missing parameter error message" do
        message = "Undefined parameter : INPUT"
        @base.get_error_message_context(message).should == "Use -p, --parameter NAME=VALUE to set parameter NAME to value VALUE."
      end
      
      it "get context for unhandled error message" do
        message = "special kind of error"
        @base.get_error_message_context(message).should == ""
      end
    end

    context "detecting the project" do
      it "read remotes from git config" do
        stub(Dir).chdir
        stub(@base.git).has_dot_git? {true}
        mock(@base.git).git("remote -v").returns(<<-REMOTES)
staging\tgit@github.com:mortarcode/4dbbd83cae8d5bf8a4000000_myproject-staging.git (fetch)
staging\tgit@github.com:mortarcode/4dbbd83cae8d5bf8a4000000_myproject-staging.git (push)
production\tgit@github.com:mortarcode/4dbbd83cae8d5bf8a4000000_myproject.git (fetch)
production\tgit@github.com:mortarcode/4dbbd83cae8d5bf8a4000000_myproject.git (push)
other\tgit@github.com:other.git (fetch)
other\tgit@github.com:other.git (push)
        REMOTES

        @mortar = Object.new
        stub(@mortar).host {'mortar.com'}
        stub(@base).mortar { @mortar }

        # need a better way to test internal functionality
        @base.git.send(:remotes, 'mortarcode').should == { 'staging' => 'myproject-staging', 'production' => 'myproject' }
      end

      it "gets the project from remotes when there's only one project" do
        stub(@base.git).has_dot_git? {true}
        stub(@base.git).remotes {{ 'mortar' => 'myproject' }}
        mock(@base.git).git("config mortar.remote", false).returns("")
        @base.project.name.should == 'myproject'
      end

      it "accepts a --remote argument to choose the project from the remote name" do
        stub(@base.git).has_dot_git?.returns(true)
        stub(@base.git).remotes.returns({ 'staging' => 'myproject-staging', 'production' => 'myproject' })
        stub(@base).options.returns(:remote => "staging")
        @base.project.name.should == 'myproject-staging'
      end

    end

    context "load_defaults" do
      it "no errors with no .mortar-defaults file" do
        with_git_initialized_project do |p|
          b = Base.new
          b.options.should == {}
        end
      end

      it "loads default only params" do
        with_git_initialized_project do |p|
          text = """
[DEFAULTS]
pigversion=0.12

[other]
no_browser=True
"""
          write_file(File.join(p.root_path, ".mortar-defaults"), text)

          b = Base.new
          b.options.should == {:pigversion => "0.12"}
        end
      end

      it "loads default only params with script" do
        stub_core
        git = Mortar::Git::Git.new

        with_git_initialized_project do |p|
          text = """
[DEFAULTS]
pigversion=0.12

[other]
no_browser=True
"""
          write_file(File.join(p.root_path, ".mortar-defaults"), text)

          describe_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          describe_url = "https://api.mortardata.com/describe/#{describe_id}"

          mock(Mortar::Auth.api).post_describe("myproject", "my_script", "my_alias", is_a(String), :parameters=>[]) {Excon::Response.new(:body => {"describe_id" => describe_id})}
          mock(Mortar::Auth.api).get_describe(describe_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Describe::STATUS_SUCCESS, "status_description" => "Success", "web_result_url" => describe_url})).ordered
          mock(Launchy).open(describe_url) {Thread.new {}}

          write_file(File.join(p.pigscripts_path, "my_script.pig"))

          stderr, stdout, d = execute_and_return_command("describe pigscripts/my_script.pig my_alias --polling_interval 0.05", p, git)
          d.options.should == {:pigversion => "0.12", :polling_interval => "0.05"}
        end
      end

      it "loads params for script" do
        stub_core
        git = Mortar::Git::Git.new

        with_git_initialized_project do |p|
          text = """
[DEFAULTS]
pigversion=0.12

[my_script]
no_browser=True
"""
          write_file(File.join(p.root_path, ".mortar-defaults"), text)

          describe_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          describe_url = "https://api.mortardata.com/describe/#{describe_id}"

          mock(Mortar::Auth.api).post_describe("myproject", "my_script", "my_alias", is_a(String), :parameters=>[]) {Excon::Response.new(:body => {"describe_id" => describe_id})}
          mock(Mortar::Auth.api).get_describe(describe_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Describe::STATUS_SUCCESS, "status_description" => "Success", "web_result_url" => describe_url})).ordered
          write_file(File.join(p.pigscripts_path, "my_script.pig"))

          stderr, stdout, d = execute_and_return_command("describe pigscripts/my_script.pig my_alias --polling_interval 0.05", p, git)
          d.options.should == {:pigversion => "0.12", :polling_interval => "0.05", :no_browser => "True"}
        end
      end

      it "obeys proper overrides" do
        stub_core
        git = Mortar::Git::Git.new

        with_git_initialized_project do |p|
          text = """
[DEFAULTS]
clustersize=5
no_browser=True

[my_script]
clustersize=10
polling_interval=10
"""
          write_file(File.join(p.root_path, ".mortar-defaults"), text)

          describe_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          describe_url = "https://api.mortardata.com/describe/#{describe_id}"

          mock(Mortar::Auth.api).post_describe("myproject", "my_script", "my_alias", is_a(String), :parameters=>[]) {Excon::Response.new(:body => {"describe_id" => describe_id})}
          mock(Mortar::Auth.api).get_describe(describe_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Describe::STATUS_SUCCESS, "status_description" => "Success", "web_result_url" => describe_url})).ordered
          write_file(File.join(p.pigscripts_path, "my_script.pig"))

          stderr, stdout, d = execute_and_return_command("describe pigscripts/my_script.pig my_alias --polling_interval 0.05", p, git)
          d.options.should == {:polling_interval => "0.05", :no_browser => "True", :clustersize => "10"}
        end
      end

    end

  end
end

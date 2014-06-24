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

      it "gets the project from remotes when there's two projects but one mortar remote" do
        stub(@base.git).has_dot_git? {true}
        stub(@base.git).remotes {{ 'mortar' => 'myproject', 'base' => 'my-base-project'}}
        mock(@base.git).git("config mortar.remote", false).returns("")
        @base.project.name.should == 'myproject'
      end

      it "accepts a --remote argument to choose the project from the remote name" do
        stub(@base.git).has_dot_git?.returns(true)
        stub(@base.git).remotes.returns({ 'staging' => 'myproject-staging', 'production' => 'myproject' })
        stub(@base).options.returns(:remote => "staging")
        @base.project.name.should == 'myproject-staging'
      end

      it "errors out on checking for updates to forked project and nobody cares" do
        stub(@base.git).has_dot_git? {true}
        stub(@base.git).remotes {{ 'mortar' => 'myproject' }}
        mock(@base.git).git("config mortar.remote", false).returns("")
        mock(@base.git).is_fork_repo_updated.with_any_args.returns { raise StandardError.new("meessage") }
        mock(@base).warning.times(0)
        @base.project.name.should == 'myproject'
      end

      it "finds an updated forked project and displays warning" do
        stub(@base.git).has_dot_git? {true}
        stub(@base.git).remotes {{ 'mortar' => 'myproject' }}
        mock(@base.git).git("config mortar.remote", false).returns("")
        mock(@base.git).is_fork_repo_updated.with_any_args.returns(true)
        mock(@base).warning.times(1).with_any_args
        @base.project.name.should == 'myproject'
      end

    end

    context "method_added" do
      it "replaces help templates" do
        lines = Base.replace_templates(["line", "start <PIG_VERSION_OPTIONS>"])
        lines.join("").should == 'linestart 0.9 (default) and 0.12 (beta)'
      end
    end

    context "config_parameters" do
      it "handles when not in mortar project" do
        stub_core
        @base.config_parameters.should == []
      end

      it "handles when in valid mortar project that isn't registered" do
        with_blank_project_with_name('proj_name') do |p|
          stub_core
          mock(Mortar::Auth.api).get_config_vars('proj_name').returns { raise Mortar::API::Errors::ErrorWithResponse.new("meessage",400) }
          @base.config_parameters.should == []
        end
      end

      it "works" do
         with_blank_project_with_name('proj_name') do |p|
          stub_core
          configs = {"foo" => "ABCDEFGHIJKLMNOP", "BAR" => "sheepdog"}
          mock(Mortar::Auth.api).get_config_vars("proj_name").returns(Excon::Response.new(:body => {"config" => configs}))
          @base.config_parameters.should =~ [{"name"=>"foo", "value"=>"ABCDEFGHIJKLMNOP"},
                                             {"name"=>"BAR", "value"=>"sheepdog"}]
        end
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
no_browser=true
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
no_browser=true
"""
          write_file(File.join(p.root_path, ".mortar-defaults"), text)

          describe_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          describe_url = "https://api.mortardata.com/describe/#{describe_id}"

          mock(Mortar::Auth.api).post_describe("myproject", "my_script", "my_alias", is_a(String), :pig_version => "0.12", :project_script_path => be_a_kind_of(String), :parameters=>[]) {Excon::Response.new(:body => {"describe_id" => describe_id})}
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
no_browser=true
"""
          write_file(File.join(p.root_path, ".mortar-defaults"), text)

          describe_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          describe_url = "https://api.mortardata.com/describe/#{describe_id}"

          mock(Mortar::Auth.api).post_describe("myproject", "my_script", "my_alias", is_a(String), :pig_version => "0.12", :project_script_path => be_a_kind_of(String), :parameters=>[]) {Excon::Response.new(:body => {"describe_id" => describe_id})}
          mock(Mortar::Auth.api).get_describe(describe_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Describe::STATUS_SUCCESS, "status_description" => "Success", "web_result_url" => describe_url})).ordered
          write_file(File.join(p.pigscripts_path, "my_script.pig"))

          stderr, stdout, d = execute_and_return_command("describe pigscripts/my_script.pig my_alias --polling_interval 0.05", p, git)
          d.options.should == {:pigversion => "0.12", :polling_interval => "0.05", :no_browser => true}
        end
      end

      it "obeys proper overrides - deprecated file" do
        stub_core
        git = Mortar::Git::Git.new

        with_git_initialized_project do |p|
          text = """
[DEFAULTS]
clustersize=5
no_browser=true

[my_script]
clustersize=10
polling_interval=10
"""
          write_file(File.join(p.root_path, ".mortar-defaults"), text)

          describe_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          describe_url = "https://api.mortardata.com/describe/#{describe_id}"

          mock(Mortar::Auth.api).post_describe("myproject", "my_script", "my_alias", is_a(String), :pig_version => "0.9", :project_script_path => be_a_kind_of(String), :parameters=>[]) {Excon::Response.new(:body => {"describe_id" => describe_id})}
          mock(Mortar::Auth.api).get_describe(describe_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Describe::STATUS_SUCCESS, "status_description" => "Success", "web_result_url" => describe_url})).ordered
          write_file(File.join(p.pigscripts_path, "my_script.pig"))

          stderr, stdout, d = execute_and_return_command("describe pigscripts/my_script.pig my_alias --polling_interval 0.05", p, git)
          d.options.should == {:polling_interval => "0.05", :no_browser => true, :clustersize => "10"}
        end
      end

      it "obeys proper overrides" do
        stub_core
        git = Mortar::Git::Git.new

        with_git_initialized_project do |p|
          text = """
[DEFAULTS]
clustersize=5
no_browser=true
pigversion=0.12
"""
          write_file(File.join(p.root_path, "project.properties"), text)

          describe_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          describe_url = "https://api.mortardata.com/describe/#{describe_id}"

          mock(Mortar::Auth.api).post_describe("myproject", "my_script", "my_alias", is_a(String), :pig_version => "0.12", :project_script_path => be_a_kind_of(String), :parameters=>[]) {Excon::Response.new(:body => {"describe_id" => describe_id})}
          mock(Mortar::Auth.api).get_describe(describe_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Describe::STATUS_SUCCESS, "status_description" => "Success", "web_result_url" => describe_url})).ordered
          write_file(File.join(p.pigscripts_path, "my_script.pig"))

          stderr, stdout, d = execute_and_return_command("describe pigscripts/my_script.pig my_alias --polling_interval 0.05", p, git)
          d.options.should == {:polling_interval => "0.05", :no_browser => true, :clustersize => "5", :pigversion => "0.12"}
        end
      end

    end

  end
end

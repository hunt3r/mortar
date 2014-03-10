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

require 'spec_helper'
require 'fakefs/spec_helpers'
require 'mortar/local/controller'
require 'mortar/auth'
require 'mortar/command/base'
require 'launchy'
require 'excon'

module Mortar::Local
  describe Controller do

    before do
      stub_core
      ENV['AWS_ACCESS_KEY'] = "foo"
      ENV['AWS_SECRET_KEY'] = "BAR"
    end

    context("aws keys") do        
      it "exits if they are not present and not logged in" do
        ENV.delete('AWS_ACCESS_KEY')
        ctrl = Mortar::Local::Controller.new
        previous_stderr, $stderr = $stderr, StringIO.new
        mock(Mortar::Auth).has_credentials{false}
        begin
          expect { ctrl.require_aws_keys }.to raise_error(SystemExit)
          $stderr.string.should eq(Mortar::Local::Controller::NO_AWS_KEYS_ERROR_MESSAGE.gsub(/^/, " !    "))
        ensure
          $stderr = previous_stderr
        end
      end

      it "exits if keys are not present, not logged in and api fails to return keys" do 
        ENV.delete('AWS_ACCESS_KEY')
        ctrl = Mortar::Local::Controller.new
        previous_stderr, $stderr = $stderr, StringIO.new
        mock(Mortar::Auth).has_credentials{true}
        stub(Mortar::Command::Base).new {'base'}
        mock(ctrl).fetch_aws_keys(Mortar::Auth, 'base'){{}}
        begin
          expect { ctrl.require_aws_keys }.to raise_error(SystemExit)
          $stderr.string.should eq(Mortar::Local::Controller::API_CONFIG_ERROR_MESSAGE.gsub(/^/, " !    "))
        ensure
          $stderr = previous_stderr
        end
      end

      it "returns if they are present" do
        ctrl = Mortar::Local::Controller.new
        previous_stderr, $stderr = $stderr, StringIO.new
        begin
          ctrl.require_aws_keys()
          $stderr.string.should eq("")
        ensure
          $stderr = previous_stderr
        end
      end
      
      it "sets fetches and sets aws keys if missing and logged in" do
        ENV.delete('AWS_ACCESS_KEY')
        ctrl = Mortar::Local::Controller.new
        stub(Mortar::Command::Base).new {'base'}
        stub(Mortar::Auth).has_credentials{true}
        previous_stderr, $stderr = $stderr, StringIO.new
        mock(ctrl).fetch_aws_keys(Mortar::Auth, 'base'){ 
          {
            "aws_access_key_id"=>"key_id", 
            "aws_secret_access_key"=>"secret"
          }
        }
        begin
          ctrl.require_aws_keys()
          $stderr.string.should eq("")
          ENV['AWS_ACCESS_KEY'].should eq("key_id")
          ENV['AWS_SECRET_KEY'].should eq("secret")
        ensure
          $stderr = previous_stderr
        end
      end


    
      it "fetches aws keys" do
        ctrl = Mortar::Local::Controller.new
        auth = Mortar::Auth        
        

        with_blank_project do
          base = Mortar::Command::Base.new             
          with_git_initialized_project do |p|
            # stub api request
            configs = {}
            mock(Mortar::Auth.api).get_config_vars("myproject").returns(Excon::Response.new(:body => {"config" => configs}))
            
            ctrl.fetch_aws_keys(auth,base).should eq(configs)
          end          
        end        
      end


      it "returns if they are not present but override is in place" do
        ENV.delete('AWS_ACCESS_KEY')
        ENV['MORTAR_IGNORE_AWS_KEYS'] = 'true'
        ctrl = Mortar::Local::Controller.new
        previous_stderr, $stderr = $stderr, StringIO.new
        begin
          ctrl.require_aws_keys()
          $stderr.string.should eq("")
        ensure
          $stderr = previous_stderr
        end
      end      

    end

    context("install_and_configure") do
      it "supplied default pig version" do
        ctrl = Mortar::Local::Controller.new

        any_instance_of(Mortar::Local::Java) do |j|
          mock(j).check_install.returns(true)
        end
        any_instance_of(Mortar::Local::Pig) do |p|
          mock(p).install_or_update(is_a(Mortar::PigVersion::Pig09), nil)
        end
        any_instance_of(Mortar::Local::Python) do |p|
          mock(p).check_or_install.returns(true)
          mock(p).check_virtualenv.returns(true)
          mock(p).setup_project_python_environment.returns(true)
        end
        any_instance_of(Mortar::Local::Jython) do |j|
          mock(j).install_or_update
        end
        mock(ctrl).ensure_local_install_dirs_in_gitignore
        ctrl.install_and_configure
      end
    end

    context("run") do

      it "checks for aws keys, checks depenendency installation, runs script" do
        c = Mortar::Local::Controller.new
        mock(c).require_aws_keys
        mock(c).install_and_configure("0.9", "run")
        test_script = "foobar-script"
        the_parameters = []
        any_instance_of(Mortar::Local::Pig) do |p|
          mock(p).run_script(test_script, "0.9", the_parameters)
        end
        c.run(test_script, "0.9", the_parameters)
      end

    end

    context("illustrate") do
      it "checks for aws keys, checks depenendency installation, runs the illustrate process" do
        c = Mortar::Local::Controller.new
        mock(c).require_aws_keys
        mock(c).install_and_configure("0.9", "illustrate")
        test_script = "foobar-script"
        script_alias = "some_alias"
        prune = false
        no_browser = false
        the_parameters = []
        any_instance_of(Mortar::Local::Pig) do |p|
          mock(p).illustrate_alias(test_script, script_alias, prune, no_browser, "0.9", the_parameters)
        end
        c.illustrate(test_script, script_alias, "0.9", the_parameters, prune, no_browser)
      end
    end

  end
end

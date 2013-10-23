#
# Copyright 2013 Mortar Data Inc.
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
# Portions of this code from heroku (https://github.com/heroku/heroku/) Copyright Heroku 2008 - 2013,
# used under an MIT license (https://github.com/heroku/heroku/blob/master/LICENSE).
#

require "spec_helper"
require "mortar/command/config"

module Mortar::Command
  describe Config do
    before(:each) do
      stub_core      
      @git = Mortar::Git::Git.new
    end

    context("index") do
      it "shows an empty collection of configs" do
        with_git_initialized_project do |p|
          # stub api request
          configs = {}
          mock(Mortar::Auth.api).get_config_vars("myproject").returns(Excon::Response.new(:body => {"config" => configs}))
       
          stderr, stdout = execute("config",  p, @git)
          stdout.should == <<-STDOUT
myproject has no config vars.
STDOUT
        end
      end
    
      it "shows a populated collection of configs" do
        with_git_initialized_project do |p|
          # stub api request
          configs = {"foo" => "ABCDEFGHIJKLMNOP", "BAR" => "sheepdog"}
          mock(Mortar::Auth.api).get_config_vars("myproject").returns(Excon::Response.new(:body => {"config" => configs}))
       
          stderr, stdout = execute("config",  p, @git)
          stdout.should == <<-STDOUT
=== myproject Config Vars
BAR: sheepdog
foo: ABCDEFGHIJKLMNOP
STDOUT
        end
      end
      
      it "does not trim long values" do
        with_git_initialized_project do |p|
          # stub api request
          configs = {'LONG' => 'A' * 60 }
          mock(Mortar::Auth.api).get_config_vars("myproject").returns(Excon::Response.new(:body => {"config" => configs}))
       
          stderr, stdout = execute("config",  p, @git)
          stdout.should == <<-STDOUT
=== myproject Config Vars
LONG: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
STDOUT
        end
      end
      
      it "handles when value is nil" do
        with_git_initialized_project do |p|
          # stub api request
          configs = { 'FOO_BAR' => 'one', 'BAZ_QUX' => nil }
          mock(Mortar::Auth.api).get_config_vars("myproject").returns(Excon::Response.new(:body => {"config" => configs}))
       
          stderr, stdout = execute("config",  p, @git)
          stdout.should == <<-STDOUT
=== myproject Config Vars
BAZ_QUX: 
FOO_BAR: one
STDOUT
        end
      end
      
      it "handles when value is a boolean" do
        with_git_initialized_project do |p|
          # stub api request
          configs = {'FOO_BAR' => 'one', 'BAZ_QUX' => true}
          mock(Mortar::Auth.api).get_config_vars("myproject").returns(Excon::Response.new(:body => {"config" => configs}))
       
          stderr, stdout = execute("config",  p, @git)
          stdout.should == <<-STDOUT
=== myproject Config Vars
BAZ_QUX: true
FOO_BAR: one
STDOUT
        end
      end
      
      it "shows configs in a shell compatible format" do
        with_git_initialized_project do |p|
          # stub api request
          configs = {'A' => 'one', 'B' => 'two three'}
          mock(Mortar::Auth.api).get_config_vars("myproject").returns(Excon::Response.new(:body => {"config" => configs}))
       
          stderr, stdout = execute("config --shell",  p, @git)
          stdout.should == <<-STDOUT
A=one
B=two three
STDOUT
        end
      end
    end
  end
end

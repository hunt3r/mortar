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
require 'mortar/command/local'
require 'launchy'

module Mortar::Command
  describe Local do

    context("illustrate") do
      it "errors when the script doesn't exist" do
        with_git_initialized_project do |p|
          write_file(File.join(p.pigscripts_path, "my_other_script.pig"))
          stderr, stdout = execute("local:illustrate pigscripts/my_script.pig some_alias", p)
          stderr.should == <<-STDERR
 !    Unable to find pigscript pigscripts/my_script.pig
 !    Available scripts:
 !    pigscripts/my_other_script.pig
STDERR
        end
      end

      it "calls the illustrate command when envoked with an alias" do
        with_git_initialized_project do |p|
          script_name = "some_script"
          script_path = File.join(p.pigscripts_path, "#{script_name}.pig")
          write_file(script_path)
          pigscript = Mortar::Project::PigScript.new(script_name, script_path)
          mock(Mortar::Project::PigScript).new(script_name, script_path).returns(pigscript)
          any_instance_of(Mortar::Local::Controller) do |u|
            mock(u).illustrate(pigscript, "some_alias", [], false).returns(nil)
          end
          stderr, stdout = execute("local:illustrate #{script_name} some_alias", p)
          stderr.should == ""
        end
      end

      it "calls the illustrate command when envoked without an alias" do
        with_git_initialized_project do |p|
          script_name = "some_script"
          script_path = File.join(p.pigscripts_path, "#{script_name}.pig")
          write_file(script_path)
          pigscript = Mortar::Project::PigScript.new(script_name, script_path)
          mock(Mortar::Project::PigScript).new(script_name, script_path).returns(pigscript)
          any_instance_of(Mortar::Local::Controller) do |u|
            mock(u).illustrate(pigscript, nil, [], false).returns(nil)
          end
          stderr, stdout = execute("local:illustrate #{script_name}", p)
          stderr.should == ""
        end
      end

    # illustrate
    end

    context("run") do

      it "errors when the script doesn't exist" do
        with_git_initialized_project do |p|
          write_file(File.join(p.pigscripts_path, "my_other_script.pig"))
          write_file(File.join(p.controlscripts_path, "my_control_script.py"))
          stderr, stdout = execute("local:run pigscripts/my_script.pig", p)
          stderr.should == <<-STDERR
 !    Unable to find a pigscript or controlscript for pigscripts/my_script.pig
 !    
 !    Available pigscripts:
 !    pigscripts/my_other_script.pig
 !    
 !    Available controlscripts:
 !    controlscripts/my_control_script.pig
STDERR
        end
      end

      it "calls the run command when envoked correctly" do
        with_git_initialized_project do |p|
          script_name = "some_script"
          script_path = File.join(p.pigscripts_path, "#{script_name}.pig")
          write_file(script_path)
          pigscript = Mortar::Project::PigScript.new(script_name, script_path)
          mock(Mortar::Project::PigScript).new(script_name, script_path).returns(pigscript)
          any_instance_of(Mortar::Local::Controller) do |u|
            mock(u).run(pigscript, []).returns(nil)
          end
          stderr, stdout = execute("local:run pigscripts/#{script_name}.pig", p)
          stderr.should == ""
        end
      end
    # run
    end

    context("configure") do

      it "errors if the project root doesn't exist or we can't cd there" do
        stderr, stdout = execute("local:configure --project-root /foo/baz")
        stderr.should == " !    No such directory /foo/baz\n"
      end

      it "errors if java can't be found" do
        any_instance_of(Mortar::Local::Java) do |j|
          stub(j).check_install.returns(false)
        end
        stderr, stdout = execute("local:configure")
        stderr.should == Mortar::Local::Controller::NO_JAVA_ERROR_MESSAGE.gsub(/^/, " !    ")
      end

      it "errors if python can't be found" do
        any_instance_of(Mortar::Local::Java) do |j|
          stub(j).check_install.returns(true)
        end
        any_instance_of(Mortar::Local::Pig) do |j|
          stub(j).install.returns(true)
        end
        any_instance_of(Mortar::Local::Python) do |j|
          stub(j).check_or_install.returns(false)
        end
        stderr, stdout = execute("local:configure")
        stderr.should == Mortar::Local::Controller::NO_PYTHON_ERROR_MESSAGE.gsub(/^/, " !    ")
      end

      it "checks for java, installs pig/python, and configures a virtualenv" do
        any_instance_of(Mortar::Local::Java) do |j|
          mock(j).check_install.returns(true)
        end
        any_instance_of(Mortar::Local::Pig) do |j|
          mock(j).install.returns(true)
        end
        any_instance_of(Mortar::Local::Python) do |j|
          mock(j).check_or_install.returns(true)
          mock(j).check_virtualenv.returns(true)
          mock(j).setup_project_python_environment.returns(true)
        end
        any_instance_of(Mortar::Local::Jython) do |j|
          mock(j).install_or_update.returns(true)
        end
        any_instance_of(Mortar::Local::Controller) do |j|
          mock(j).ensure_local_install_dirs_in_gitignore.returns(true)
        end
        stderr, stdout = execute("local:configure")
        stderr.should == ""
      end

    # configure
    end

    context "local:validate" do

      it "Runs pig with the -check command option for deprecated no-path pigscript syntax" do
        with_git_initialized_project do |p|
          script_name = "some_script"
          script_path = File.join(p.pigscripts_path, "#{script_name}.pig")
          write_file(script_path)
          pigscript = Mortar::Project::PigScript.new(script_name, script_path)
          mock(Mortar::Project::PigScript).new(script_name, script_path).returns(pigscript)
          any_instance_of(Mortar::Local::Controller) do |u|
            mock(u).install_and_configure
          end
          any_instance_of(Mortar::Local::Pig) do |u|
            mock(u).run_pig_command(" -check #{pigscript.path}", [])
          end
          stderr, stdout = execute("local:validate #{script_name}", p)
          stderr.should == ""
        end
      end

      it "Runs pig with the -check command option for new full-path pigscript syntax" do
        with_git_initialized_project do |p|
          script_name = "some_script"
          script_path = File.join(p.pigscripts_path, "#{script_name}.pig")
          write_file(script_path)
          pigscript = Mortar::Project::PigScript.new(script_name, script_path)
          mock(Mortar::Project::PigScript).new(script_name, script_path).returns(pigscript)
          any_instance_of(Mortar::Local::Controller) do |u|
            mock(u).install_and_configure
          end
          any_instance_of(Mortar::Local::Pig) do |u|
            mock(u).run_pig_command(" -check #{pigscript.path}", [])
          end
          stderr, stdout = execute("local:validate pigscripts/#{script_name}.pig", p)
          stderr.should == ""
        end
      end

    end

  end
end


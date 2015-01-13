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

require "spec_helper"
require "mortar/generators/generator_base"
require "mortar/command/generate"
require "fileutils"
require "tmpdir"

describe Mortar::Command::Generate do

  before(:each) do
    @tmpdir = Dir.mktmpdir
    Dir.chdir(@tmpdir)
  end

  describe "generate:project" do
    it "creates new project" do
      stderr, stdout = execute("generate:project Test")
      File.exists?("Test").should be_true
      File.exists?("Test/macros").should be_true
      File.exists?("Test/pigscripts").should be_true
      File.exists?("Test/udfs").should be_true
      File.exists?("Test/README.md").should be_true
      File.exists?("Test/Gemfile").should be_false
      File.exists?("Test/macros/.gitkeep").should be_true
      File.exists?("Test/pigscripts/Test.pig").should be_true
      File.exists?("Test/udfs/python/Test.py").should be_true
      File.exists?("Test/luigiscripts/README").should be_true
      File.exists?("Test/sparkscripts/README").should be_true

      File.read("Test/pigscripts/Test.pig").each_line { |line| line.match(/<%.*%>/).should be_nil }
    end

    it "error when name isn't provided" do
      stderr, stdout = execute("generate:project")
      stderr.should == <<-STDERR
 !    Usage: mortar generate:project PROJECTNAME
 !    Must specify PROJECTNAME.
STDERR
    end

    it 'removes project directory when generate:project fails' do
      any_instance_of(Mortar::Generators::Base) do |base|
        stub(base).copy_file { raise Mortar::Command::CommandFailed, 'Bad Copy'}
      end
      begin
        stderr, stdout = execute("generate:project Test")
      rescue => e
        e.message.should == 'Bad Copy'
      end
      File.exists?("Test").should be_false
    end

    it 'does not remove pre-existing project directory when generate:project fails' do
      FileUtils.mkdir("Test")
      any_instance_of(Mortar::Generators::Base) do |base|
        stub(base).copy_file { raise Mortar::Command::CommandFailed, 'Bad Copy'}
      end
      begin
        stderr, stdout = execute("generate:project Test")
      rescue => e
        e.message.should == 'Bad Copy'
      end
      File.exists?("Test").should be_true
    end
  end

  describe "generate:pigscript" do
    it "Generate a new pigscript in a project" do
      with_blank_project do |p| 
        stderr, stdout = execute("generate:pigscript Oink", p)
        File.exists?(File.join(p.root_path, "pigscripts/Oink.pig")).should be_true
        File.read("pigscripts/Oink.pig").each_line { |line| line.match(/<%.*%>/).should be_nil }
      end
    end

    it "error when pigscript name isn't provided" do
      with_blank_project do |p|
        stderr, stdout = execute("generate:pigscript")
        stderr.should == <<-STDERR
 !    Usage: mortar generate:pigscript SCRIPTNAME
 !    Must specify SCRIPTNAME.
 STDERR
      end
    end
  end

  describe "generate:controlscript" do
    it "Generate a new controlscript in a project" do
      with_blank_project do |p| 
        stderr, stdout = execute("generate:controlscript Oink", p)
        File.exists?(File.join(p.root_path, "controlscripts/Oink.py")).should be_true
        File.read("controlscripts/Oink.py").each_line { |line| line.match(/<%.*%>/).should be_nil }
      end
    end

    it "error when controlscript name isn't provided" do
      with_blank_project do |p|
        stderr, stdout = execute("generate:controlscript")
        stderr.should == <<-STDERR
 !    Usage: mortar generate:controlscript SCRIPTNAME
 !    Must specify SCRIPTNAME.
 STDERR
      end
    end
  end

  describe "generate:python_udf" do
    it "Generate a new python udf in a project" do
      with_blank_project do |p| 
        stderr, stdout = execute("generate:python_udf slither", p)
        File.exists?(File.join(p.root_path, "udfs/python/slither.py")).should be_true
        File.read("udfs/python/slither.py").each_line { |line| line.match(/<%.*%>/).should be_nil }
      end
    end

    it "error when udf name isn't provided" do
      with_blank_project do |p|
        stderr, stdout = execute("generate:python_udf")
        stderr.should == <<-STDERR
 !    Usage: mortar generate:python_udf UDFNAME
 !    Must specify UDFNAME.
 STDERR
      end
    end
  end

  describe "generate:macro" do
    it "Generate a new macro in a project" do
      with_blank_project do |p| 
        stderr, stdout = execute("generate:macro big_mac", p)
        File.exists?(File.join(p.root_path, "macros/big_mac.pig")).should be_true
        File.read("macros/big_mac.pig").each_line { |line| line.match(/<%.*%>/).should be_nil }
      end
    end

    it "error when udf name isn't provided" do
      with_blank_project do |p|
        stderr, stdout = execute("generate:macro")
        stderr.should == <<-STDERR
 !    Usage: mortar generate:macro MACRONAME
 !    Must specify MACRONAME.
 STDERR
      end
    end
  end
end
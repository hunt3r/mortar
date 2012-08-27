require "spec_helper"
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
      File.exists?("Test/Gemfile").should be_true
      #File.exists?("Test/Gemfile.lock").should be_true
      File.exists?("Test/macros/.gitkeep").should be_true
      File.exists?("Test/pigscripts/Test.pig").should be_true
      File.exists?("Test/udfs/python/Test.py").should be_true

      File.read("Test/pigscripts/Test.pig").each_line { |line| line.match(/<%.*%>/).should be_nil }
    end
    it "error when name isn't provided" do
      stderr, stdout = execute("generate:project")
      stderr.should == <<-STDERR
 !    Usage: mortar new PROJECTNAME
 !    Must specify PROJECTNAME.
STDERR
    end
  end

  describe "new" do
    it "create new project using alias" do
      stderr, stdout = execute("new Test")
      File.exists?("Test").should be_true
      File.exists?("Test/macros").should be_true
      File.exists?("Test/pigscripts").should be_true
      File.exists?("Test/udfs").should be_true
      File.exists?("Test/README.md").should be_true
      File.exists?("Test/Gemfile").should be_true
      #File.exists?("Test/Gemfile.lock").should be_true
      File.exists?("Test/macros/.gitkeep").should be_true
      File.exists?("Test/pigscripts/Test.pig").should be_true
      File.exists?("Test/udfs/python/Test.py").should be_true
    end

    it "error when name isn't provided" do
      stderr, stdout = execute("new")
      stderr.should == <<-STDERR
 !    Usage: mortar new PROJECTNAME
 !    Must specify PROJECTNAME.
STDERR
    end
  end

  describe "generate:pigscript" do
    it "Generate a new pigscript in a project" do
      with_blank_project do |p| 
        stderr, stdout = execute("generate:pigscript Oink", p)
        File.exists?(File.join(p.root_path, "pigscripts/Oink.pig")).should be_true
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

  describe "generate:python_udf" do
    it "Generate a new python udf in a project" do
      with_blank_project do |p| 
        stderr, stdout = execute("generate:python_udf slither", p)
        File.exists?(File.join(p.root_path, "udfs/python/slither.py")).should be_true
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
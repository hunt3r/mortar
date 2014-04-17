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
require 'fileutils'

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
          any_instance_of(Mortar::Command::Local) do |u|
            mock(u).config_parameters.returns([])
          end
          any_instance_of(Mortar::Local::Controller) do |u|
            mock(u).illustrate(pigscript, "some_alias", is_a(Mortar::PigVersion::Pig09), [], false, false).returns(nil)
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
          any_instance_of(Mortar::Command::Local) do |u|
            mock(u).config_parameters.returns([])
          end
          any_instance_of(Mortar::Local::Controller) do |u|
            mock(u).illustrate(pigscript, nil, is_a(Mortar::PigVersion::Pig012), [], false, false).returns(nil)
          end
          stderr, stdout = execute("local:illustrate #{script_name} -g 0.12", p)
          stderr.should == ""
        end
      end

      it "puts config params before pig params" do
        with_git_initialized_project do |p|
          script_name = "some_script"
          script_path = File.join(p.pigscripts_path, "#{script_name}.pig")
          write_file(script_path)
          pigscript = Mortar::Project::PigScript.new(script_name, script_path)
          any_instance_of(Mortar::Command::Local) do |u|
            mock(u).config_parameters.returns([{"name"=>"first", "value"=>1}])
            mock(u).pig_parameters.returns([{"name"=>"second", "value"=>2}])
          end
          mock(Mortar::Project::PigScript).new(script_name, script_path).returns(pigscript)
          any_instance_of(Mortar::Local::Controller) do |u|
            mock(u).illustrate(pigscript, nil, is_a(Mortar::PigVersion::Pig012), [{"name"=>"first", "value"=>1},{"name"=>"second", "value"=>2}], false, false).returns(nil)
          end
          stderr, stdout = execute("local:illustrate #{script_name} -g 0.12", p)
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
          any_instance_of(Mortar::Command::Local) do |u|
            mock(u).config_parameters.returns([])
          end
          any_instance_of(Mortar::Local::Controller) do |u|
            mock(u).run(pigscript, is_a(Mortar::PigVersion::Pig09), []).returns(nil)
          end
          stderr, stdout = execute("local:run pigscripts/#{script_name}.pig -g 0.9", p)
          stderr.should == ""
        end
      end
    # run
    end

    context("characterize") do
      # TODO - oleiman: some tests for characterize should go here

      it "should clean up after itself" do
        @tmpdir = Dir.mktmpdir
        Dir.chdir(@tmpdir)

        File.open("test.params", 'w') do |file|
          file.write(<<PARAMS
LOADER=org.apache.pig.piggybank.storage.JsonLoader()
INPUT_SRC=s3n://twitter-gardenhose-mortar/example
OUTPUT_PATH=twitter_char
INFER_TYPES=true
PARAMS
          )
        end
        stderr, stdout = execute("generate:project Test")
        stderr, stdout = execute("local:characterize -f test.params --project_root Test")
        File.exists?("Test/pigscripts/characterize.pig").should be_false
        File.exists?("Test/macros/characterize_macro.pig").should be_false
        File.exists?("Test/udfs/jython/top_5_tuple.py").should be_false
        File.exists?("Test/controlscripts/lib/characterize_control.py").should be_false
        File.delete("test.params")           
      end

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
          stub(j).install_pig.returns(true)
          stub(j).install_lib.returns(true)
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
          mock(j).install_pig.with_any_args.returns(true)
          stub(j).install_lib.returns(true)
        end
        any_instance_of(Mortar::Local::Python) do |j|
          mock(j).check_or_install.returns(true)
          mock(j).check_virtualenv.returns(true)
          mock(j).setup_project_python_environment.returns(true)
        end
        any_instance_of(Mortar::Local::Jython) do |j|
          mock(j).install_or_update.returns(true)
        end
        any_instance_of(Mortar::Local::Sqoop) do |j|
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

          any_instance_of(Mortar::Command::Local) do |u|
            mock(u).config_parameters.returns([{"key"=>"k", "value"=>"v"}])
          end
          any_instance_of(Mortar::Local::Controller) do |u|
            mock(u).install_and_configure(is_a(Mortar::PigVersion::Pig09), 'validate')
          end
          any_instance_of(Mortar::Local::Pig) do |u|
            mock(u).run_pig_command(" -check #{pigscript.path}", is_a(Mortar::PigVersion::Pig09), [{"key"=>"k", "value"=>"v"}])
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
          any_instance_of(Mortar::Command::Local) do |u|
            mock(u).config_parameters.returns([])
          end
          any_instance_of(Mortar::Local::Controller) do |u|
            mock(u).install_and_configure(is_a(Mortar::PigVersion::Pig09), 'validate')
          end
          any_instance_of(Mortar::Local::Pig) do |u|
            mock(u).run_pig_command(" -check #{pigscript.path}", is_a(Mortar::PigVersion::Pig09), [])
          end
          stderr, stdout = execute("local:validate pigscripts/#{script_name}.pig", p)
          stderr.should == ""
        end
      end

    end

    context "local:luigi" do

      it "Exits with error if no script specified" do
        with_git_initialized_project do |p|
          stderr, stdout = execute("local:luigi", p)
          stderr.should == <<-STDERR
 !    Usage: mortar local:luigi SCRIPT
 !    Must specify SCRIPT.
STDERR
        end
      end

      it "Exits with error if script doesn't exist" do
        with_git_initialized_project do |p|
          stderr, stdout = execute("local:luigi foobarbaz", p)
          stderr.should == <<-STDERR
 !    Unable to find luigiscript foobarbaz
 !    No luigiscripts found
STDERR
        end
      end

      it "Runs script forwarding options to luigi script" do
        with_git_initialized_project do |p|
          script_name = "some_luigi_script"
          script_path = File.join(p.luigiscripts_path, "#{script_name}.py")
          write_file(script_path)
          luigi_script = Mortar::Project::LuigiScript.new(script_name, script_path)
          mock(Mortar::Project::LuigiScript).new(script_name, script_path).returns(luigi_script)
          any_instance_of(Mortar::Local::Python) do |u|
            mock(u).run_luigi_script(luigi_script, %W{--myoption 2 --myotheroption 3})
          end
          any_instance_of(Mortar::Local::Controller) do |u|
            mock(u).install_and_configure(nil,'luigi')
          end
          stderr, stdout = execute("local:luigi some_luigi_script -p myoption=2 -p myotheroption=3", p)
          stderr.should == ""
        end
      end


    end

    context "local:sqoop_table" do
      it "requires a db type" do
          stderr, stdout = execute "local:sqoop_table"
          stderr.should == <<-STDERR
 !    Usage: mortar local:sqoop_table dbtype database-name table s3-destination
 !    Must specify database type.
STDERR
      end

      it "requires the physical db name" do
          stderr, stdout = execute "local:sqoop_table mysql"
          stderr.should == <<-STDERR
 !    Usage: mortar local:sqoop_table dbtype database-name table s3-destination
 !    Must specify database name.
STDERR
      end

      it "requires the table name" do
          stderr, stdout = execute "local:sqoop_table mysql myappdb"
          stderr.should == <<-STDERR
 !    Usage: mortar local:sqoop_table dbtype database-name table s3-destination
 !    Must specify database table.
STDERR
      end

      it "requires the s3 destination" do
          stderr, stdout = execute "local:sqoop_table mysql myappdb customers"
          stderr.should == <<-STDERR
 !    Usage: mortar local:sqoop_table dbtype database-name table s3-destination
 !    Must specify s3 destination.
STDERR
      end

      it "sends everything to the controller" do
        connstr = "jdbc:mysql://foobar.com/mydb?zeroDateTimeBehavior=convertToNull"
        dbtable = "customers"
        s3dest = "s3n://a-bucket/a-directory"
        any_instance_of(Mortar::Local::Controller) do |c|
          mock(c).sqoop_export_table(connstr, dbtable, s3dest, {})
        end
        stderr, stdout = execute "local:sqoop_table mysql mydb #{dbtable} #{s3dest} --host foobar.com"
      end

      it "defaults to 'localhost' if no host specified" do
        connstr = "jdbc:mysql://localhost/mydb?zeroDateTimeBehavior=convertToNull"
        dbtable = "customers"
        s3dest = "s3n://a-bucket/a-directory"
        any_instance_of(Mortar::Local::Controller) do |c|
          mock(c).sqoop_export_table(connstr, dbtable, s3dest, {})
        end
        stderr, stdout = execute "local:sqoop_table mysql mydb #{dbtable} #{s3dest}"
      end

    end

    context "local:sqoop_query" do
      it "requires a db type" do
          stderr, stdout = execute "local:sqoop_query"
          stderr.should == <<-STDERR
 !    Usage: mortar local:sqoop_query dbtype database-name query s3-destination
 !    Must specify database type.
STDERR
      end

      it "requires the physical db name" do
          stderr, stdout = execute "local:sqoop_query mysql"
          stderr.should == <<-STDERR
 !    Usage: mortar local:sqoop_query dbtype database-name query s3-destination
 !    Must specify database name.
STDERR
      end

      it "requires the table name" do
          stderr, stdout = execute "local:sqoop_query mysql myappdb"
          stderr.should == <<-STDERR
 !    Usage: mortar local:sqoop_query dbtype database-name query s3-destination
 !    Must specify sql query.
STDERR
      end

      it "requires the s3 destination" do
          stderr, stdout = execute "local:sqoop_query mysql myappdb customers"
          stderr.should == <<-STDERR
 !    Usage: mortar local:sqoop_query dbtype database-name query s3-destination
 !    Must specify s3 destination.
STDERR
      end

      it "sends everything to the controller" do
        connstr = "jdbc:mysql://foobar.com/mydb?zeroDateTimeBehavior=convertToNull"
        query = "select_*_from_customers"
        s3dest = "s3n://a-bucket/a-directory"
        any_instance_of(Mortar::Local::Controller) do |c|
          mock(c).sqoop_export_query(connstr, query, s3dest, {})
        end
        stderr, stdout = execute "local:sqoop_query mysql mydb #{query} #{s3dest} --host foobar.com"
        stderr.should == ''
      end

      it "defaults to 'localhost' if no host specified" do
        connstr = "jdbc:mysql://localhost/mydb?zeroDateTimeBehavior=convertToNull"
        query = "select_*_from_customers"
        s3dest = "s3n://a-bucket/a-directory"
        any_instance_of(Mortar::Local::Controller) do |c|
          mock(c).sqoop_export_query(connstr, query, s3dest, {})
        end
        stderr, stdout = execute "local:sqoop_query mysql mydb #{query} #{s3dest}"
        stderr.should == ''
      end

    end

    context "local:sqoop_incremental" do
      it "requires a db type" do
          stderr, stdout = execute "local:sqoop_incremental"
          stderr.should == <<-STDERR
 !    Usage: mortar local:sqoop_incremental dbtype database-name table column value s3-destination
 !    Must specify database type.
STDERR
      end

      it "requires the physical db name" do
          stderr, stdout = execute "local:sqoop_incremental mysql"
          stderr.should == <<-STDERR
 !    Usage: mortar local:sqoop_incremental dbtype database-name table column value s3-destination
 !    Must specify database name.
STDERR
      end

      it "requires the table name" do
          stderr, stdout = execute "local:sqoop_incremental mysql myappdb"
          stderr.should == <<-STDERR
 !    Usage: mortar local:sqoop_incremental dbtype database-name table column value s3-destination
 !    Must specify database table.
STDERR
      end

      it "requires the column name" do
          stderr, stdout = execute "local:sqoop_incremental mysql myappdb mytable"
          stderr.should == <<-STDERR
 !    Usage: mortar local:sqoop_incremental dbtype database-name table column value s3-destination
 !    Must specify column.
STDERR
      end

      it "requires the column value" do
          stderr, stdout = execute "local:sqoop_incremental mysql myappdb mytable mycolumn"
          stderr.should == <<-STDERR
 !    Usage: mortar local:sqoop_incremental dbtype database-name table column value s3-destination
 !    Must specify value.
STDERR
      end

      it "requires the s3 destination" do
          stderr, stdout = execute "local:sqoop_incremental mysql myappdb mytable mycolumn customers"
          stderr.should == <<-STDERR
 !    Usage: mortar local:sqoop_incremental dbtype database-name table column value s3-destination
 !    Must specify s3 destination.
STDERR
      end

      it "sends everything to the controller" do
        connstr = "jdbc:mysql://foobar.com/mydb?zeroDateTimeBehavior=convertToNull"
        dbtable = "customers"
        column = "customer_id"
        column_value = "12345"
        s3dest = "s3n://a-bucket/a-directory"
        any_instance_of(Mortar::Local::Controller) do |c|
          mock(c).sqoop_export_incremental(connstr, dbtable, column, column_value, s3dest, {})
        end
        stderr, stdout = execute "local:sqoop_incremental mysql mydb #{dbtable} #{column} #{column_value} #{s3dest} --host foobar.com"
      end

      it "defaults to 'localhost' if no host specified" do
        connstr = "jdbc:mysql://localhost/mydb?zeroDateTimeBehavior=convertToNull"
        dbtable = "customers"
        column = "customer_id"
        column_value = "12345"
        s3dest = "s3n://a-bucket/a-directory"
        any_instance_of(Mortar::Local::Controller) do |c|
          mock(c).sqoop_export_incremental(connstr, dbtable, column, column_value, s3dest, {})
        end
        stderr, stdout = execute "local:sqoop_incremental mysql mydb #{dbtable} #{column} #{column_value} #{s3dest}"
      end

    end



  end
end


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
require 'mortar/command/illustrate'
require 'mortar/api/illustrate'
require 'launchy'

module Mortar::Command
  describe Illustrate do
    
    before(:each) do
      stub_core      
      @git = Mortar::Git::Git.new
    end
        
    context("index") do
      it "errors when no remote exists in the project" do
        with_git_initialized_project do |p|
          @git.git('remote rm mortar')
          p.remote = nil
          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("illustrate pigscripts/my_script.pig my_alias", p, @git)
          stderr.should == <<-STDERR
 !    Unable to find git remote for project myproject.
 !    
 !    Do 'mortar projects -h' for help creating a new Mortar project or linking to an existing Mortar project.
STDERR
        end
      end

      it "errors when requested pigscript cannot be found" do
        with_git_initialized_project do |p|
          stderr, stdout = execute("illustrate pigscripts/does_not_exist.pig my_alias", p, @git)
          stderr.should == <<-STDERR
 !    Unable to find a pigscript or controlscript for pigscripts/does_not_exist.pig
 !    
 !    No pigscripts found
 !    
 !    No controlscripts found
 STDERR
        end
      end
      
      it "errors when requested with controlscript" do
        with_git_initialized_project do |p|
          write_file(File.join(p.controlscripts_path, "my_script.py"))
          stderr, stdout = execute("illustrate pigscripts/my_script.pig my_alias", p, @git)
          stderr.should == <<-STDERR
 !    Currently Mortar does not support illustrating control scripts
 STDERR
        end
      end
      
      it "requests and reports on a successful illustrate using deprecated no-path pigscript syntax" do
        with_git_initialized_project do |p|
          # stub api requests
          illustrate_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          illustrate_url = "https://api.mortardata.com/illustrates/#{illustrate_id}"
          parameters = ["name"=>"key", "value"=>"value" ]
          
          # These don't test the validity of the error message, it only tests that the CLI can handle a message returned from the server
          mock(Mortar::Auth.api).post_illustrate("myproject", "my_script", "my_alias", false, is_a(String), :pig_version => "0.9", :parameters => parameters) {Excon::Response.new(:body => {"illustrate_id" => illustrate_id})}
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_QUEUED,           "status_description" => "Pending"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_GATEWAY_STARTING, "status_description" => "GATEWAY_STARTING"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_PROGRESS,         "status_description" => "In progress"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_READING_DATA,     "status_description" => "Reading data"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_PRUNING_DATA,     "status_description" => "Pruning data"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_SUCCESS,          "status_description" => "Succeeded", "web_result_url" => illustrate_url})).ordered
          
          # stub launchy
          mock(Launchy).open(illustrate_url) {Thread.new {}}
                    
          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("illustrate my_script my_alias --polling_interval 0.05 -p key=value", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Starting illustrate... done

\r\e[0KStatus: Pending... /\r\e[0KStatus: GATEWAY_STARTING... -\r\e[0KStatus: In progress... \\\r\e[0KStatus: Reading data... |\r\e[0KStatus: Pruning data... /\r\e[0KStatus: Succeeded  

Results available at https://api.mortardata.com/illustrates/c571a8c7f76a4fd4a67c103d753e2dd5
Opening web browser to show results... done
STDOUT
        end
      end

      it "requests and reports on a successful illustrate using new full-path pigscript syntax" do
        with_git_initialized_project do |p|
          # stub api requests
          illustrate_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          illustrate_url = "https://api.mortardata.com/illustrates/#{illustrate_id}"
          parameters = ["name"=>"key", "value"=>"value" ]
          
          # These don't test the validity of the error message, it only tests that the CLI can handle a message returned from the server
          mock(Mortar::Auth.api).post_illustrate("myproject", "my_script", "my_alias", false, is_a(String), :pig_version => "0.9", :parameters => parameters) {Excon::Response.new(:body => {"illustrate_id" => illustrate_id})}
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_QUEUED,           "status_description" => "Pending"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_GATEWAY_STARTING, "status_description" => "GATEWAY_STARTING"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_PROGRESS,         "status_description" => "In progress"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_READING_DATA,     "status_description" => "Reading data"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_PRUNING_DATA,     "status_description" => "Pruning data"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_SUCCESS,          "status_description" => "Succeeded", "web_result_url" => illustrate_url})).ordered
          
          # stub launchy
          mock(Launchy).open(illustrate_url) {Thread.new {}}
                    
          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("illustrate pigscripts/my_script.pig my_alias --polling_interval 0.05 -p key=value", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Starting illustrate... done

\r\e[0KStatus: Pending... /\r\e[0KStatus: GATEWAY_STARTING... -\r\e[0KStatus: In progress... \\\r\e[0KStatus: Reading data... |\r\e[0KStatus: Pruning data... /\r\e[0KStatus: Succeeded  

Results available at https://api.mortardata.com/illustrates/c571a8c7f76a4fd4a67c103d753e2dd5
Opening web browser to show results... done
STDOUT
        end
      end

      it "requests and reports on a successful illustrate without a browser" do
        with_git_initialized_project do |p|
          # stub api requests
          illustrate_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          illustrate_url = "https://api.mortardata.com/illustrates/#{illustrate_id}"
          parameters = ["name"=>"key", "value"=>"value" ]
          
          # These don't test the validity of the error message, it only tests that the CLI can handle a message returned from the server
          mock(Mortar::Auth.api).post_illustrate("myproject", "my_script", "my_alias", false, is_a(String), :pig_version => "0.9", :parameters => parameters) {Excon::Response.new(:body => {"illustrate_id" => illustrate_id})}
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_QUEUED,           "status_description" => "Pending"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_SUCCESS,          "status_description" => "Succeeded", "web_result_url" => illustrate_url})).ordered
                    
          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("illustrate pigscripts/my_script.pig my_alias --polling_interval 0.05 -p key=value --no_browser", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Starting illustrate... done

\r\e[0KStatus: Pending... /\r\e[0KStatus: Succeeded  

Results available at https://api.mortardata.com/illustrates/c571a8c7f76a4fd4a67c103d753e2dd5
STDOUT
        end
      end


      it "requests and reports on a successful illustrate that skips pruning" do
        with_git_initialized_project do |p|
          # stub api requests
          illustrate_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          illustrate_url = "https://api.mortardata.com/illustrates/#{illustrate_id}"
          parameters = ["name"=>"key", "value"=>"value" ]
          
          # These don't test the validity of the error message, it only tests that the CLI can handle a message returned from the server
          mock(Mortar::Auth.api).post_illustrate("myproject", "my_script", "my_alias", true, is_a(String), :pig_version => "0.9", :parameters => parameters) {Excon::Response.new(:body => {"illustrate_id" => illustrate_id})}
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_QUEUED,           "status_description" => "Pending"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_SUCCESS,          "status_description" => "Succeeded", "web_result_url" => illustrate_url})).ordered
                    
          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("illustrate pigscripts/my_script.pig my_alias --polling_interval 0.05 -p key=value -s --no_browser", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Starting illustrate... done

\r\e[0KStatus: Pending... /\r\e[0KStatus: Succeeded  

Results available at https://api.mortardata.com/illustrates/c571a8c7f76a4fd4a67c103d753e2dd5
STDOUT
        end
      end

      it "requests and reports on a successful illustrate without an alias" do
        with_git_initialized_project do |p|
          # stub api requests
          illustrate_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          illustrate_url = "https://api.mortardata.com/illustrates/#{illustrate_id}"
          parameters = ["name"=>"key", "value"=>"value" ]
          
          # These don't test the validity of the error message, it only tests that the CLI can handle a message returned from the server
          mock(Mortar::Auth.api).post_illustrate("myproject", "my_script", nil, false, is_a(String), :pig_version => "0.9", :parameters => parameters) {Excon::Response.new(:body => {"illustrate_id" => illustrate_id})}
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_QUEUED,           "status_description" => "Pending"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_GATEWAY_STARTING, "status_description" => "GATEWAY_STARTING"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_PROGRESS,         "status_description" => "In progress"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_READING_DATA,     "status_description" => "Reading data"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_PRUNING_DATA,     "status_description" => "Pruning data"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_SUCCESS,          "status_description" => "Succeeded", "web_result_url" => illustrate_url})).ordered
          
          # stub launchy
          mock(Launchy).open(illustrate_url) {Thread.new {}}
                    
          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("illustrate pigscripts/my_script.pig --polling_interval 0.05 -p key=value", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Starting illustrate... done

\r\e[0KStatus: Pending... /\r\e[0KStatus: GATEWAY_STARTING... -\r\e[0KStatus: In progress... \\\r\e[0KStatus: Reading data... |\r\e[0KStatus: Pruning data... /\r\e[0KStatus: Succeeded  

Results available at https://api.mortardata.com/illustrates/c571a8c7f76a4fd4a67c103d753e2dd5
Opening web browser to show results... done
STDOUT
        end
      end
      
      it "requests and reports on a failed illustrate" do
        with_git_initialized_project do |p|
          # stub api requests
          illustrate_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          
          error_message = "This is my error message\nWith multiple lines."
          line_number = 23
          column_number = 32
          error_type = 'PigError'
          
          # These don't test the validity of the error message, it only tests that the CLI can handle a message returned from the server
          mock(Mortar::Auth.api).post_illustrate("myproject", "my_script", "my_alias", false, is_a(String), :pig_version => "0.9", :parameters => []) {Excon::Response.new(:body => {"illustrate_id" => illustrate_id})}
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_QUEUED,  "status_description" => "Pending"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_FAILURE, 
            "error_message" => error_message,
            "line_number" => line_number,
            "column_number" => column_number,
            "error_type" => error_type,
            "status_description" => "Failed"})).ordered

          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("illustrate pigscripts/my_script.pig my_alias --polling_interval 0.05", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Starting illustrate... done

\r\e[0KStatus: Pending... /\r\e[0KStatus: Failed  

STDOUT
          stderr.should == <<-STDERR
 !    Illustrate failed with PigError at Line 23, Column 32:
 !    
 !    This is my error message
 !    With multiple lines.
STDERR
        end
      end

      it "requests and reports an illustrate for an embedded project" do
        with_embedded_project do |p|
          # stub api requests
          illustrate_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          illustrate_url = "https://api.mortardata.com/illustrates/#{illustrate_id}"
          parameters = ["name"=>"key", "value"=>"value" ]
          
          # These don't test the validity of the error message, it only tests that the CLI can handle a message returned from the server
          mock(Mortar::Auth.api).post_illustrate("myproject", "my_script", nil, false, is_a(String), :pig_version => "0.9", :parameters => parameters) {Excon::Response.new(:body => {"illustrate_id" => illustrate_id})}
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_QUEUED,           "status_description" => "Pending"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_GATEWAY_STARTING, "status_description" => "GATEWAY_STARTING"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_PROGRESS,         "status_description" => "In progress"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_READING_DATA,     "status_description" => "Reading data"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_PRUNING_DATA,     "status_description" => "Pruning data"})).ordered
          mock(Mortar::Auth.api).get_illustrate(illustrate_id, :exclude_result => true).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Illustrate::STATUS_SUCCESS,          "status_description" => "Succeeded", "web_result_url" => illustrate_url})).ordered
          
          mock(@git).sync_embedded_project.with_any_args.times(1) { "somewhere_over_the_rainbow" }

          # stub launchy
          mock(Launchy).open(illustrate_url) {Thread.new {}}
                    
          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("illustrate pigscripts/my_script.pig --polling_interval 0.05 -p key=value", p, @git)
        end
      end
    end
  end
end

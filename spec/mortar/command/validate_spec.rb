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
require 'mortar/command/validate'
require 'mortar/api/validate'
require 'launchy'

module Mortar::Command
  describe Validate do
    
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
          stderr, stdout = execute("validate my_script", p, @git)
          stderr.should == <<-STDERR
 !    Unable to find git remote for project myproject.
 !    
 !    Do 'mortar projects -h' for help creating a new Mortar project or linking to an existing Mortar project.
STDERR
        end
      end

      it "errors when requested pigscript cannot be found" do
        with_git_initialized_project do |p|
          stderr, stdout = execute("validate does_not_exist", p, @git)
          stderr.should == <<-STDERR
 !    Unable to find a pigscript or controlscript for does_not_exist
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
          stderr, stdout = execute("validate my_script", p, @git)
          stderr.should == <<-STDERR
 !    Currently Mortar does not support validating control scripts
 STDERR
        end
      end
      
      it "requests and reports on a successful validate" do
        with_git_initialized_project do |p|
          # stub api requests
          validate_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          parameters = ["name"=>"key", "value"=>"value" ]

          mock(Mortar::Auth.api).post_validate("myproject", "my_script", is_a(String), :pig_version => "0.9", :project_script_path => be_a_kind_of(String), :parameters => parameters) {Excon::Response.new(:body => {"validate_id" => validate_id})}
          mock(Mortar::Auth.api).get_validate(validate_id).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Validate::STATUS_QUEUED, "status_description" => "Pending"})).ordered
          mock(Mortar::Auth.api).get_validate(validate_id).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Validate::STATUS_GATEWAY_STARTING, "status_description" => "GATEWAY_STARTING"})).ordered
          mock(Mortar::Auth.api).get_validate(validate_id).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Validate::STATUS_PROGRESS, "status_description" => "Starting"})).ordered
          mock(Mortar::Auth.api).get_validate(validate_id).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Validate::STATUS_SUCCESS, "status_description" => "Success"})).ordered
                              
          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("validate my_script --polling_interval 0.05 -p key=value", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Starting validate... done

\r\e[0K[/] Checking your script for problems with: Pig syntax, Python syntax, and S3 data access\r\e[0K[-] Checking your script for problems with: Pig syntax, Python syntax, and S3 data access\r\e[0K[\\] Checking your script for problems with: Pig syntax, Python syntax, and S3 data access\r\e[0K[|] Checking your script for problems with: Pig syntax, Python syntax, and S3 data access

Your script is valid.
STDOUT
        end
      end
      
      it "requests and reports on a failed validate" do
        with_git_initialized_project do |p|
          # stub api requests
          validate_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          
          error_message = "This is my error message\nWith multiple lines."
          line_number = 23
          column_number = 32
          error_type = 'PigError'
          
          mock(Mortar::Auth.api).post_validate("myproject", "my_script", is_a(String), :pig_version => "0.9", :project_script_path => be_a_kind_of(String), :parameters => []) {Excon::Response.new(:body => {"validate_id" => validate_id})}
          mock(Mortar::Auth.api).get_validate(validate_id).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Validate::STATUS_QUEUED, "status_description" => "Pending"})).ordered
          mock(Mortar::Auth.api).get_validate(validate_id).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Validate::STATUS_FAILURE, "status_description" => "Failed",
            "error_message" => error_message,
            "line_number" => line_number,
            "column_number" => column_number,
            "error_type" => error_type})).ordered

          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("validate my_script --polling_interval 0.05", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Starting validate... done

\r\e[0K[/] Checking your script for problems with: Pig syntax, Python syntax, and S3 data access\r\e[0K[-] Checking your script for problems with: Pig syntax, Python syntax, and S3 data access

STDOUT
          stderr.should == <<-STDERR
 !    Validate failed with PigError at Line 23, Column 32:
 !    
 !    This is my error message
 !    With multiple lines.
STDERR
        end
      end
    end

    it "requests and reports a validate for an embedded project" do
      with_embedded_project do |p|
        # stub api requests
        validate_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
        parameters = ["name"=>"key", "value"=>"value" ]
        
        mock(Mortar::Auth.api).post_validate("myproject", "my_script", is_a(String), :pig_version => "0.12", :project_script_path => be_a_kind_of(String), :parameters => parameters) {Excon::Response.new(:body => {"validate_id" => validate_id})}
        mock(Mortar::Auth.api).get_validate(validate_id).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Validate::STATUS_QUEUED, "status_description" => "Pending"})).ordered
        mock(Mortar::Auth.api).get_validate(validate_id).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Validate::STATUS_GATEWAY_STARTING, "status_description" => "GATEWAY_STARTING"})).ordered
        mock(Mortar::Auth.api).get_validate(validate_id).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Validate::STATUS_PROGRESS, "status_description" => "Starting"})).ordered
        mock(Mortar::Auth.api).get_validate(validate_id).returns(Excon::Response.new(:body => {"status_code" => Mortar::API::Validate::STATUS_SUCCESS, "status_description" => "Success"})).ordered
        
        mock(@git).sync_embedded_project.with_any_args.times(1) { "somewhere_over_the_rainbow" }

        write_file(File.join(p.pigscripts_path, "my_script.pig"))
        stderr, stdout = execute("validate my_script --polling_interval 0.05 -p key=value -g 0.12", p, @git)
      end
    end
  end
end

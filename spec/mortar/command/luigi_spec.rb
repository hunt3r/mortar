#
# Copyright 2014 Mortar Data Inc.
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
require 'mortar/command/luigi'
require 'mortar/api/jobs'

module Mortar::Command
  describe Luigi do
    
    before(:each) do
      stub_core      
      @git = Mortar::Git::Git.new
    end
    
    context("index") do
      it "shows help when user adds help argument" do
        with_git_initialized_project do |p|
          stderr_dash_h, stdout_dash_h = execute("luigi -h", p, @git) 
          stderr_help, stdout_help = execute("luigi help", p, @git)
          stdout_dash_h.should == stdout_help
          stderr_dash_h.should == stderr_help
        end
      end

      it "runs a luigi job with no parameters" do
        with_git_initialized_project do |p|
          # stub api requests
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/pipeline_job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          mock(Mortar::Auth.api).post_luigi_job("myproject", "my_script", is_a(String),
            :project_script_path => be_a_kind_of(String),
            :parameters => match_array([])
          ) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.luigiscripts_path, "my_script.py"))
          stderr, stdout = execute("luigi luigiscripts/my_script.py", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/pipeline_job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

STDOUT
        end
      end

      it "runs a luigi job with luigi-style parameters" do
        with_git_initialized_project do |p|
          # stub api requests
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/pipeline_job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          mock(Mortar::Auth.api).post_luigi_job("myproject", "my_script", is_a(String),
            :project_script_path => be_a_kind_of(String),
            :parameters => match_array([{"name" => "my-luigi-parameter", "value" => "elephant"},
                                        {"name" => "my-luigi-parameter-2", "value" => "14"}])
          ) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.luigiscripts_path, "my_script.py"))
          stderr, stdout = execute("luigi luigiscripts/my_script.py --my-luigi-parameter elephant --my-luigi-parameter-2 14", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/pipeline_job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

STDOUT
        end
      end

      it "errors when parameter does not have dash-dash at beginning of name" do
        with_git_initialized_project do |p|
          write_file(File.join(p.luigiscripts_path, "my_script.py"))
          stderr, stdout = execute("luigi luigiscripts/my_script.py my-luigi-parameter-missing-dashdash", p, @git)
          stdout.should == ""
          stderr.should == <<-STDERR
 !    Luigi parameter my-luigi-parameter-missing-dashdash must begin with --
STDERR
        end
      end

      it "errors when no value provided for parameter" do
        with_git_initialized_project do |p|
          write_file(File.join(p.luigiscripts_path, "my_script.py"))
          stderr, stdout = execute("luigi luigiscripts/my_script.py --p1 withvalue --p2", p, @git)
          stdout.should == ""
          stderr.should == <<-STDERR
 !    No value provided for luigi parameter --p2
STDERR
        end
      end

    end
  end
end

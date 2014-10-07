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
require 'mortar/command/jobs'
require 'mortar/api/jobs'

module Mortar::Command
  describe Jobs do
    
    before(:each) do
      stub_core      
      @git = Mortar::Git::Git.new
    end
        
    context("index") do
      it "shows help when user adds help argument" do
        with_git_initialized_project do |p|
          stderr_dash_h, stdout_dash_h = execute("jobs -h", p, @git) 
          stderr_help, stdout_help = execute("jobs help", p, @git)
          stdout_dash_h.should == stdout_help
          stderr_dash_h.should == stderr_help
        end
      end
    end
    
    context("run") do
      it "handles singlejobcluster parameter" do
        with_git_initialized_project do |p|
          # stub api requests
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          cluster_size = 5

          mock(Mortar::Auth.api).post_pig_job_new_cluster("myproject", "my_script", is_a(String), cluster_size, 
            :pig_version => "0.9",
            :project_script_path => be_a_kind_of(String),
            :parameters => match_array([{"name" => "FIRST_PARAM", "value" => "FOO"}, {"name" => "SECOND_PARAM", "value" => "BAR"}]), 
            :cluster_type => Jobs::CLUSTER_TYPE__SINGLE_JOB,
            :notify_on_job_finish => true,
            :is_control_script=> false,
            :use_spot_instances => false) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("jobs:run pigscripts/my_script.pig -1 --clustersize 5 -p FIRST_PARAM=FOO -p SECOND_PARAM=BAR", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

Or by running:

  mortar jobs:status c571a8c7f76a4fd4a67c103d753e2dd5 --poll

STDOUT
        end
      end

      it "handles permanentcluster parameter" do
        with_git_initialized_project do |p|
          # stub api requests
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          cluster_size = 5

          mock(Mortar::Auth.api).post_pig_job_new_cluster("myproject", "my_script", is_a(String),cluster_size,
                                                      :pig_version => "0.9", 
                                                      :project_script_path => be_a_kind_of(String),
                                                      :parameters => match_array([{"name" => "FIRST_PARAM", "value" => "FOO"}, {"name" => "SECOND_PARAM", "value" => "BAR"}]),
                                                      :cluster_type => Jobs::CLUSTER_TYPE__PERMANENT,
                                                      :notify_on_job_finish => true,
                                                      :is_control_script=> false,
                                                      :use_spot_instances => false) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("jobs:run pigscripts/my_script.pig -2 --clustersize 5 -p FIRST_PARAM=FOO -p SECOND_PARAM=BAR", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

Or by running:

  mortar jobs:status c571a8c7f76a4fd4a67c103d753e2dd5 --poll

          STDOUT
        end
      end


      it "throws error on singlejobcluster and permanentcluster" do
        with_git_initialized_project do |p|

          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("jobs:run pigscripts/my_script.pig -2 -1 --clustersize 5 -p FIRST_PARAM=FOO -p SECOND_PARAM=BAR", p, @git)
          stderr.should == <<-STDERR
 !    Cannot declare cluster as both --singlejobcluster and --permanentcluster
STDERR
        end
      end

      it "throws error on clusterid and permanentcluster" do
        with_git_initialized_project do |p|
          cluster_id = "e2790e7e8c7d48e39157238d58191346"

          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("jobs:run pigscripts/my_script.pig -2 --clusterid e2790e7e8c7d48e39157238d58191346 -p FIRST_PARAM=FOO -p SECOND_PARAM=BAR", p, @git)
          stderr.should == <<-STDERR
 !    Option permanentcluster cannot be set when running a job on an existing cluster (with --clusterid option)
          STDERR
        end
      end

      it "runs a job on a new cluster" do
        with_git_initialized_project do |p|
          # stub api requests
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          cluster_size = 5

          mock(Mortar::Auth.api).post_pig_job_new_cluster("myproject", "my_script", is_a(String),cluster_size, 
            :pig_version => "0.9", 
            :project_script_path => be_a_kind_of(String),
            :parameters => match_array([{"name" => "FIRST_PARAM", "value" => "FOO"}, {"name" => "SECOND_PARAM", "value" => "BAR"}]), 
            :cluster_type => Jobs::CLUSTER_TYPE__PERSISTENT,
            :notify_on_job_finish => true,
            :is_control_script=>false,
            :use_spot_instances => false) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("jobs:run pigscripts/my_script.pig --clustersize 5 -p FIRST_PARAM=FOO -p SECOND_PARAM=BAR", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

Or by running:

  mortar jobs:status c571a8c7f76a4fd4a67c103d753e2dd5 --poll

STDOUT
        end
      end

      it "runs a job on a new spot instance cluster" do
        with_git_initialized_project do |p|
          # stub api requests
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          cluster_size = 5

          mock(Mortar::Auth.api).post_pig_job_new_cluster("myproject", "my_script", is_a(String),cluster_size, 
            :pig_version => "0.9", 
            :project_script_path => be_a_kind_of(String),
            :parameters => match_array([{"name" => "FIRST_PARAM", "value" => "FOO"}, {"name" => "SECOND_PARAM", "value" => "BAR"}]), 
            :cluster_type => Jobs::CLUSTER_TYPE__PERSISTENT,
            :notify_on_job_finish => true,
            :is_control_script=>false,
            :use_spot_instances=>true) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("jobs:run pigscripts/my_script.pig --clustersize 5 -p FIRST_PARAM=FOO -p SECOND_PARAM=BAR --spot", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

Or by running:

  mortar jobs:status c571a8c7f76a4fd4a67c103d753e2dd5 --poll

STDOUT
        end
      end
      
      it "runs a control script using new full-path syntax" do
        with_git_initialized_project do |p|
          # stub api requests
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          cluster_id = "e2790e7e8c7d48e39157238d58191346"

          mock(Mortar::Auth.api).post_pig_job_existing_cluster("myproject", "my_script", is_a(String), cluster_id,
              :pig_version => "0.9", 
              :project_script_path => be_a_kind_of(String),
              :parameters => [],
              :notify_on_job_finish => false,
              :is_control_script=>true) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.controlscripts_path, "my_script.py"))
          stderr, stdout = execute("jobs:run controlscripts/my_script.pig --clusterid e2790e7e8c7d48e39157238d58191346 -d", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

Or by running:

  mortar jobs:status c571a8c7f76a4fd4a67c103d753e2dd5 --poll

STDOUT
        end
      end

      it "runs a control script using deprecated no-path controlscript syntax" do
        with_git_initialized_project do |p|
          # stub api requests
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          cluster_id = "e2790e7e8c7d48e39157238d58191346"

          mock(Mortar::Auth.api).post_pig_job_existing_cluster("myproject", "my_script", is_a(String), cluster_id,
              :pig_version => "0.9", 
              :project_script_path => be_a_kind_of(String),
              :parameters => [],
              :notify_on_job_finish => false,
              :is_control_script=>true) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.controlscripts_path, "my_script.py"))
          stderr, stdout = execute("jobs:run my_script --clusterid e2790e7e8c7d48e39157238d58191346 -d", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

Or by running:

  mortar jobs:status c571a8c7f76a4fd4a67c103d753e2dd5 --poll

STDOUT
        end
      end

      it "runs a job with no cluster defined using deprecated no-path pigscript syntax" do
        with_git_initialized_project do |p|
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          cluster_size = 2

          mock(Mortar::Auth.api).get_clusters() {Excon::Response.new(:body => {'clusters' => []})}
          mock(Mortar::Auth.api).post_pig_job_new_cluster("myproject", "my_script", is_a(String), cluster_size, 
            :pig_version => "0.9", 
            :project_script_path => be_a_kind_of(String),
            :parameters => [], 
            :cluster_type => Jobs::CLUSTER_TYPE__PERSISTENT,
            :notify_on_job_finish => true,
            :is_control_script=>false,
            :use_spot_instances => false) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("jobs:run my_script", p, @git)
          stdout.should == <<-STDOUT
Defaulting to running job on new cluster of size 2
Taking code snapshot... done
Sending code snapshot to Mortar... done
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

Or by running:

  mortar jobs:status c571a8c7f76a4fd4a67c103d753e2dd5 --poll

STDOUT

        end
      end
      
      it "runs a job with no cluster defined using new full-path pigscript syntax" do
        with_git_initialized_project do |p|
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          cluster_size = 2

          mock(Mortar::Auth.api).get_clusters() {Excon::Response.new(:body => {'clusters' => []})}
          mock(Mortar::Auth.api).post_pig_job_new_cluster("myproject", "my_script", is_a(String), cluster_size, 
            :pig_version => "0.9", 
            :project_script_path => be_a_kind_of(String),
            :parameters => [], 
            :cluster_type => Jobs::CLUSTER_TYPE__PERSISTENT,
            :notify_on_job_finish => true,
            :is_control_script=>false,
            :use_spot_instances => false) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("jobs:run pigscripts/my_script.pig ", p, @git)
          stdout.should == <<-STDOUT
Defaulting to running job on new cluster of size 2
Taking code snapshot... done
Sending code snapshot to Mortar... done
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

Or by running:

  mortar jobs:status c571a8c7f76a4fd4a67c103d753e2dd5 --poll

STDOUT

        end
      end

      it "runs a job on an existing cluster" do
        with_git_initialized_project do |p|
          # stub api requests
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          cluster_id = "e2790e7e8c7d48e39157238d58191346"

          mock(Mortar::Auth.api).post_pig_job_existing_cluster("myproject", "my_script", is_a(String), cluster_id, :pig_version => "0.9", :project_script_path => be_a_kind_of(String), :parameters => [], :notify_on_job_finish => false, :is_control_script=>false) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("jobs:run pigscripts/my_script.pig --clusterid e2790e7e8c7d48e39157238d58191346 -d", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

Or by running:

  mortar jobs:status c571a8c7f76a4fd4a67c103d753e2dd5 --poll

STDOUT
        end
      end

      it "runs a job by default on the largest existing running cluster" do
        with_git_initialized_project do |p|
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"

          small_cluster_id = '510beb6b3004860820ab6538'
          small_cluster_size = 2
          small_cluster_status = Mortar::API::Clusters::STATUS_RUNNING
          large_cluster_id = '510bf0db3004860820ab6590'
          large_cluster_size = 5
          large_cluster_status = Mortar::API::Clusters::STATUS_RUNNING
          starting_cluster_id = '510bf0db3004860820abaaaa'
          starting_cluster_size = 10
          starting_cluster_status = Mortar::API::Clusters::STATUS_STARTING
          huge_busy_cluster_id = '510bf0db3004860820ab6621'
          huge_busy_cluster_size = 20
          huge_busy_cluster_status = Mortar::API::Clusters::STATUS_RUNNING
          

          mock(Mortar::Auth.api).get_clusters() {
            Excon::Response.new(:body => { 
              'clusters' => [
                  { 'cluster_id' => small_cluster_id, 'size' => small_cluster_size, 'running_jobs' => [], 'status_code' => small_cluster_status }, 
                  { 'cluster_id' => large_cluster_id, 'size' => large_cluster_size, 'running_jobs' => [], 'status_code' => large_cluster_status },
                  { 'cluster_id' => starting_cluster_id, 'size' => starting_cluster_size, 'running_jobs' => [], 'status_code' => starting_cluster_status },
                  { 'cluster_id' => huge_busy_cluster_id, 'size' => huge_busy_cluster_size, 
                    'running_jobs' => [ { 'job_id' => 'c571a8c7f76a4fd4a67c103d753e2dd5',
                       'job_name' => "", 'start_timestamp' => ""} ], 'status_code' => huge_busy_cluster_status  }
              ]})
          }
          mock(Mortar::Auth.api).post_pig_job_existing_cluster("myproject", "my_script", is_a(String), large_cluster_id, 
            :pig_version => "0.9", 
            :project_script_path => be_a_kind_of(String),
            :parameters => [], 
            :notify_on_job_finish => true,
            :is_control_script=>false) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("jobs:run pigscripts/my_script.pig ", p, @git)
          stdout.should == <<-STDOUT
Defaulting to running job on largest existing free cluster, id = 510bf0db3004860820ab6590, size = 5
Taking code snapshot... done
Sending code snapshot to Mortar... done
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

Or by running:

  mortar jobs:status c571a8c7f76a4fd4a67c103d753e2dd5 --poll

STDOUT

        end
      end

      it "runs a job with parameter file" do
        with_git_initialized_project do |p|
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          cluster_size = 5

          mock(Mortar::Auth.api).post_pig_job_new_cluster("myproject", "my_script", is_a(String), cluster_size, 
            :pig_version => "0.9",
            :project_script_path => be_a_kind_of(String), 
            :parameters => match_array([{"name" => "FIRST", "value" => "FOO"}, {"name" => "SECOND", "value" => "BAR"}, {"name" => "THIRD", "value" => "BEAR"}]), 
            :cluster_type => Jobs::CLUSTER_TYPE__PERSISTENT,
            :notify_on_job_finish => true,
            :is_control_script=>false,
            :use_spot_instances => false) {Excon::Response.new(:body => {"job_id" => job_id})}

          write_file(File.join(p.pigscripts_path, "my_script.pig"))

          parameters = <<PARAMS
FIRST=PIZZA
SECOND=LASAGNA

THIRD=BEAR
PARAMS

          write_file(File.join(p.root_path, "params.ini"), parameters)
          stderr, stdout = execute("jobs:run pigscripts/my_script.pig --clustersize 5 -p FIRST=FOO -p SECOND=BAR --param-file params.ini", p, @git)
        end
      end

      it "runs a job with parameter file with comments" do
        with_git_initialized_project do |p|
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          cluster_size = 5

          mock(Mortar::Auth.api).post_pig_job_new_cluster("myproject", "my_script", is_a(String), cluster_size, 
            :pig_version => "0.9", 
            :project_script_path => be_a_kind_of(String),
            :parameters => match_array([{"name" => "FIRST", "value" => "FOO"}, {"name" => "SECOND", "value" => "BAR"}, {"name" => "THIRD", "value" => "BEAR"}]), 
            :cluster_type => Jobs::CLUSTER_TYPE__PERSISTENT,
            :notify_on_job_finish => true,
            :is_control_script=>false,
            :use_spot_instances => false) {Excon::Response.new(:body => {"job_id" => job_id})}

          write_file(File.join(p.pigscripts_path, "my_script.pig"))

          parameters = <<PARAMS
FIRST=PIZZA
SECOND=LASAGNA
; This is a test

THIRD=BEAR
PARAMS

          write_file(File.join(p.root_path, "params.ini"), parameters)
          stderr, stdout = execute("jobs:run pigscripts/my_script.pig --clustersize 5 -p FIRST=FOO -p SECOND=BAR --param-file params.ini", p, @git)
        end
      end

      it "runs a job with malformed parameter file" do
        with_git_initialized_project do |p|
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          cluster_size = 5

          write_file(File.join(p.pigscripts_path, "my_script.pig"))

          parameters = <<PARAMS
FIRST=PIZZA
SECONDLASAGasNA
; This is a test
Natta
THIRD=BEAR
PARAMS

          write_file(File.join(p.root_path, "params.ini"), parameters)
          stderr, stdout = execute("jobs:run pigscripts/my_script.pig --clustersize 5 -p FIRST=FOO -p SECOND=BAR --param-file params.ini", p, @git)
          stderr.should == <<-STDERR
 !    Parameter file is malformed
STDERR
        end
      end

      it "runs a job for an embedded project" do
        with_embedded_project do |p|
          # stub api requests
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          cluster_size = 5

          mock(@git).sync_embedded_project.with_any_args.times(1) { "somewhere_over_the_rainbow" }

          mock(Mortar::Auth.api).post_pig_job_new_cluster("myproject", "my_script", is_a(String), cluster_size, 
            :pig_version => "0.9", 
            :project_script_path => be_a_kind_of(String),
            :parameters => match_array([{"name" => "FIRST_PARAM", "value" => "FOO"}, {"name" => "SECOND_PARAM", "value" => "BAR"}]), 
            :cluster_type => Jobs::CLUSTER_TYPE__PERSISTENT,
            :notify_on_job_finish => true,
            :is_control_script=>false,
            :use_spot_instances => false) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.pigscripts_path, "my_script.pig"))
          stderr, stdout = execute("jobs:run pigscripts/my_script.pig --clustersize 5 -p FIRST_PARAM=FOO -p SECOND_PARAM=BAR", p, @git)
        end
      end
    end
    
    context("status") do
      it "gets status for a completed, successful job" do
        with_git_initialized_project do |p|
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          pigscript_name = "my_script"
          project_name = "myproject"
          status_code = Mortar::API::Jobs::STATUS_SUCCESS
          progress = 100
          outputs = [{'name'=> 'hottest_songs_of_the_decade', 
                      'records' => 10, 
                      'alias' => 'output_data',
                      'location' => 's3n://my-bucket/my-folder/hottest_songs_of_the_decade/output_data'},
                     {'name'=> 'hottest_songs_of_the_decade', 
                      'records' => 100,
                      'alias' => 'output_data_2',
                      'location' => 's3n://my-bucket/my-folder/hottest_songs_of_the_decade/output_data_2'}]
          cluster_id = "e2790e7e8c7d48e39157238d58191346"
          start_timestamp = "2012-02-28T03:35:42.831000+00:00"
          running_timestamp = "2012-02-28T03:41:52.613000+00:00"
          stop_timestamp = "2012-02-28T03:44:52.613000+00:00"
          parameters = {"my_param_1" => "value1", "MY_PARAM_2" => "3"}

          mock(Mortar::Auth.api).get_job(job_id) {Excon::Response.new(:body => {"job_id" => job_id,
            "pigscript_name" => pigscript_name,
            "project_name" => project_name,
            "display_name" => "#{project_name}: #{pigscript_name}",
            "status_code" => status_code,
            "status_description" => "Success",
            "progress" => progress,
            "cluster_id" => cluster_id,
            "start_timestamp" => start_timestamp,
            "running_timestamp" => running_timestamp,
            "stop_timestamp" => stop_timestamp,
            "duration" => "6 mins",
            "num_hadoop_jobs" => 4,
            "num_hadoop_jobs_succeeded" => 4,
            "parameters" => parameters,
            "outputs" => outputs
            })}
          stderr, stdout = execute("jobs:status c571a8c7f76a4fd4a67c103d753e2dd5", p, @git)
          stdout.should == <<-STDOUT
=== myproject: my_script (job_id: c571a8c7f76a4fd4a67c103d753e2dd5)
cluster_id:              e2790e7e8c7d48e39157238d58191346
hadoop jobs complete:    4.00 / 4.00
job began running at:    2012-02-28T03:41:52.613000+00:00
job finished at:         2012-02-28T03:44:52.613000+00:00
job run with parameters: 
  MY_PARAM_2:   3
  my_param_1:   value1
job running for:         6 mins
job submitted at:        2012-02-28T03:35:42.831000+00:00
outputs:                 
  output_data:   
    location:     s3n://my-bucket/my-folder/hottest_songs_of_the_decade/output_data
    records:      10
  output_data_2: 
    location:     s3n://my-bucket/my-folder/hottest_songs_of_the_decade/output_data_2
    records:      100
progress:                100%
status:                  Success
STDOUT
        end
      end
          
      it "gets status for a running job" do
        with_git_initialized_project do |p|
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          pigscript_name = "my_script"
          project_name = "myproject"
          status_code = Mortar::API::Jobs::STATUS_RUNNING
          progress = 55
          cluster_id = "e2790e7e8c7d48e39157238d58191346"
          start_timestamp = "2012-02-28T03:35:42.831000+00:00"
          running_timestamp = "2012-02-28T03:41:52.613000+00:00"
          parameters = {"my_param_1" => "value1", "MY_PARAM_2" => "3"}
          
          mock(Mortar::Auth.api).get_job(job_id) {Excon::Response.new(:body => {"job_id" => job_id,
            "pigscript_name" => pigscript_name,
            "project_name" => project_name,
            "display_name" => "#{project_name}: #{pigscript_name}",
            "status_code" => status_code,
            "status_description" => "Running",
            "progress" => progress,
            "cluster_id" => cluster_id,
            "start_timestamp" => start_timestamp,
            "running_timestamp" => running_timestamp,
            "duration" => "6 mins",
            "num_hadoop_jobs" => 4,
            "num_hadoop_jobs_succeeded" => 2,
            "parameters" => parameters
            })}
          stderr, stdout = execute("jobs:status c571a8c7f76a4fd4a67c103d753e2dd5", p, @git)
          stdout.should == <<-STDOUT
=== myproject: my_script (job_id: c571a8c7f76a4fd4a67c103d753e2dd5)
cluster_id:              e2790e7e8c7d48e39157238d58191346
hadoop jobs complete:    2.00 / 4.00
job began running at:    2012-02-28T03:41:52.613000+00:00
job run with parameters: 
  MY_PARAM_2:   3
  my_param_1:   value1
job running for:         6 mins
job submitted at:        2012-02-28T03:35:42.831000+00:00
progress:                55%
status:                  Running
STDOUT
        end
      end

      it "gets status for a error job" do
        with_git_initialized_project do |p|
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          pigscript_name = "my_script"
          project_name = "myproject"
          status_code = Mortar::API::Jobs::STATUS_EXECUTION_ERROR
          progress = 55
          cluster_id = "e2790e7e8c7d48e39157238d58191346"
          start_timestamp = "2012-02-28T03:35:42.831000+00:00"
          running_timestamp = "2012-02-28T03:41:52.613000+00:00"
          stop_timestamp = "2012-02-28T03:45:52.613000+00:00"
          parameters = {"my_param_1" => "value1", "MY_PARAM_2" => "3"}
          error = {"message" => "An error occurred and here's some more info",
                   "type" => "RuntimeError",
                   "line_number" => 43,
                   "column_number" => 34}
          mock(Mortar::Auth.api).get_job(job_id) {Excon::Response.new(:body => {"job_id" => job_id,
            "pigscript_name" => pigscript_name,
            "project_name" => project_name,
            "display_name" => "#{project_name}: #{pigscript_name}",
            "status_code" => status_code,
            "status_description" => "Execution error",
            "progress" => progress,
            "cluster_id" => cluster_id,
            "start_timestamp" => start_timestamp,
            "running_timestamp" => running_timestamp,
            "stop_timestamp" => stop_timestamp,
            "duration" => "6 mins",
            "num_hadoop_jobs" => 4,
            "num_hadoop_jobs_succeeded" => 0,
            "parameters" => parameters,
            "error" => error
            })}
          stderr, stdout = execute("jobs:status c571a8c7f76a4fd4a67c103d753e2dd5", p, @git)
          stdout.should == <<-STDOUT
=== myproject: my_script (job_id: c571a8c7f76a4fd4a67c103d753e2dd5)
cluster_id:              e2790e7e8c7d48e39157238d58191346
error - column_number:   34
error - line_number:     43
error - message:         An error occurred and here's some more info
error - type:            RuntimeError
hadoop jobs complete:    0.00 / 4.00
job began running at:    2012-02-28T03:41:52.613000+00:00
job finished at:         2012-02-28T03:45:52.613000+00:00
job run with parameters: 
  MY_PARAM_2:   3
  my_param_1:   value1
job running for:         6 mins
job submitted at:        2012-02-28T03:35:42.831000+00:00
progress:                55%
status:                  Execution error
STDOUT
        end
      end

      it "gets status for a control job" do
        with_git_initialized_project do |p|
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          controlscript_name = "my_control"
          project_name = "myproject"
          status_code = Mortar::API::Jobs::STATUS_RUNNING
          progress = 0
          cluster_id = "e2790e7e8c7d48e39157238d58191346"
          start_timestamp = "2012-02-28T03:35:42.831000+00:00"
          stop_timestamp = "2012-02-28T03:44:52.613000+00:00"
          running_timestamp = "2012-02-28T03:41:52.613000+00:00"
          parameters = {"my_param_1" => "value1", "MY_PARAM_2" => "3"}

          mock(Mortar::Auth.api).get_job(job_id).returns(Excon::Response.new(:body => {"job_id" => job_id,
            "controlscript_name" => controlscript_name,
            "project_name" => project_name,
            "display_name" => "#{project_name}: #{controlscript_name}",
            "status_code" => status_code,
            "status_description" => "Execution error",
            "progress" => progress,
            "cluster_id" => cluster_id,
            "start_timestamp" => start_timestamp,
            "running_timestamp" => running_timestamp,
            "duration" => "6 mins",
            "num_hadoop_jobs_succeeded" => 1.3,
            "parameters" => parameters
            }))

          status_code = Mortar::API::Jobs::STATUS_SUCCESS
          progress = 100
          outputs = [{'name'=> 'hottest_songs_of_the_decade', 
                      'records' => 10, 
                      'alias' => 'output_data',
                      'location' => 's3n://my-bucket/my-folder/hottest_songs_of_the_decade/output_data'},
                     {'name'=> 'hottest_songs_of_the_decade', 
                      'records' => 100,
                      'alias' => 'output_data_2',
                      'location' => 's3n://my-bucket/my-folder/hottest_songs_of_the_decade/output_data_2'}]

          mock(Mortar::Auth.api).get_job(job_id).returns(Excon::Response.new(:body => {"job_id" => job_id,
            "controlscript_name" => controlscript_name,
            "project_name" => project_name,
            "display_name" => "#{project_name}: #{controlscript_name}",
            "status_code" => status_code,
            "status_description" => "Success",
            "progress" => progress,
            "cluster_id" => cluster_id,
            "start_timestamp" => start_timestamp,
            "running_timestamp" => running_timestamp,
            "stop_timestamp" => stop_timestamp,
            "duration" => "6 mins",
            "num_hadoop_jobs" => 4,
            "num_hadoop_jobs_succeeded" => 4,
            "parameters" => parameters,
            "outputs" => outputs
            }))
          stderr, stdout = execute("jobs:status c571a8c7f76a4fd4a67c103d753e2dd5 -p --polling_interval 0.05", p, @git)
          stdout.should == <<-STDOUT
\r[/] 1.30 MapReduce Jobs complete.\r\e[0K=== myproject: my_control (job_id: c571a8c7f76a4fd4a67c103d753e2dd5)
cluster_id:              e2790e7e8c7d48e39157238d58191346
hadoop jobs complete:    4.00 / 4.00
job began running at:    2012-02-28T03:41:52.613000+00:00
job finished at:         2012-02-28T03:44:52.613000+00:00
job run with parameters: 
  MY_PARAM_2:   3
  my_param_1:   value1
job running for:         6 mins
job submitted at:        2012-02-28T03:35:42.831000+00:00
outputs:                 
  output_data:   
    location:     s3n://my-bucket/my-folder/hottest_songs_of_the_decade/output_data
    records:      10
  output_data_2: 
    location:     s3n://my-bucket/my-folder/hottest_songs_of_the_decade/output_data_2
    records:      100
progress:                100%
status:                  Success
STDOUT
        end
      end

      it "gets status for a running job using polling" do
        with_git_initialized_project do |p|
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          pigscript_name = "my_script"
          project_name = "myproject"
          status_code = Mortar::API::Jobs::STATUS_RUNNING
          progress = 0
          cluster_id = "e2790e7e8c7d48e39157238d58191346"
          start_timestamp = "2012-02-28T03:35:42.831000+00:00"
          stop_timestamp = "2012-02-28T03:44:52.613000+00:00"
          running_timestamp = "2012-02-28T03:41:52.613000+00:00"
          parameters = {"my_param_1" => "value1", "MY_PARAM_2" => "3"}

          mock(Mortar::Auth.api).get_job(job_id).returns(Excon::Response.new(:body => {"job_id" => job_id,
            "pigscript_name" => pigscript_name,
            "project_name" => project_name,
            "display_name" => "#{project_name}: #{pigscript_name}",
            "status_code" => status_code,
            "status_description" => "Execution error",
            "progress" => progress,
            "cluster_id" => cluster_id,
            "start_timestamp" => start_timestamp,
            "running_timestamp" => running_timestamp,
            "duration" => "6 mins",
            "num_hadoop_jobs" => 4,
            "num_hadoop_jobs_succeeded" => 0,
            "parameters" => parameters
            }))

          status_code = Mortar::API::Jobs::STATUS_SUCCESS
          progress = 100
          outputs = [{'name'=> 'hottest_songs_of_the_decade', 
                      'records' => 10, 
                      'alias' => 'output_data',
                      'location' => 's3n://my-bucket/my-folder/hottest_songs_of_the_decade/output_data'},
                     {'name'=> 'hottest_songs_of_the_decade', 
                      'records' => 100,
                      'alias' => 'output_data_2',
                      'location' => 's3n://my-bucket/my-folder/hottest_songs_of_the_decade/output_data_2'}]

          mock(Mortar::Auth.api).get_job(job_id).returns(Excon::Response.new(:body => {"job_id" => job_id,
            "pigscript_name" => pigscript_name,
            "project_name" => project_name,
            "display_name" => "#{project_name}: #{pigscript_name}",
            "status_code" => status_code,
            "status_description" => "Success",
            "progress" => progress,
            "cluster_id" => cluster_id,
            "start_timestamp" => start_timestamp,
            "running_timestamp" => running_timestamp,
            "stop_timestamp" => stop_timestamp,
            "duration" => "6 mins",
            "num_hadoop_jobs" => 4,
            "num_hadoop_jobs_succeeded" => 4,
            "parameters" => parameters,
            "outputs" => outputs
            }))
          stderr, stdout = execute("jobs:status c571a8c7f76a4fd4a67c103d753e2dd5 -p --polling_interval 0.05", p, @git)
          stdout.should == <<-STDOUT
\r[/] Status: [=>                    ] 0% Complete (0.00 / 4.00 MapReduce jobs finished)\r\e[0K=== myproject: my_script (job_id: c571a8c7f76a4fd4a67c103d753e2dd5)
cluster_id:              e2790e7e8c7d48e39157238d58191346
hadoop jobs complete:    4.00 / 4.00
job began running at:    2012-02-28T03:41:52.613000+00:00
job finished at:         2012-02-28T03:44:52.613000+00:00
job run with parameters: 
  MY_PARAM_2:   3
  my_param_1:   value1
job running for:         6 mins
job submitted at:        2012-02-28T03:35:42.831000+00:00
outputs:                 
  output_data:   
    location:     s3n://my-bucket/my-folder/hottest_songs_of_the_decade/output_data
    records:      10
  output_data_2: 
    location:     s3n://my-bucket/my-folder/hottest_songs_of_the_decade/output_data_2
    records:      100
progress:                100%
status:                  Success
STDOUT
        end
      end

      it "gets status for a running pipeline job using polling" do
        #{"project_name"=>"jkarn-mortar-recsys", "status_code"=>"finished", "status_detail_description"=>"Success", "status_detail"=>"success", "duration"=>"< 1 min", "status_description"=>"Finished", "script_variables"=>[], "start_timestamp"=>"2014-10-03T12:34:40.994000+00:00", "display_name"=>"jkarn-mortar-recsys: simple-retail-generate-signals", "job_id"=>"542e97cea40a865ab7000dfe", "request_timestamp"=>"2014-10-03T12:34:22.439000+00:00", "luigiscript_name"=>"simple-retail-generate-signals", "job_type"=>"luigi", "error"=>nil, "git_ref"=>"015690ad2c951c67366e36847be59646d441c5b1", "stop_timestamp"=>"2014-10-03T12:35:20.241000+00:00"}
        with_git_initialized_project do |p|
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          luigiscript_name = "my_luigi_script"
          project_name = "myproject"
          display_name = "#{project_name}: #{luigiscript_name}"
          status_code = Mortar::API::Jobs::LUIGI_JOB_STATUS__STARTING
          status_description = "#{status_code} description"
          status_detail = nil
          status_detail_description = "#{status_detail} description"
          start_timestamp = "2012-02-28T03:35:42.831000+00:00"
          stop_timestamp = "2012-02-28T03:44:52.613000+00:00"
          running_timestamp = "2012-02-28T03:41:52.613000+00:00"
          duration = "< 1 min"

          mock(Mortar::Auth.api).get_job(job_id).returns(Excon::Response.new(:body => {"job_id" => job_id,
            "project_name"=>project_name,
            "status_code"=>status_code,
            "status_detail_description"=>status_detail_description,
            "status_detail"=>status_detail,
            "duration"=>duration,
            "status_description"=>status_description,
            "script_variables"=>[],
            "start_timestamp"=>start_timestamp,
            "display_name"=>display_name,
            "job_id"=>job_id,
            "request_timestamp"=>running_timestamp,
            "luigiscript_name"=>luigiscript_name, 
            "job_type"=>Mortar::API::Jobs::JOB_TYPE_LUIGI, 
            "error"=>nil, 
            "git_ref"=>"015690ad2c951c67366e36847be59646d441c5b1", 
            "stop_timestamp"=>stop_timestamp
          }))

          status_code = Mortar::API::Jobs::LUIGI_JOB_STATUS__FINISHED
          status_detail = "success"

          status_description = "#{status_code} description"
          status_detail_description = "#{status_detail} description"

        mock(Mortar::Auth.api).get_job(job_id).returns(Excon::Response.new(:body => {"job_id" => job_id,
            "project_name"=>project_name,
            "status_code"=>status_code,
            "status_detail_description"=>"#{status_detail} description",
            "status_detail"=>status_detail,
            "duration"=>duration,
            "status_description"=>"#{status_code} description",
            "script_variables"=>[],
            "start_timestamp"=>start_timestamp,
            "display_name"=>display_name,
            "job_id"=>job_id,
            "request_timestamp"=>running_timestamp,
            "luigiscript_name"=>luigiscript_name, 
            "job_type"=>Mortar::API::Jobs::JOB_TYPE_LUIGI, 
            "error"=>nil, 
            "git_ref"=>"015690ad2c951c67366e36847be59646d441c5b1", 
            "stop_timestamp"=>stop_timestamp
          }))
        stderr, stdout = execute("jobs:status c571a8c7f76a4fd4a67c103d753e2dd5 -p --polling_interval 0.05", p, @git)
        stdout.should == <<-STDOUT
\r\e[0K[/] Status: starting description -  description\r\e[0K=== #{display_name} (job_id: #{job_id})
job finished at:         #{stop_timestamp}
job running for:         #{duration}
job submitted at:        #{start_timestamp}
status:                  #{status_description} - #{status_detail_description}
STDOUT
        end
      end
    end

    context("stop") do
      it "Stops a running job with default message" do
        job_id = "1234abcd"
        mock(Mortar::Auth.api).stop_job(job_id) {Excon::Response.new(:body => {"success" => true})}

        stderr, stdout = execute("jobs:stop #{job_id}")
        stdout.should == <<-STDOUT
Stopping job #{job_id}.
STDOUT
      end

      it "Stops a running job with server message" do
        job_id = "1234abcd"
        message = "some awesome message"
        mock(Mortar::Auth.api).stop_job(job_id) {Excon::Response.new(:body => {"success" => true, "message" => message})}

        stderr, stdout = execute("jobs:stop #{job_id}")
        stdout.should == "#{message}\n"
      end

    end
  end
end

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
require 'mortar/command/spark'
require 'mortar/api/jobs'

module Mortar::Command
  describe Spark do
    
    before(:each) do
      stub_core      
      @git = Mortar::Git::Git.new
    end
    
    context("index") do
      it "shows help when user adds help argument" do
        with_git_initialized_project do |p|
          stderr_dash_h, stdout_dash_h = execute("spark -h", p, @git) 
          stderr_help, stdout_help = execute("spark help", p, @git)
          stdout_dash_h.should == stdout_help
          stderr_dash_h.should == stderr_help
        end
      end

      it "runs a spark job with no arguments new cluster" do
        with_git_initialized_project do |p|
          # stub api requests
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/spark_job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          mock(Mortar::Auth.api).post_spark_job_new_cluster("myproject", "my_script.py", is_a(String), 4,
            :project_script_path => be_a_kind_of(String),
            :script_arguments => "",
            :cluster_type=>"persistent",
            :use_spot_instances=>false
          ) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.sparkscripts_path, "my_script.py"))
          stderr, stdout = execute("spark sparkscripts/my_script.py --clustersize 4", p, @git)
          puts stderr
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/spark_job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

STDOUT
        end
      end

      it "runs a spark job with script_arguments existing cluster" do
        with_git_initialized_project do |p|
          # stub api requests
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          cluster_id = "c571a8c7f76a4fd4a67c103d753e2dd7"
          job_url = "http://127.0.0.1:5000/jobs/spark_job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          script_arguments = "arg1 arg2 arg3"
          mock(Mortar::Auth.api).post_spark_job_existing_cluster("myproject", "my_script.py", is_a(String), cluster_id,
            :project_script_path => be_a_kind_of(String),
            :script_arguments => script_arguments
          ) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.sparkscripts_path, "my_script.py"))
          stderr, stdout = execute("spark sparkscripts/my_script.py --clusterid #{cluster_id} #{script_arguments}", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/spark_job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

STDOUT
        end
      end

      it "runs a spark job on free cluster" do
        with_git_initialized_project do |p|
          # stub api requests
          job_id = "c571a8c7f76a4fd4a67c103d753e2dd5"
          job_url = "http://127.0.0.1:5000/jobs/spark_job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5"
          script_arguments = "arg1 arg2 arg3"

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
          
          mock(Mortar::Auth.api).get_clusters(Mortar::API::Jobs::CLUSTER_BACKEND__EMR_HADOOP_2) {
            Excon::Response.new(:body => { 
              'clusters' => [
                  { 'cluster_id' => small_cluster_id, 'size' => small_cluster_size, 'running_spark_jobs' => [], 'status_code' => small_cluster_status }, 
                  { 'cluster_id' => large_cluster_id, 'size' => large_cluster_size, 'running_spark_jobs' => [], 'status_code' => large_cluster_status },
                  { 'cluster_id' => starting_cluster_id, 'size' => starting_cluster_size, 'running_spark_jobs' => [], 'status_code' => starting_cluster_status },
                  { 'cluster_id' => huge_busy_cluster_id, 'size' => huge_busy_cluster_size, 
                    'running_spark_jobs' => [ { 'job_id' => 'c571a8c7f76a4fd4a67c103d753e2dd5',
                       'job_name' => "", 'start_timestamp' => ""} ], 'status_code' => huge_busy_cluster_status  }
              ]})
          }

          mock(Mortar::Auth.api).post_spark_job_existing_cluster("myproject", "my_script.py", is_a(String), large_cluster_id,
            :project_script_path => be_a_kind_of(String),
            :script_arguments => script_arguments
          ) {Excon::Response.new(:body => {"job_id" => job_id, "web_job_url" => job_url})}

          write_file(File.join(p.sparkscripts_path, "my_script.py"))
          stderr, stdout = execute("spark sparkscripts/my_script.py #{script_arguments}", p, @git)
          stdout.should == <<-STDOUT
Taking code snapshot... done
Sending code snapshot to Mortar... done
Defaulting to running job on largest existing free cluster, id = 510bf0db3004860820ab6590, size = 5
Requesting job execution... done
job_id: c571a8c7f76a4fd4a67c103d753e2dd5

Job status can be viewed on the web at:

 http://127.0.0.1:5000/jobs/spark_job_detail?job_id=c571a8c7f76a4fd4a67c103d753e2dd5

STDOUT
        end
      end



    end
  end
end

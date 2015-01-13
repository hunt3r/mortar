#
# Copyright 2015 Mortar Data Inc.
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

require "mortar/command/base"
require "time"

# run spark jobs
#
class Mortar::Command::Spark < Mortar::Command::Base

  include Mortar::Git

  # spark SCRIPT
  #
  # Run a spark job.
  #
  # -c, --clusterid CLUSTERID   # Run job on an existing cluster with ID of CLUSTERID (optional)
  # -s, --clustersize NUMNODES  # Run job on a new cluster, with NUMNODES nodes (optional; must be >= 2 if provided)
  # -1, --singlejobcluster      # Stop the cluster after job completes.  (Default: false--cluster can be used for other jobs, and will shut down after 1 hour of inactivity)
  # -2, --permanentcluster      # Don't automatically stop the cluster after it has been idle for an hour (Default: false--cluster will be shut down after 1 hour of inactivity)
  # -3, --spot                  # Use spot instances for this cluster (Default: false, only applicable to new clusters)
  # -P, --project PROJECTNAME   # Use a project that is not checked out in the current directory.  Runs code from project's master branch in GitHub rather than snapshotting local code.
  # -B, --branch BRANCHNAME     # Used with --project to specify a non-master branch
  #
  # Examples:
  #
  #    Run the classify_text sparkscript:
  #        $ mortar spark sparkscripts/classify_text.py
  #
  #    Run the classify_text sparkscript with 3 script arguments (input location, output location, tuning parameter):
  #        $ mortar spark sparkscripts/classify_text.py s3://your-bucket/input s3://your-bucket/output 100
  #
  def index
    script_name = shift_argument
    unless script_name
      error("Usage: mortar spark SCRIPT\nMust specify SCRIPT.")
    end
    
    if options[:project]
      project_name = options[:project]
    else
      project_name = project.name
      script = validate_sparkscript!(script_name)
      script_name = script.name
    end

    script_arguments = spark_script_arguments()

    if options[:clusterid]
      [:clustersize, :singlejobcluster, :permanentcluster].each do |opt|
        unless options[opt].nil?
          error("Option #{opt.to_s} cannot be set when running a job on an existing cluster (with --clusterid option)")
        end
      end
    end

    if options[:project]
      if options[:branch]
        git_ref = options[:branch]
      else
        git_ref = "master"
      end
    else
      git_ref = sync_code_with_cloud()
    end

    unless options[:clusterid] || options[:clustersize]
      clusters = api.get_clusters(Mortar::API::Jobs::CLUSTER_BACKEND__EMR_HADOOP_2).body['clusters']

      largest_free_cluster = clusters.select{ |c| \
        c['running_jobs'].length == 0 && c['status_code'] == Mortar::API::Clusters::STATUS_RUNNING }.
        max_by{|c| c['size']}

      if largest_free_cluster.nil?
        options[:clustersize] = 2
        display("Defaulting to running job on new cluster of size 2")
      else
        options[:clusterid] = largest_free_cluster['cluster_id']
        display("Defaulting to running job on largest existing free cluster, id = " + 
                largest_free_cluster['cluster_id'] + ", size = " + largest_free_cluster['size'].to_s)
      end
    end

    response = action("Requesting job execution") do
      if options[:clustersize]
        if options[:singlejobcluster] && options[:permanentcluster]
          error("Cannot declare cluster as both --singlejobcluster and --permanentcluster")
        end
        cluster_size = options[:clustersize].to_i
        cluster_type = Mortar::API::Jobs::CLUSTER_TYPE__PERSISTENT
        if options[:singlejobcluster]
          cluster_type = Mortar::API::Jobs::CLUSTER_TYPE__SINGLE_JOB
        elsif options[:permanentcluster]
          cluster_type = Mortar::API::Jobs::CLUSTER_TYPE__PERMANENT
        end
        use_spot_instances = options[:spot] || false
        api.post_spark_job_new_cluster(project_name, script_name, git_ref, cluster_size, 
          :project_script_path => script.rel_path,
          :script_arguments => script_arguments,
          :cluster_type => cluster_type,
          :use_spot_instances => use_spot_instances).body
      else
        cluster_id = options[:clusterid]
        api.post_spark_job_existing_cluster(project_name, script_name, git_ref, cluster_id,
          :project_script_path => script.rel_path,
          :script_arguments => script_arguments).body
      end
    end
    
    display("job_id: #{response['job_id']}")
    display
    display("Job status can be viewed on the web at:\n\n #{response['web_job_url']}")
    display

    response['job_id']
  end
  
  alias_command "spark:run", "spark"
end

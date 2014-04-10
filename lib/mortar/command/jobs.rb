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

require "mortar/command/base"
require "time"

# run and view status of pig jobs (run, status)
#
class Mortar::Command::Jobs < Mortar::Command::Base

  include Mortar::Git

  CLUSTER_TYPE__SINGLE_JOB = 'single_job'
  CLUSTER_TYPE__PERSISTENT = 'persistent'
  CLUSTER_TYPE__PERMANENT = 'permanent'

  # jobs
  #
  # Show recent and running jobs.
  #
  # -l, --limit LIMITJOBS # Limit the number of jobs returned (defaults to 10)
  # -s, --skip SKIPJOBS   # Skip a certain amount of jobs (defaults to 0)
  #
  # Examples:
  #
  #     List the last 20 jobs:
  #          $ mortar jobs -l 20
  def index
    validate_arguments!

    options[:limit] ||= '10'
    options[:skip] ||= '0'
    jobs = api.get_jobs(options[:skip], options[:limit]).body['jobs']
    jobs.each do |job|
      if job['start_timestamp']
        job['start_timestamp'] = Time.parse(job['start_timestamp']).strftime('%A, %B %e, %Y, %l:%M %p')
      end
    end
    headers = [ 'job_id', 'script' , 'status' , 'start_date' , 'elapsed_time' , 'cluster_size' , 'cluster_id']
    columns = [ 'job_id', 'display_name', 'status_description', 'start_timestamp', 'duration', 'cluster_size', 'cluster_id']
    display_table(jobs, columns, headers)
  end
    
  # jobs:run SCRIPT
  #
  # Run a job on a Mortar Hadoop cluster.
  #
  # -c, --clusterid CLUSTERID   # Run job on an existing cluster with ID of CLUSTERID (optional)
  # -s, --clustersize NUMNODES  # Run job on a new cluster, with NUMNODES nodes (optional; must be >= 2 if provided)
  # -1, --singlejobcluster      # Stop the cluster after job completes.  (Default: false--cluster can be used for other jobs, and will shut down after 1 hour of inactivity)
  # -2, --permanentcluster      # Don't automatically stop the cluster after it has been idle for an hour (Default: false--cluster will be shut down after 1 hour of inactivity)
  # -3, --spot                  # Use spot instances for this cluster (Default: false, only applicable to new clusters)
  # -p, --parameter NAME=VALUE  # Set a pig parameter value in your script.
  # -f, --param-file PARAMFILE  # Load pig parameter values from a file.
  # -d, --donotnotify           # Don't send an email on job completion.  (Default: false--an email will be sent to you once the job completes)
  # -P, --project PROJECTNAME   # Use a project that is not checked out in the current directory.  Runs code from project's master branch in github rather than snapshotting local code.
  # -B, --branch BRANCHNAME     # Used with --project to specify a non-master branch
  # -g, --pigversion PIG_VERSION # Set pig version.  Options are <PIG_VERSION_OPTIONS>.
  #
  #Examples:
  #
  #    Run the generate_regression_model_coefficients pigscript on a 3 node cluster.
  #        $ mortar jobs:run pigscripts/generate_regression_model_coefficients.pig --clustersize 3
  #
  #    Run the regression_controller control script on a 3 node cluster.
  #        $ mortar jobs:run controlscripts/regression_controller.py --clustersize 3
  def run
    script_name = shift_argument
    unless script_name
      error("Usage: mortar jobs:run SCRIPT\nMust specify SCRIPT.")
    end
    
    validate_arguments!
    if options[:project]
      project_name = options[:project]

      if File.extname(script_name) == ".pig"
        is_control_script = false
        script_name = File.basename(script_name, ".*")
      elsif File.extname(script_name) == ".py"
        is_control_script = true
        script_name = File.basename(script_name, ".*")
      else
        error "Unable to guess script type (controlscript vs pigscript).\n" + 
          "When running a script with the --project option, please provide the full path and filename, e.g.\n" +
          " mortar run pigscripts/#{script_name}.pig --project #{project_name}"
      end
    else
      project_name = project.name
      script = validate_script!(script_name)

      script_name = script.name
      case script
      when Mortar::Project::PigScript
        is_control_script = false
      when Mortar::Project::ControlScript
        is_control_script = true
      else
        error "Unknown Script Type"
      end
    end
    
    unless options[:clusterid] || options[:clustersize]
      clusters = api.get_clusters().body['clusters']

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
    
    notify_on_job_finish = ! options[:donotnotify]
    
    # post job to API    
    response = action("Requesting job execution") do
      if options[:clustersize]
        if options[:singlejobcluster] && options[:permanentcluster]
          error("Cannot declare cluster as both --singlejobcluster and --permanentcluster")
        end
        cluster_size = options[:clustersize].to_i
        cluster_type = CLUSTER_TYPE__PERSISTENT
        if options[:singlejobcluster]
          cluster_type = CLUSTER_TYPE__SINGLE_JOB
        elsif options[:permanentcluster]
          cluster_type = CLUSTER_TYPE__PERMANENT
        end
        use_spot_instances = options[:spot] || false
        api.post_job_new_cluster(project_name, script_name, git_ref, cluster_size, 
          :pig_version => pig_version.version, 
          :project_script_path => script.rel_path,
          :parameters => pig_parameters,
          :cluster_type => cluster_type,
          :notify_on_job_finish => notify_on_job_finish,
          :is_control_script => is_control_script,
          :use_spot_instances => use_spot_instances).body
      else
        cluster_id = options[:clusterid]
        api.post_job_existing_cluster(project_name, script_name, git_ref, cluster_id,
          :pig_version => pig_version.version, 
          :project_script_path => script.rel_path,
          :parameters => pig_parameters,
          :notify_on_job_finish => notify_on_job_finish,
          :is_control_script => is_control_script).body
      end
    end
    
    display("job_id: #{response['job_id']}")
    display
    display("Job status can be viewed on the web at:\n\n #{response['web_job_url']}")
    display
    display("Or by running:\n\n  mortar jobs:status #{response['job_id']} --poll")
    display

    response['job_id']
  end
  
  alias_command "run", "jobs:run"
  

  # jobs:status JOB_ID
  #
  # Check the status of a job.
  #
  # -p, --poll      # Poll the status of a job
  #
  def status
    job_id = shift_argument
    unless job_id
      error("Usage: mortar jobs:status JOB_ID\nMust specify JOB_ID.")
    end
    validate_arguments!
    
    # Inner function to display the hash table when the job is complte
    def display_job_status(job_status)
      job_display_entries = {
        "status" => job_status["status_description"],
        "cluster_id" => job_status["cluster_id"],
        "job submitted at" => job_status["start_timestamp"],
        "job began running at" => job_status["running_timestamp"],
        "job finished at" => job_status["stop_timestamp"],
        "job running for" => job_status["duration"],
        "job run with parameters" => job_status["parameters"],
      }

      
      unless job_status["error"].nil? || job_status["error"]["message"].nil?
        error_context = get_error_message_context(job_status["error"]["message"])
        unless error_context == ""
          job_status["error"]["help"] = error_context
        end
        job_status["error"].each_pair do |key, value|
          job_display_entries["error - #{key}"] = value
        end
      end
      
      if job_status["num_hadoop_jobs"] && job_status["num_hadoop_jobs_succeeded"]
        job_display_entries["progress"] = "#{job_status["progress"]}%"
        job_display_entries["hadoop jobs complete"] = 
          '%0.2f / %0.2f' % [job_status["num_hadoop_jobs_succeeded"], job_status["num_hadoop_jobs"]]
      elsif job_status["num_hadoop_jobs_succeeded"]
        job_display_entries["progress"] = '%0.2f MapReduce Jobs complete.' % job_status["num_hadoop_jobs_succeeded"]
      else
        job_display_entries["progress"] = "#{job_status["progress"]}%"
      end
      
      if job_status["outputs"] && job_status["outputs"].length > 0
        job_display_entries["outputs"] = Hash.new { |h,k| h[k] = [] }
        job_status["outputs"].select{|o| o["alias"]}.collect{ |output|
          output_hash = {}
          output_hash["location"] = output["location"] if output["location"]
          output_hash["records"] = output["records"] if output["records"]
          [output['alias'], output_hash]
        }.each{ |k,v| job_display_entries["outputs"][k] << v }
      end
      
      if job_status["controlscript_name"]
        script_name = job_status["controlscript_name"]
      else 
        script_name = job_status["pigscript_name"]
      end

      styled_header("#{job_status["project_name"]}: #{script_name} (job_id: #{job_status["job_id"]})")
      styled_hash(job_display_entries)
    end
    
    # If polling the status
    if options[:poll]
      job_status = nil
      ticking(polling_interval) do |ticks|
        job_status = api.get_job(job_id).body
        # If the job is complete exit and display the table normally 
        if Mortar::API::Jobs::STATUSES_COMPLETE.include?(job_status["status_code"] )
          redisplay("")
          display_job_status(job_status)
          break
        end

        # If the job is running show the progress bar
        if job_status["status_code"] == Mortar::API::Jobs::STATUS_RUNNING && job_status["num_hadoop_jobs"]
          progressbar = "=" + ("=" * (job_status["progress"].to_i / 5)) + ">"

          if job_status["num_hadoop_jobs"] && job_status["num_hadoop_jobs_succeeded"]
            hadoop_jobs_ratio_complete = 
              '%0.2f / %0.2f' % [job_status["num_hadoop_jobs_succeeded"], job_status["num_hadoop_jobs"]]
          end

          printf("\r[#{spinner(ticks)}] Status: [%-22s] %s%% Complete (%s MapReduce jobs finished)", progressbar, job_status["progress"], hadoop_jobs_ratio_complete)

        elsif job_status["status_code"] == Mortar::API::Jobs::STATUS_RUNNING
          jobs_complete = '%0.2f' % job_status["num_hadoop_jobs_succeeded"]
          printf("\r[#{spinner(ticks)}] #{jobs_complete} MapReduce Jobs complete.")

        # If the job is not complete, but not in the running state, just display its status
        else
          job_display_status = job_status['status_description']
          if !job_status['status_details'].nil?
            job_display_status += " - #{job_status['status_details']}"
          end
          redisplay("[#{spinner(ticks)}] Status: #{job_display_status}")
        end
      end
      job_status
    # If not polling, get the job status and display the results
    else
      job_status = api.get_job(job_id).body
      display_job_status(job_status)
      job_status
    end
  end

  # jobs:stop JOB_ID
  #
  # Stop a running job.
  #
  def stop
    job_id = shift_argument
    unless job_id
      error("Usage: mortar jobs:stop JOB_ID\nMust specify JOB_ID.")
    end
    validate_arguments!

    response = api.stop_job(job_id).body  

    #TODO: jkarn - Once all servers have the additional message field we can remove this check.
    if response['message'].nil?
      display("Stopping job #{job_id}.")
    else
      display(response['message'])
    end
  end
end

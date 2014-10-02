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

require "mortar/command/base"
require "time"

# run luigi pipeline jobs
#
class Mortar::Command::Luigi < Mortar::Command::Base

  include Mortar::Git

  # luigi SCRIPT
  #
  # Run a luigi pipeline.
  #
  # -P, --project PROJECTNAME   # Use a project that is not checked out in the current directory.  Runs code from project's master branch in GitHub rather than snapshotting local code.
  # -B, --branch BRANCHNAME     # Used with --project to specify a non-master branch
  #
  # Examples:
  #
  #    Run the nightly_rollup luigiscript:
  #        $ mortar luigi luigiscripts/nightly_rollup.py
  #
  #    Run the nightly_rollup luigiscript with two parameters:
  #        $ mortar luigi luigiscripts/nightly_rollup.py --data-date 2012-02-01 --my-param myval
  #
  def index
    script_name = shift_argument
    unless script_name
      error("Usage: mortar luigi SCRIPT\nMust specify SCRIPT.")
    end
    
    if options[:project]
      project_name = options[:project]
      if File.extname(script_name) == ".py"
        script_name = File.basename(script_name, ".*")
      end
    else
      project_name = project.name
      script = validate_luigiscript!(script_name)
      script_name = script.name
    end

    parameters = luigi_parameters()

    if options[:project]
      if options[:branch]
        git_ref = options[:branch]
      else
        git_ref = "master"
      end
    else
      git_ref = sync_code_with_cloud()
    end
    
    # post job to API 
    response = action("Requesting job execution") do      
      api.post_luigi_job(project_name, script_name, git_ref,
        :project_script_path => script.rel_path,
        :parameters => parameters).body
    end
    
    display("job_id: #{response['job_id']}")
    display
    display("Job status can be viewed on the web at:\n\n #{response['web_job_url']}")
    display

    response['job_id']
  end
  
  alias_command "luigi:run", "luigi"
end

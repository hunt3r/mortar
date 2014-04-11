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

# check script syntax
#
class Mortar::Command::Validate < Mortar::Command::Base
    
  # validate [PIGSCRIPT]
  #
  # Validate a pig script.  Checks script for problems with:
  #    * Pig syntax
  #    * Python syntax
  #    * S3 data access
  #
  # -p, --parameter NAME=VALUE  # Set a pig parameter value in your script.
  # -f, --param-file PARAMFILE  # Load pig parameter values from a file.
  # -g, --pigversion PIG_VERSION # Set pig version.  Options are <PIG_VERSION_OPTIONS>.
  #
  def index
    pigscript_name = shift_argument
    unless pigscript_name
      error("Usage: mortar validate PIGSCRIPT\nMust specify PIGSCRIPT.")
    end
    validate_arguments!
    pigscript = validate_script!(pigscript_name)
    
    if pigscript.is_a? Mortar::Project::ControlScript
      error "Currently Mortar does not support validating control scripts"
    end
    
    git_ref = sync_code_with_cloud()
    
    validate_id = nil
    action("Starting validate") do
      validate_id = api.post_validate(project.name, pigscript.name, git_ref, 
        :pig_version => pig_version.version, 
        :project_script_path => pigscript.rel_path,
        :parameters => pig_parameters).body["validate_id"]
    end
        
    validate_result = nil
    display
    ticking(polling_interval) do |ticks|
      validate_result = api.get_validate(validate_id).body
      is_finished =
        Mortar::API::Validate::STATUSES_COMPLETE.include?(validate_result["status_code"])
       
      redisplay("[#{spinner(ticks)}] Checking your script for problems with: Pig syntax, Python syntax, and S3 data access",
        is_finished) # only display newline on last message
      if is_finished
        display
        break
      end
    end
    
    case validate_result['status_code']
    when Mortar::API::Validate::STATUS_FAILURE
      error_message = "Validate failed with #{validate_result['error_type'] || 'error'}"
      if line_number = validate_result["line_number"]
        error_message += " at Line #{line_number}"
        if column_number = validate_result["column_number"]
          error_message += ", Column #{column_number}"
        end
      end
      error_context = get_error_message_context(validate_result['error_message'])
      error_message += ":\n\n#{validate_result['error_message']}\n\n#{error_context}"
      error(error_message)
    when Mortar::API::Validate::STATUS_KILLED
      error("Validate killed by user.")
    when Mortar::API::Validate::STATUS_SUCCESS
      display("Your script is valid.")
    else
      raise RuntimeError, "Unknown validate status: #{validate_result['status']} for validate_id: #{validate_id}"
    end
  end
end

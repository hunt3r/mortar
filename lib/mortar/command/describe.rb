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

# show data schema for pigscript
#
class Mortar::Command::Describe < Mortar::Command::Base
  
  include Mortar::Git
    
  # describe PIGSCRIPT ALIAS
  #
  # Describe the schema of an alias and all of its ancestors.
  #
  # -p, --parameter NAME=VALUE  # Set a pig parameter value in your script.
  # -f, --param-file PARAMFILE  # Load pig parameter values from a file.
  # -g, --pigversion PIG_VERSION # Set pig version.  Options are <PIG_VERSION_OPTIONS>.
  #
  # Examples:
  #     
  #     Describe the songs_sample relation in the generate_regression_model_coefficients.pig pigscript.
  #          $ mortar describe pigscripts/generate_regression_model_coefficients.pig songs_sample
  def index
    pigscript_name = shift_argument
    alias_name = shift_argument
    unless pigscript_name && alias_name
      error("Usage: mortar describe PIGSCRIPT ALIAS\nMust specify PIGSCRIPT and ALIAS.")
    end
    
    validate_arguments!
    pigscript = validate_script!(pigscript_name)
    
    if pigscript.is_a? Mortar::Project::ControlScript
      error "Currently Mortar does not support describing control scripts"
    end
    
    git_ref = sync_code_with_cloud()
    
    describe_id = nil
    action("Starting describe") do
      describe_id = api.post_describe(project.name, pigscript.name, alias_name, git_ref, 
        :pig_version => pig_version.version, 
        :project_script_path => pigscript.rel_path,
        :parameters => pig_parameters).body["describe_id"]
    end
        
    describe_result = nil
    display
    ticking(polling_interval) do |ticks|
      describe_result = api.get_describe(describe_id, :exclude_result => true).body
      is_finished =
        Mortar::API::Describe::STATUSES_COMPLETE.include?(describe_result["status_code"])
        
      redisplay("[#{spinner(ticks)}] Calculating schema for #{alias_name} and ancestors...",
        is_finished) # only display newline on last message
      if is_finished
        display
        break
      end
    end
    
    case describe_result['status_code']
    when Mortar::API::Describe::STATUS_FAILURE
      error_message = "Describe failed with #{describe_result['error_type'] || 'error'}"
      if line_number = describe_result["line_number"]
        error_message += " at Line #{line_number}"
        if column_number = describe_result["column_number"]
          error_message += ", Column #{column_number}"
        end
      end
      error_context = get_error_message_context(describe_result['error_message'])
      error_message += ":\n\n#{describe_result['error_message']}\n\n#{error_context}"
      error(error_message)
    when Mortar::API::Describe::STATUS_KILLED
      error("Describe killed by user.")
    when Mortar::API::Describe::STATUS_SUCCESS
      web_result_url = describe_result['web_result_url']
      display("Results available at #{web_result_url}")

      unless no_browser?
        action("Opening web browser to show results") do
          require "launchy"
          Launchy.open(web_result_url).join
        end
      end
    else
      raise RuntimeError, "Unknown describe status: #{describe_result['status']} for describe_id: #{describe_id}"
    end
  end
end

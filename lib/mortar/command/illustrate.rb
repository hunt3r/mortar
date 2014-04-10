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

# sample and show data flowing through a pigscript
#
class Mortar::Command::Illustrate < Mortar::Command::Base
  
  include Mortar::Git
    
  # illustrate PIGSCRIPT [ALIAS]
  #
  # Illustrate the effects and output of a pigscript.
  #
  # -s, --skippruning          # Don't try to reduce the illustrate results to the smallest size possible.
  # -p, --parameter NAME=VALUE  # Set a pig parameter value in your script.
  # -f, --param-file PARAMFILE  # Load pig parameter values from a file.
  # -g, --pigversion PIG_VERSION # Set pig version.  Options are <PIG_VERSION_OPTIONS>.
  # --no_browser                # Don't open the illustrate results automatically in the browser.
  #
  # Examples:
  #  
  #     Illustrate all relations in the generate_regression_model_coefficients pigscript.
  #         $ mortar illustrate pigscripts/generate_regression_model_coefficients.pig
  #
  def index
    pigscript_name = shift_argument
    alias_name = shift_argument
    validate_arguments!

    skip_pruning = options[:skippruning] ||= false
          
    unless pigscript_name
      error("Usage: mortar illustrate PIGSCRIPT [ALIAS]\nMust specify PIGSCRIPT.")
    end
    pigscript = validate_script!(pigscript_name)
    
    if pigscript.is_a? Mortar::Project::ControlScript
      error "Currently Mortar does not support illustrating control scripts"
    end
    
    git_ref = sync_code_with_cloud()

    illustrate_id = nil
    action("Starting illustrate") do
      illustrate_id = api.post_illustrate(project.name, pigscript.name, alias_name, skip_pruning, git_ref, 
        :pig_version => pig_version.version, 
        :project_script_path => pigscript.rel_path,
        :parameters => pig_parameters).body["illustrate_id"]
    end
        
    illustrate_result = nil
    display
    ticking(polling_interval) do |ticks|
      illustrate_result = api.get_illustrate(illustrate_id, :exclude_result => true).body
      is_finished =
        Mortar::API::Illustrate::STATUSES_COMPLETE.include?(illustrate_result["status_code"])
        
      redisplay("Status: %s %s" % [
        illustrate_result['status_description'] + (is_finished ? "" : "..."),
        is_finished ? " " : spinner(ticks)],
        is_finished) # only display newline on last message
      if is_finished
        display
        break
      end
    end
    
    case illustrate_result['status_code']
    when Mortar::API::Illustrate::STATUS_FAILURE
      error_message = "Illustrate failed with #{illustrate_result['error_type'] || 'error'}"
      if line_number = illustrate_result["line_number"]
        error_message += " at Line #{line_number}"
        if column_number = illustrate_result["column_number"]
          error_message += ", Column #{column_number}"
        end
      end
      error_context = get_error_message_context(illustrate_result['error_message'])
      error_message += ":\n\n#{illustrate_result['error_message']}\n\n#{error_context}"
      error(error_message)
    when Mortar::API::Illustrate::STATUS_KILLED
      error("Illustrate killed by user.")
    when Mortar::API::Illustrate::STATUS_SUCCESS
      web_result_url = illustrate_result['web_result_url']
      display("Results available at #{web_result_url}")

      unless no_browser?
        action("Opening web browser to show results") do
          require "launchy"
          Launchy.open(web_result_url).join
        end
      end
    else
      raise RuntimeError, "Unknown illustrate status: #{illustrate_result['status_code']} for illustrate_id: #{illustrate_id}"
    end
  end
end

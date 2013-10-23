#
# Copyright 2013 Mortar Data Inc.
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
# Portions of this code from heroku (https://github.com/heroku/heroku/) Copyright Heroku 2008 - 2013,
# used under an MIT license (https://github.com/heroku/heroku/blob/master/LICENSE).
#

require "mortar/command/base"

# manage project configuration variables
#
class Mortar::Command::Config < Mortar::Command::Base

  # config
  #
  # Display the configuration variables for a project.
  #
  # -s, --shell  # output config vars in shell format
  #
  #
  # $ mortar config
  # A: one
  # B: two
  #
  # $ mortar config --shell
  # A=one
  # B=two
  #
  def index
    validate_arguments!
    project_name = options[:project] || project.name
    vars = api.get_config_vars(project_name).body['config']
    if vars.empty?
      display("#{project_name} has no config vars.")
    else
      vars.each {|key, value| vars[key] = value.to_s}
      if options[:shell]
        vars.keys.sort.each do |key|
          display(%{#{key}=#{vars[key]}})
        end
      else
        styled_header("#{project_name} Config Vars")
        styled_hash(vars)
      end
    end
  end
end

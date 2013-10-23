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

# manage project config variables
#
class Mortar::Command::Config < Mortar::Command::Base

  # config
  #
  # Display the config vars for a project.
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
  
  # config:get KEY
  #
  # display a config var for a project
  #
  #Examples:
  #
  # $ mortar config:get MY_CONFIG_VAR
  # one
  #
  def get
    unless key = shift_argument
      error("Usage: mortar config:get KEY\nMust specify KEY.")
    end
    validate_arguments!
    project_name = options[:project] || project.name

    vars = api.get_config_vars(project_name).body['config']
    key_name, value = vars.detect {|k,v| k == key}
    unless key_name
      error("Config var #{key} is not defined for project #{project_name}.")
    end
    
    display(value.to_s)
  end
  
  # config:set KEY1=VALUE1 [KEY2=VALUE2 ...]
  #
  # Set one or more config vars
  #
  #Example:
  #
  # $ mortar config:set A=one
  # Setting config vars... done.
  # A: one
  #
  # $ mortar config:set A=one B=two
  # Setting config vars... done.
  # A: one
  # B: two
  #
  def set
    unless args.size > 0 and args.all? { |a| a.include?('=') }
      error("Usage: mortar config:set KEY1=VALUE1 [KEY2=VALUE2 ...]\nMust specify KEY and VALUE to set.")
    end

    vars = args.inject({}) do |vars, arg|
      key, value = arg.split('=', 2)
      vars[key] = value
      vars
    end

    project_name = options[:project] || project.name

    action("Setting config vars for project #{project_name}") do
      api.put_config_vars(project_name, vars)
    end

    vars.each {|key, value| vars[key] = value.to_s}
    styled_hash(vars)
  end
  
  alias_command "config:add", "config:set"
  alias_command "config:put", "config:set"
  
end

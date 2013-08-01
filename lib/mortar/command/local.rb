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

require "mortar/local/controller"
require "mortar/command/base"
require "mortar/generators/characterize_generator"

# run select pig commands on your local machine
#
class Mortar::Command::Local < Mortar::Command::Base


  # local:configure
  #
  # Install dependencies for running this mortar project locally - other mortar:local commands will also perform this step automatically.
  #
  # --project-root PROJECTDIR  # The root directory of the project if not the CWD
  #
  def configure

    # cd into the project root
    project_root = options[:project_root] ||= Dir.getwd
    unless File.directory?(project_root)
      error("No such directory #{project_root}")
    end
    Dir.chdir(project_root)

    ctrl = Mortar::Local::Controller.new
    ctrl.install_and_configure
  end

  # local:run SCRIPT
  #
  # Run a job on your local machine.
  #
  # -p, --parameter NAME=VALUE  # Set a pig parameter value in your script.
  # -f, --param-file PARAMFILE  # Load pig parameter values from a file.
  # --project-root PROJECTDIR   # The root directory of the project if not the CWD
  #
  #Examples:
  #
  #    Run the generate_regression_model_coefficients script locally.
  #        $ mortar local:run pigscripts/generate_regression_model_coefficients.pig
  def run
    script_name = shift_argument
    unless script_name
      error("Usage: mortar local:run SCRIPT\nMust specify SCRIPT.")
    end
    validate_arguments!

    # cd into the project root
    project_root = options[:project_root] ||= Dir.getwd
    unless File.directory?(project_root)
      error("No such directory #{project_root}")
    end
    Dir.chdir(project_root)
    script = validate_script!(script_name)
    ctrl = Mortar::Local::Controller.new
    ctrl.run(script, pig_parameters)
  end

  # local:characterize 
  #
  # Characterize will inspect your input data, inferring a schema and 
  #    generating keys, if needed. It will output CSV containing various
  #    statistics about your data (most common values, percent null, etc.)
  # 
  # -f, --param-file PARAMFILE # Load pig parameter values from a file
  #
  # Load some data and emit statistics.
  # PARAMFILE:
  #   LOADER=<full class path of loader function>
  #   INPUT_SRC=<Location of the input data>
  #   OUTPUT_PATH=<Relative path from project root for output>
  #   INFER_TYPES=<when true, recursively infers types for input data>
  #
  # Example paramfile:
  #   LOADER=org.apache.pig.piggybank.storage.JsonLoader()
  #   INPUT_SRC=s3n://twitter-gardenhose-mortar/example
  #   OUTPUT_PATH=twitter_char
  #   INFER_TYPES=true
  #
  def characterize
    validate_arguments!

    #cd into the project root
    project_root = options[:project_root] ||= Dir.getwd
    unless File.directory?(project_root)
      error("No such directory #{project_root}")
    end

    Dir.chdir(project_root)

    gen = Mortar::Generators::CharacterizeGenerator.new
    gen.generate_characterize

    controlscript_name = "controlscripts/lib/characterize_control.py"
    gen = Mortar::Generators::CharacterizeGenerator.new
    gen.generate_characterize
    script = validate_script!(controlscript_name)
    ctrl = Mortar::Local::Controller.new
    ctrl.run(script, pig_parameters)
    gen.cleanup_characterize(project_root)
  end

  # local:illustrate PIGSCRIPT [ALIAS]
  #
  # Locally illustrate the effects and output of a pigscript.
  # If an alias is specified, will show data flow from the ancestor LOAD statements to the alias itself.
  # If no alias is specified, will show data flow through all aliases in the script.
  #
  # -s, --skippruning           # Don't try to reduce the illustrate results to the smallest size possible.
  # -p, --parameter NAME=VALUE  # Set a pig parameter value in your script.
  # -f, --param-file PARAMFILE  # Load pig parameter values from a file.
  # --no_browser                # Don't open the illustrate results automatically in the browser.
  # --project-root PROJECTDIR   # The root directory of the project if not the CWD
  #
  # Examples:
  #
  #     Illustrate all relations in the generate_regression_model_coefficients pigscript:
  #         $ mortar illustrate pigscripts/generate_regression_model_coefficients.pig
  def illustrate
    pigscript_name = shift_argument
    alias_name = shift_argument
    skip_pruning = options[:skippruning] ||= false

    unless pigscript_name
      error("Usage: mortar local:illustrate PIGSCRIPT [ALIAS]\nMust specify PIGSCRIPT.")
    end

    # cd into the project root
    project_root = options[:project_root] ||= Dir.getwd
    unless File.directory?(project_root)
      error("No such directory #{project_root}")
    end
    Dir.chdir(project_root)

    validate_arguments!
    pigscript = validate_pigscript!(pigscript_name)

    ctrl = Mortar::Local::Controller.new
    ctrl.illustrate(pigscript, alias_name, pig_parameters, skip_pruning)
  end


  # local:validate SCRIPT
  #
  # Locally validate the syntax of a script.
  #
  # -p, --parameter NAME=VALUE  # Set a pig parameter value in your script.
  # -f, --param-file PARAMFILE  # Load pig parameter values from a file.
  # --project-root PROJECTDIR   # The root directory of the project if not the CWD
  #
  #Examples:
  #
  #    Check the pig syntax of the generate_regression_model_coefficients pigscript locally.
  #        $ mortar local:validate pigscripts/generate_regression_model_coefficients.pig
  def validate
    script_name = shift_argument
    unless script_name
      error("Usage: mortar local:validate SCRIPT\nMust specify SCRIPT.")
    end
    validate_arguments!

    # cd into the project root
    project_root = options[:project_root] ||= Dir.getwd
    unless File.directory?(project_root)
      error("No such directory #{project_root}")
    end
    Dir.chdir(project_root)

    script = validate_script!(script_name)
    ctrl = Mortar::Local::Controller.new
    ctrl.validate(script, pig_parameters)
  end

end

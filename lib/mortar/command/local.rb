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
  # -g, --pigversion PIG_VERSION  # Set pig version.  Options are <PIG_VERSION_OPTIONS>.
  # --project-root PROJECTDIR     # The root directory of the project if not the CWD
  #
  def configure
    validate_arguments!

    # cd into the project root
    project_root = options[:project_root] ||= Dir.getwd
    unless File.directory?(project_root)
      error("No such directory #{project_root}")
    end
    Dir.chdir(project_root)

    ctrl = Mortar::Local::Controller.new
    ctrl.install_and_configure(pig_version, nil, true)
  end

  # local:run SCRIPT
  #
  # Run a job on your local machine.
  #
  # -p, --parameter NAME=VALUE  # Set a pig parameter value in your script.
  # -f, --param-file PARAMFILE  # Load pig parameter values from a file.
  # -g, --pigversion PIG_VERSION  # Set pig version.  Options are <PIG_VERSION_OPTIONS>.
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
    params = config_parameters.concat(pig_parameters)

    ctrl = Mortar::Local::Controller.new
    ctrl.run(script, pig_version, params)
  end

  # local:characterize -f PARAMFILE
  #
  # Characterize will inspect your input data, inferring a schema and 
  #    generating keys, if needed. It will output CSV containing various
  #    statistics about your data (most common values, percent null, etc.)
  # 
  # -f, --param-file PARAMFILE # Load pig parameter values from a file
  # -g, --pigversion PIG_VERSION  # Set pig version.  Options are <PIG_VERSION_OPTIONS>.
  #
  # Load some data and emit statistics.
  # PARAMFILE (Required):
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

    unless options[:param_file]
      error("Usage: mortar local:characterize -f PARAMFILE.\nMust specify parameter file. For detailed help run:\n\n   mortar local:characterize -h")
    end

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
    params = config_parameters.concat(pig_parameters)

    ctrl = Mortar::Local::Controller.new
    ctrl.run(script, pig_version, params)
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
  # -g, --pigversion PIG_VERSION # Set pig version.  Options are <PIG_VERSION_OPTIONS>.
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
    validate_arguments!

    skip_pruning = options[:skippruning] ||= false
    no_browser = options[:no_browser] ||= false

    unless pigscript_name
      error("Usage: mortar local:illustrate PIGSCRIPT [ALIAS]\nMust specify PIGSCRIPT.")
    end

    # cd into the project root
    project_root = options[:project_root] ||= Dir.getwd
    unless File.directory?(project_root)
      error("No such directory #{project_root}")
    end
    Dir.chdir(project_root)

    pigscript = validate_pigscript!(pigscript_name)
    params = config_parameters.concat(pig_parameters)

    ctrl = Mortar::Local::Controller.new
    ctrl.illustrate(pigscript, alias_name, pig_version, params, skip_pruning, no_browser)
  end


  # local:validate SCRIPT
  #
  # Locally validate the syntax of a script.
  #
  # -p, --parameter NAME=VALUE  # Set a pig parameter value in your script.
  # -f, --param-file PARAMFILE  # Load pig parameter values from a file.
  # -g, --pigversion PIG_VERSION  # Set pig version.  Options are <PIG_VERSION_OPTIONS>.
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
    params = config_parameters.concat(pig_parameters)

    ctrl = Mortar::Local::Controller.new
    ctrl.validate(script, pig_version, params)
  end


  # local:repl
  #
  # Start a local Pig REPL session
  # -p, --parameter NAME=VALUE  # Set a pig parameter value in your script.
  # -f, --param-file PARAMFILE  # Load pig parameter values from a file.
  # -g, --pigversion PIG_VERSION  # Set pig version.  Options are <PIG_VERSION_OPTIONS>.
  #
  def repl
    validate_arguments!

    params = config_parameters.concat(pig_parameters)
    
    ctrl = Mortar::Local::Controller.new
    ctrl.repl(pig_version, params)
  end


  # local:luigi SCRIPT
  #
  # Run a luigi pipeline script on your local machine in local scheduler mode.
  # Any additional command line arguments will be passed directly to the luigi script.
  #
  # --project-root PROJECTDIR   # The root directory of the project if not the CWD
  # -p, --parameter NAME=VALUE  # [deprecated] Instead, pass luigi parameters directly as options (see below)
  # -f, --param-file PARAMFILE  # [deprecated] Instead, pass luigi parameters directly as options (see below)
  #
  #Examples:
  #
  #    Run the recsys luigi script with a parameter named date-interval
  #        $ mortar local:luigi luigiscripts/recsys.py --date-interval 2012-04
  def luigi
    script_name = shift_argument
    unless script_name
      error("Usage: mortar local:luigi SCRIPT\nMust specify SCRIPT.")
    end
    
    # cd into the project root
    project_root = options[:project_root] ||= Dir.getwd
    unless File.directory?(project_root)
      error("No such directory #{project_root}")
    end
    Dir.chdir(project_root)

    script = validate_luigiscript!(script_name)
    
    #Set git ref as environment variable for mortar-luigi to use when
    #running a MortarTask
    git_ref = sync_code_with_cloud()
    ENV['MORTAR_LUIGI_GIT_REF'] = git_ref

    # pick up standard luigi-style params
    luigi_parameters = luigi_parameters()

    # pick up old pig-style parameters (included for backwards compatibility)
    pig_style_parameters = pig_parameters()
    if pig_style_parameters.length > 0
      warn "[DEPRECATION] Passing luigi parameters with -p is deprecated. Please pass them directly (e.g. --myparam myvalue)"
    end

    luigi_parameters.concat(pig_style_parameters)
    luigi_parameters.sort_by { |p| p['name'] }
    luigi_cli_parameters = luigi_parameters.map { |arg| ["--#{arg['name']}", "#{arg['value']}"] }.flatten

    ctrl = Mortar::Local::Controller.new
    ctrl.run_luigi(pig_version, script, luigi_cli_parameters)
  end

  # local:sqoop_table dbtype database-name table s3-destination
  #
  # Export data from an RDBMS table to S3.
  #
  # -h, --host HOSTNAME # Database host, localhost assumed if not specified
  # -u, --username USERNAME # User to log into the database with
  # -p, --password PASSWORD # Password to log into the database
  # -j, --jdbcdriver COM.DRIVER.BAR # Name of the JDBC driver class
  # -d, --direct # Use a direct import path
  # -r, --driverjar JARFILE # Path to the jar containing the jdbc driver
  #
  #Examples:
  #
  #    Export from a postgres database
  #        $ mortar local:sqoop_table postgres mydb mytable s3://com.dbhost01/archive -u steve -p stevespassword
  def sqoop_table
    dbtype = shift_argument
    unless dbtype
      error("Usage: mortar local:sqoop_table dbtype database-name table s3-destination\nMust specify database type.")
    end
    physdb = shift_argument
    unless physdb
      error("Usage: mortar local:sqoop_table dbtype database-name table s3-destination\nMust specify database name.")
    end
    dbtable = shift_argument
    unless dbtable
      error("Usage: mortar local:sqoop_table dbtype database-name table s3-destination\nMust specify database table.")
    end
    s3dest = shift_argument
    unless s3dest
      error("Usage: mortar local:sqoop_table dbtype database-name table s3-destination\nMust specify s3 destination.")
    end
    validate_arguments!

    dbhost = options[:host] || "localhost"
    connstr = jdbc_conn(dbtype, dbhost, physdb)

    ctrl = Mortar::Local::Controller.new
    ctrl.sqoop_export_table(pig_version, connstr, dbtable, s3dest, options)
  end

  # local:sqoop_query dbtype database-name query s3-destination
  #
  # Export the result of an SQL query to S3.
  #
  # -h, --host HOSTNAME # Database host, localhost assumed if not specified
  # -u, --username USERNAME # User to log into the database with
  # -p, --password PASSWORD # Password to log into the database
  # -j, --jdbcdriver COM.DRIVER.BAR # Name of the JDBC driver class
  # -d, --direct # Use a direct import path
  # -r, --driverjar JARFILE # Path to the jar containing the jdbc driver
  #
  #Examples:
  #
  #    Export from a postgres database
  #        $ mortar local:sqoop_query postgres mydb "select user_name, id from users" s3://com.dbhost01/archive
  def sqoop_query
    dbtype = shift_argument
    unless dbtype
      error("Usage: mortar local:sqoop_query dbtype database-name query s3-destination\nMust specify database type.")
    end
    physdb = shift_argument
    unless physdb
      error("Usage: mortar local:sqoop_query dbtype database-name query s3-destination\nMust specify database name.")
    end
    query = shift_argument
    unless query
      error("Usage: mortar local:sqoop_query dbtype database-name query s3-destination\nMust specify sql query.")
    end
    s3dest = shift_argument
    unless s3dest
      error("Usage: mortar local:sqoop_query dbtype database-name query s3-destination\nMust specify s3 destination.")
    end
    validate_arguments!

    dbhost = options[:host] || "localhost"
    connstr = jdbc_conn(dbtype, dbhost, physdb)

    ctrl = Mortar::Local::Controller.new
    ctrl.sqoop_export_query(pig_version, connstr, query, s3dest, options)
  end

  # local:sqoop_incremental dbtype database-name table column value s3-destination
  #
  # Export all records where column is > value
  #
  # -h, --host HOSTNAME # Database host, localhost assumed if not specified
  # -u, --username USERNAME # User to log into the database with
  # -p, --password PASSWORD # Password to log into the database
  # -j, --jdbcdriver COM.DRIVER.BAR # Name of the JDBC driver class
  # -d, --direct # Use a direct import path
  # -r, --driverjar JARFILE # Path to the jar containing the jdbc driver
  #
  #Examples:
  #
  #    Export from the newest users
  #        $ mortar local:sqoop_incremental postgres mydb users user_id 12345 s3://com.dbhost01/archive
  def sqoop_incremental
    dbtype = shift_argument
    unless dbtype
      error("Usage: mortar local:sqoop_incremental dbtype database-name table column value s3-destination\nMust specify database type.")
    end
    physdb = shift_argument
    unless physdb
      error("Usage: mortar local:sqoop_incremental dbtype database-name table column value s3-destination\nMust specify database name.")
    end
    table = shift_argument
    unless table
      error("Usage: mortar local:sqoop_incremental dbtype database-name table column value s3-destination\nMust specify database table.")
    end
    column = shift_argument
    unless column
      error("Usage: mortar local:sqoop_incremental dbtype database-name table column value s3-destination\nMust specify column.")
    end
    max_value = shift_argument
    unless max_value
      error("Usage: mortar local:sqoop_incremental dbtype database-name table column value s3-destination\nMust specify value.")
    end
    s3dest = shift_argument
    unless s3dest
      error("Usage: mortar local:sqoop_incremental dbtype database-name table column value s3-destination\nMust specify s3 destination.")
    end
    validate_arguments!

    dbhost = options[:host] || "localhost"
    connstr = jdbc_conn(dbtype, dbhost, physdb)

    ctrl = Mortar::Local::Controller.new
    ctrl.sqoop_export_incremental(pig_version, connstr, table, column, max_value, s3dest, options)
  end


end

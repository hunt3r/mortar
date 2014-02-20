## Copyright 2012 Mortar Data Inc.#
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

require "mortar/helpers"
require "mortar/auth"
require "mortar/pigversion"
require "mortar/local/pig"
require "mortar/local/java"
require "mortar/local/python"
require "mortar/local/jython"


class Mortar::Local::Controller
  include Mortar::Local::InstallUtil

  NO_JAVA_ERROR_MESSAGE = <<EOF
A suitable java installation could not be found.  If you already have java installed
please set your JAVA_HOME environment variable before continuing.  Otherwise, a
suitable java installation will need to be added to your local system.

Installing Java
On OSX run `javac` from the command line.  This will intiate the installation.  For
Linux systems please consult the documentation on your relevant package manager.
EOF

  NO_PYTHON_ERROR_MESSAGE = <<EOF
A suitable python installation could not be located.  Please ensure you have python 2.6+
installed on your local system.
EOF

  NO_VIRTENV_ERROR_MESSAGE = <<EOF
A suitable Python installation was found, but it is required that virtualenv be installed
as well.  You can install it with pip, or download it directly from:
https://pypi.python.org/pypi/virtualenv
EOF

  NO_AWS_KEYS_ERROR_MESSAGE = <<EOF
You have not set AWS access keys, which will often prevent you from accessing input data.  You can either:

- Login to your Mortar account to automatically sync your AWS keys from Mortar when running commands ("mortar login")

-  *or*, set your AWS keys via environment variables:

  export AWS_ACCESS_KEY="XXXXXXXXXXXX" 
  export AWS_SECRET_KEY="XXXXXXXXXXXX"

If your script does not need AWS S3 access, you can leave those values as XXXXXXXXXXXX.
EOF

  API_CONFIG_ERROR_MESSAGE = <<EOF
We were unable to sync your AWS keys from Mortar.  
To continue, please specify your amazon AWS access key via environment variable AWS_ACCESS_KEY and your AWS secret key via environment variable AWS_SECRET_KEY, e.g.:
  
  export AWS_ACCESS_KEY="XXXXXXXXXXXX"
  export AWS_SECRET_KEY="XXXXXXXXXXXX"
  
If your script does not need AWS S3 access, you can set these variables to XXXXXXXXXXXX.
EOF


  # Checks if the user has properly specified their AWS keys
  def verify_aws_keys()
    if (not (ENV['AWS_ACCESS_KEY'] and ENV['AWS_SECRET_KEY'])) then
      if not ENV['MORTAR_IGNORE_AWS_KEYS']
        return false
      else
        return true
      end
    else
      return true
    end
  end

  # Asks to sync with AWS if user has not setup their aws keys
  def require_aws_keys()        
    unless verify_aws_keys()
      auth = Mortar::Auth
      if !auth.has_credentials                      
        error(NO_AWS_KEYS_ERROR_MESSAGE)
      else
        vars = fetch_aws_keys(auth, Mortar::Command::Base.new)
        if vars['aws_access_key_id'] && vars['aws_secret_access_key']
          set_aws_keys(vars['aws_access_key_id'], vars['aws_secret_access_key'])
        else
          error(API_CONFIG_ERROR_MESSAGE)
        end
      end 
    end
  end

  # Fetches AWS Keys based on auth
  def fetch_aws_keys(auth, base)    
    project = base.project    
    project_name = base.options[:project] || project.name    
    return auth.api.get_config_vars(project_name).body['config']
  end

  def set_aws_keys(aws_access_key, aws_secret_key)    
    ENV['AWS_ACCESS_KEY'] = aws_access_key
    ENV['AWS_SECRET_KEY'] = aws_secret_key    
  end
  
  # Main entry point to perform installation and configuration necessary
  # to run pig on the users local machine
  def install_and_configure(pig_version=nil)
    #To support old watchtower plugins we'll accept nil pig_version
    if pig_version.nil?
      pig_version = Mortar::PigVersion::Pig09.new
    end
    java = Mortar::Local::Java.new()
    unless java.check_install
      error(NO_JAVA_ERROR_MESSAGE)
    end

    pig = Mortar::Local::Pig.new()
    pig.install_or_update(pig_version)

    py = Mortar::Local::Python.new()
    unless py.check_or_install
      error(NO_PYTHON_ERROR_MESSAGE)
    end

    unless py.check_virtualenv
      error(NO_VIRTENV_ERROR_MESSAGE)
    end

    unless py.setup_project_python_environment
      msg = "\nUnable to setup a python environment with your dependencies, "
      msg += "see #{py.pip_error_log_path} for more details"
      error(msg)
    end

    jy = Mortar::Local::Jython.new()
    jy.install_or_update()

    ensure_local_install_dirs_in_gitignore
  end

  def ensure_local_install_dirs_in_gitignore()
    if File.exists? local_project_gitignore
      File.open(local_project_gitignore, 'r+') do |gitignore|
        contents = gitignore.read()
        gitignore.seek(0, IO::SEEK_END)

        unless contents[-1] == "\n"
          gitignore.puts "" # write a newline
        end

        unless contents.include? local_install_directory_name
          gitignore.puts local_install_directory_name
        end

        unless contents.include? "logs"
          gitignore.puts "logs"
        end

        unless contents.include? "illustrate-output"
          gitignore.puts "illustrate-output"
        end
      end
    end
  end

  # Main entry point for user running a pig script
  def run(pig_script, pig_version, pig_parameters)
    require_aws_keys
    install_and_configure(pig_version)
    pig = Mortar::Local::Pig.new()
    pig.run_script(pig_script, pig_version, pig_parameters)
  end

  # Main entry point for illustrating a pig alias
  def illustrate(pig_script, pig_alias, pig_version, pig_parameters, skip_pruning, no_browser)
    require_aws_keys
    install_and_configure(pig_version)
    pig = Mortar::Local::Pig.new()
    pig.illustrate_alias(pig_script, pig_alias, skip_pruning, no_browser, pig_version, pig_parameters)
  end

  def validate(pig_script, pig_version, pig_parameters)
    install_and_configure(pig_version)
    pig = Mortar::Local::Pig.new()
    pig.validate_script(pig_script, pig_version, pig_parameters)
  end

  def repl(pig_version, pig_parameters)
    install_and_configure(pig_version)
    pig = Mortar::Local::Pig.new()
    pig.launch_repl(pig_version, pig_parameters)
  end

end

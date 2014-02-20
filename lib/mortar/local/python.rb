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

require "mortar/local/installutil"

class Mortar::Local::Python
  include Mortar::Local::InstallUtil

  PYTHON_OSX_TGZ_NAME = "mortar-python-osx.tgz"
  PYTHON_OSX_TGZ_DEFAULT_URL_PATH = "resource/python_osx"

  MORTAR_PYTHON_PACKAGES = ["luigi", "mortar-luigi"]

  # Path to the python binary that should be used
  # for running UDFs
  @command = nil


  @candidate_pythons = nil

  # Execute either an installation of python or an inspection
  # of the local system to see if a usable python is available
  def check_or_install
    if osx?
      # We currently only install python for osx
      install_or_update_osx
    else
      # Otherwise we check that the system supplied python will be sufficient
      check_system_python
    end
  end

  def check_virtualenv
    # Assumes you've already called check_or_install(), in which case
    # we can skip osx as its installation includeds virtualenv
    if osx?
      return true
    else
      return check_pythons_for_virtenv
    end

  end

  def should_do_update?
    return is_newer_version('python', python_archive_url)
  end

  # Performs an installation of python specific to this project, this
  # install includes pip and virtualenv
  def install_or_update_osx
    @command = "#{local_install_directory}/python/bin/python"
    if should_do_python_install?
      action "Installing python to #{local_install_directory_name}" do
        install_osx
      end
    elsif should_do_update?
      action "Updating to latest python in #{local_install_directory_name}" do
        install_osx
      end
    end
    true
  end

  def install_osx
    FileUtils.mkdir_p(local_install_directory)
    python_tgz_path = File.join(local_install_directory, PYTHON_OSX_TGZ_NAME)
    download_file(python_archive_url, python_tgz_path)
    extract_tgz(python_tgz_path, local_install_directory)

    # This has been seening coming out of the tgz w/o +x so we do
    # here to be sure it has the necessary permissions
    FileUtils.chmod(0755, @command)
    File.delete(python_tgz_path)
    note_install("python")
  end

  # Determines if a python install needs to occur, true if no
  # python install present or a newer version is available
  def should_do_python_install?
    return (osx? and (not (File.exists?(python_directory))))
  end

  def candidates
    @candidate_pythons.dup
  end

  # Checks if there is a usable versionpython already installed
  def check_system_python
    @candidate_pythons = lookup_local_pythons
    return 0 != @candidate_pythons.length
  end

  # Inspects the list of found python installations and
  # checks if they have virtualenv installed. The first
  # one found will be used.
  def check_pythons_for_virtenv
    @candidate_pythons.each{ |py|
      if has_virtualenv_installed(py)
        @command = py
        return true
      end
    }
    return false
  end

  # Checks if the specified python command has
  # virtualenv installed
  def has_virtualenv_installed(python)
    `#{python} -m virtualenv --help 2>&1`
    if (0 != $?.to_i)
      false
    else
      true
    end
  end

  def lookup_local_pythons
    # Check several python commands in decending level of desirability
    found_bins = []
    [ "python#{desired_python_minor_version}", "python" ].each{ |cmd|
      path_to_python = `which #{cmd}`.to_s.strip
      if path_to_python != ''
        found_bins << path_to_python
      end
    }
    return found_bins
  end


  def desired_python_minor_version
    return "2.7"
  end

  def pip_requirements_path
    return ENV.fetch('PIP_REQ_FILE', File.join(Dir.getwd, "udfs", "python", "requirements.txt"))
  end

  def has_python_requirements
    return File.exists?(pip_requirements_path)
  end

  def python_env_dir
    return "#{local_install_directory}/pythonenv"
  end

  def python_directory
    return "#{local_install_directory}/python"
  end

  def python_archive_url
    full_host  = (host =~ /^http/) ? host : "https://api.#{host}"
    default_url = full_host + "/" + PYTHON_OSX_TGZ_DEFAULT_URL_PATH
    return ENV.fetch('PYTHON_DISTRO_URL', default_url)
  end

  def has_valid_virtualenv?
    output = `#{@command} -m virtualenv #{python_env_dir} 2>&1`
    if 0 != $?.to_i
      File.open(virtualenv_error_log_path, 'w') { |f|
        f.write(output)
      }
      return false
    end
    return true
  end

  # Creates a virtualenv in a well known location and installs any packages
  # necessary for the users python udf
  def setup_project_python_environment
    if not has_valid_virtualenv?
      return false
    end
    if should_do_requirements_install
      action "Installing python UDF dependencies" do
        pip_output = `. #{python_env_dir}/bin/activate &&
          #{python_env_dir}/bin/pip install --requirement #{pip_requirements_path}`
          if 0 != $?.to_i
            File.open(pip_error_log_path, 'w') { |f|
              f.write(pip_output)
            }
            return false
          end
        note_install("pythonenv")
      end
    end
    if should_install_python_dependencies?
      unless install_python_dependencies()
        return false
      end
    end
    return true
  end

  def pip_error_log_path
    return ENV.fetch('PIP_ERROR_LOG', "dependency_install.log")
  end

  def virtualenv_error_log_path
    return ENV.fetch('VE_ERROR_LOG', "virtualenv.log")
  end

  # Whether or not we need to do a `pip install -r requirements.txt` because
  # we've never done one before or the dependencies have changed
  def should_do_requirements_install
    if has_python_requirements
      if not install_date('pythonenv')
        # We've never done an install from requirements.txt before
        return true
      else
        return (requirements_edit_date > install_date('pythonenv'))
      end
    else
      return false
    end
  end

  # Date of last change to the requirements file
  def requirements_edit_date
    if has_python_requirements
      return File.mtime(pip_requirements_path).to_i
    else
      return nil
    end
  end

  def mortar_package_url(package)
    return "http://s3.amazonaws.com/mortar-pypi/#{package}/#{package}.tar.gz";
  end

  def update_mortar_package?(package)
    return is_newer_version(mortar_package_dir(package), mortar_package_url(package))
  end

  def mortar_packages_dir
    return "pythonenv/mortar-packages"
  end

  def mortar_package_dir(package)
    package_dir = "#{mortar_packages_dir}/#{package}"
  end

  def should_install_python_dependencies?
    MORTAR_PYTHON_PACKAGES.each{ |package|
      if update_mortar_package? package
        return true
      end
    }
    return false
  end

  def install_python_dependencies
    action "Installing python dependencies to #{local_install_directory_name}" do
      ensure_mortar_local_directory mortar_packages_dir
      MORTAR_PYTHON_PACKAGES.each{ |package_name|
        unless install_mortar_python_package(package_name)
          return false
        end
      }
    end
    return true
  end

  def local_activate_path
    return "#{python_env_dir}/bin/activate"
  end

  def local_python_bin
    return "#{python_env_dir}/bin/python"
  end

  def local_pip_bin
    return "#{python_env_dir}/bin/pip"
  end

  def pip_install package_url
    # Note that we're executing pip by passing it as a script for python to execute, this is
    # explicitly done to deal with this command breaking due to the maximum size of the path
    # to the interpreter in a shebang.  Since the containing virtualenv is already buried
    # several layers deep in the .mortar-local directory we're very likely to (read: have) hit
    # this limit.  This unfortunately leads to very vague errors about pip not existing when
    # in fact it is the truncated path to the interpreter that does not exist.  I would now
    # like the last day of my life back.
    pip_output = `. #{local_activate_path} && #{local_python_bin} #{local_pip_bin} install  #{package_url} --use-mirrors;`
    if 0 != $?.to_i
      File.open(pip_error_log_path, 'w') { |f|
        f.write(pip_output)
      }
      return false
    else
      return true
    end
  end

  def install_mortar_python_package(package_name)
    unless pip_install mortar_package_url(package_name)
        return false
    end
    ensure_mortar_local_directory mortar_package_dir(package_name)
    note_install mortar_package_dir(package_name)
  end

  def run_luigi_script(luigi_script, user_script_args)
    template_params = luigi_command_template_parameters(luigi_script, user_script_args)
    return run_templated_script(python_command_script_template_path, template_params)
  end

  # Path to the template which generates the bash script for running python
  def python_command_script_template_path
    File.expand_path("../../templates/script/runpython.sh", __FILE__)
  end

  def luigi_logging_config_file_path
    File.expand_path("../../conf/luigi/logging.ini", __FILE__)
  end

  def luigi_command_template_parameters(luigi_script, user_script_args)
    script_args = [
      "--local-scheduler",
      "--logging-conf-file #{luigi_logging_config_file_path}",
      user_script_args.join(" "),
    ]
    return {
      :python_arugments => "",
      :python_script => luigi_script.executable_path(),
      :script_arguments => script_args.join(" ")
    }
  end

end

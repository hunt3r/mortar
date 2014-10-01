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

require "erb"
require 'tempfile'
require "mortar/helpers"
require "mortar/local/installutil"
require "mortar/local/params"

class Mortar::Local::Pig
  include Mortar::Local::InstallUtil
  include Mortar::Local::Params

  PIG_LOG_FORMAT = "humanreadable"
  LIB_TGZ_NAME = "lib-common.tar.gz"
  PIG_COMMON_LIB_URL_PATH = "resource/lib_common"


  #This needs to be defined for watchtower.
  DEFAULT_PIGOPTS_FILES = %w(
      /lib-common/conf/pig-hawk-global.properties
      /lib-common/conf/pig-cli-local-dev.properties
  )

  # Tempfile objects have a hook to delete the file when the object is
  # destroyed by the garbage collector.  In practice this means that a
  # file we want sitting around could disappear out from under us. To
  # prevent this behavior, we're keeping references to these objects so
  # that the garbage collector will not destroy them until the program
  # exits (and our files won't be deleted until we don't care about them
  # any more).
  @temp_file_objects

  # We copy some resources to the user's illustrate-output directory
  # for styling the output. This only happens if they are not already present.
  @resource_locations
  @resource_destinations

  attr_accessor :resource_locations
  attr_accessor :resource_destinations

  def initialize
    @temp_file_objects = []

    @resource_locations = { 
      "illustrate_template" => File.expand_path("../../templates/report/illustrate-report.html", __FILE__),
      "illustrate_css" => File.expand_path("../../../../css/illustrate.css", __FILE__),
      "jquery" => File.expand_path("../../../../js/jquery-1.7.1.min.js", __FILE__),
      "jquery_transit" => File.expand_path("../../../../js/jquery.transit.js", __FILE__),
      "jquery_stylestack" => File.expand_path("../../../../js/jquery.stylestack.js", __FILE__),
      "mortar_table" => File.expand_path("../../../../js/mortar-table.js", __FILE__),
      "zeroclipboard" => File.expand_path("../../../../js/zero_clipboard.js", __FILE__),
      "zeroclipboard_swf" => File.expand_path("../../../../flash/zeroclipboard.swf", __FILE__)
  }

  @resource_destinations = {
      "illustrate_html" => "illustrate-output/illustrate-output.html",
      "illustrate_css" => "illustrate-output/resources/css/illustrate-output.css",
      "jquery" => "illustrate-output/resources/js/jquery-1.7.1.min.js",
      "jquery_transit" => "illustrate-output/resources/js/jquery.transit.js",
      "jquery_stylestack" => "illustrate-output/resources/js/jquery.stylestack.js",
      "mortar_table" => "illustrate-output/resources/js/mortar-table.js",
      "zeroclipboard" => "illustrate-output/resources/js/zero_clipboard.js",
      "zeroclipboard_swf" => "illustrate-output/resources/flash/zeroclipboard.swf"
  }
  end

  def command(pig_version)
    return File.join(pig_directory(pig_version), "bin", "pig")
  end

  def pig_directory(pig_version)
    return File.join(local_install_directory, pig_version.name)
  end

  def lib_directory
    return File.join(local_install_directory, "lib-common")
  end

  def pig_archive_url(pig_version)
    full_host  = (host =~ /^http/) ? host : "https://api.#{host}"
    default_url = full_host + "/" + pig_version.tgz_default_url_path
    ENV.fetch('PIG_DISTRO_URL', default_url)
  end

  def lib_archive_url
    full_host  = (host =~ /^http/) ? host : "https://api.#{host}"
    default_url = full_host + "/" + PIG_COMMON_LIB_URL_PATH
    ENV.fetch('COMMON_LIB_DISTRO_URL', default_url)
  end

  # Determines if a pig install needs to occur, true if no pig install present
  def should_do_pig_install?(pig_version)
    not (File.exists?(pig_directory(pig_version)))
  end

  def should_do_lib_install?
    not (File.exists?(lib_directory))
  end

  # Determines if a pig install needs to occur, true if server side
  # pig tgz is newer than date of the existing install
  def should_do_pig_update?(pig_version, command=nil)
    return is_newer_version(pig_version.name, pig_archive_url(pig_version), command)
  end

  def should_do_lib_update?
    return is_newer_version('lib-common', lib_archive_url)
  end

  def install_or_update(pig_version, command=nil)
    if should_do_pig_install?(pig_version)
      action "Installing #{pig_version.name} to #{local_install_directory_name}" do
        install_pig(pig_version, command)
      end
    elsif should_do_pig_update?(pig_version, command)
      action "Updating to latest #{pig_version.name} in #{local_install_directory_name}" do
        install_pig(pig_version)
      end
    end

    if should_do_lib_install?
      action "Installing pig dependencies to #{local_install_directory_name}" do
        install_lib()
      end
    elsif should_do_lib_update?
      action "Updating to latest pig dependencies in #{local_install_directory_name}" do
        install_lib()
      end
    end
  end

  # Installs pig for this project if it is not already present
  def install_pig(pig_version, command=nil)
    #Delete the directory if it already exists to ensure cruft isn't left around.
    if File.directory? pig_directory(pig_version)
      FileUtils.rm_rf pig_directory(pig_version)
    end

    FileUtils.mkdir_p(local_install_directory)
    local_tgz = File.join(local_install_directory, pig_version.tgz_name)
    download_file(pig_archive_url(pig_version), local_tgz, command)
    extract_tgz(local_tgz, local_install_directory)

    # This has been seening coming out of the tgz w/o +x so we do
    # here to be sure it has the necessary permissions
    FileUtils.chmod(0755, command(pig_version))

    File.delete(local_tgz)
    note_install(pig_version.name)
  end

  def install_lib
    #Delete the directory if it already exists to ensure cruft isn't left around.
    if File.directory? lib_directory
      FileUtils.rm_rf lib_directory
    end

    FileUtils.mkdir_p(local_install_directory)
    local_tgz = File.join(local_install_directory, LIB_TGZ_NAME)
    download_file(lib_archive_url, local_tgz)
    extract_tgz(local_tgz, local_install_directory)

    File.delete(local_tgz)
    note_install("lib-common")
  end

  def validate_script(pig_script, pig_version, pig_parameters)
    run_pig_command(" -check #{pig_script.path}", pig_version, pig_parameters)
  end

  def launch_repl(pig_version, pig_parameters)
    # The REPL is very likely to be run outside a mortar project and almost equally as likely
    # to be run in the users home directory.  The default log4j config file references pig log
    # file as being ../logs/local-pig.log, which is a path relative to the 'pigscripts' directory.
    # Since we very likely aren't going be run from a mortar project we won't have a pigscripts
    # directory to cd into, so log4j spits out an ugly error message when it doesn't have permissions
    # to create /home/logs/local-pig.log. So to work around this we copy the log4j configuration and
    # overwrite the log file to no longer be relative.
    File.open(log4j_conf_no_project, 'w') do |out|
      out << File.open(log4j_conf).read.gsub(/log4j.appender.LogFileAppender.File=.*\n/,
                                        "log4j.appender.LogFileAppender.File=local-pig.log\n")
    end
    run_pig_command(" ", pig_version, pig_parameters)
  end


  # run the pig script with user supplied pig parameters
  def run_script(pig_script, pig_version, pig_parameters)
    run_pig_command(" -f #{pig_script.path}", pig_version, pig_parameters, true)
  end

  # Create a temp file to be used for writing the illustrate
  # json output, and return it's path. This data file will
  # later be used to create the result html output. Tempfile
  # will take care of cleaning up the file when we exit.
  def create_illustrate_output_path
    # Using Tempfile for the path generation and so that the
    # file will be cleaned up on process exit
    outfile = Tempfile.new("mortar-illustrate-output")
    outfile.close(false)
    outfile.path
  end

  # Given a file path, open it and decode the containing text
  def decode_illustrate_input_file(illustrate_outpath)
    data_raw = File.read(illustrate_outpath)
    begin
      data_encoded = data_raw.encode('UTF-8', 'binary', :invalid => :replace, :undef => :replace, :replace => '')
    rescue NoMethodError
      require 'iconv'
      ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
      data_encoded = ic.iconv(data_raw)
    end
  end

  def show_illustrate_output_browser(illustrate_outpath)
    ensure_dir_exists("illustrate-output")
    ensure_dir_exists("illustrate-output/resources")
    ensure_dir_exists("illustrate-output/resources/css")
    ensure_dir_exists("illustrate-output/resources/js")
    ensure_dir_exists("illustrate-output/resources/flash")

    ["illustrate_css",
     "jquery", "jquery_transit", "jquery_stylestack",
     "mortar_table", "zeroclipboard", "zeroclipboard_swf"].each { |resource|
      copy_if_not_present_at_dest(@resource_locations[resource], @resource_destinations[resource])
    }

    # Pull in the dumped json file
    illustrate_data_json_text = decode_illustrate_input_file(illustrate_outpath)
    illustrate_data = json_decode(illustrate_data_json_text)

    # Render a template using it's values
    template_params = create_illustrate_template_parameters(illustrate_data)

    # template_params = {'tables' => []}
    erb = ERB.new(File.read(@resource_locations["illustrate_template"]), 0, "%<>")
    html = erb.result(BindingClazz.new(template_params).get_binding)

    # Write the rendered template out to a file
    File.open(@resource_destinations["illustrate_html"], 'w') { |f|
      f.write(html)
    }

    # Open a browser pointing to the rendered template output file
    action("Opening illustrate results from #{@resource_destinations["illustrate_html"]} ") do
      require "launchy"
      Launchy.open(File.expand_path(@resource_destinations["illustrate_html"]))
    end
  end

  def create_illustrate_template_parameters(illustrate_data)
    params = {}
    params['tables'] = illustrate_data['tables']
    params['udf_output'] = illustrate_data['udf_output']
    return params
  end

  def illustrate_alias(pig_script, pig_alias, skip_pruning, no_browser, pig_version, pig_parameters)
    cmd = "-e 'illustrate "

    # Parameters have to be entered with the illustrate command (as
    # apposed to as a command line argument) or it will result in an
    # 'Undefined parameter' error.
    param_file = make_pig_param_file(pig_parameters)
    cmd += "-param_file #{param_file} "

    # Now point us at the script/alias to illustrate
    illustrate_outpath = create_illustrate_output_path()
    cmd += "-script #{pig_script.path} -out #{illustrate_outpath} "
    
    if skip_pruning
      cmd += " -skipPruning "
    end

    if no_browser
      cmd += " -str '"
    else
      cmd += " -json '"
    end

    if pig_alias
      cmd += " #{pig_alias} "
    end

    result = run_pig_command(cmd, pig_version, [], false)
    if result
      if no_browser
        display decode_illustrate_input_file(illustrate_outpath)
      else
        show_illustrate_output_browser(illustrate_outpath)
      end
    end
  end

  # Run pig with the specified command ('command' is anything that
  # can be appended to the command line invocation of Pig that will
  # get it to do something interesting, such as '-f some-file.pig'
  def run_pig_command(cmd, pig_version, parameters = nil, jython_output = true)
    template_params = pig_command_script_template_parameters(cmd, pig_version, parameters)
    template_params['pig_opts']['jython.output'] = jython_output
    return run_templated_script(pig_command_script_template_path, template_params)
  end

  # Path to the template which generates the bash script for running pig
  def pig_command_script_template_path
    File.expand_path("../../templates/script/runpig.sh", __FILE__)
  end

  def template_params_classpath(pig_version=nil)
    # Need to support old watchtower plugins that don't set pig_version
    if pig_version.nil?
      pig_version = Mortar::PigVersion::Pig09.new
    end
    [ "#{pig_directory(pig_version)}/*",
      "#{pig_directory(pig_version)}/lib-local/*",
      "#{lib_directory}/lib-local/*",
      "#{pig_directory(pig_version)}/lib-pig/*",
      "#{pig_directory(pig_version)}/lib-cluster/*",
      "#{lib_directory}/lib-pig/*",
      "#{lib_directory}/lib-cluster/*",
      "#{jython_directory}/jython.jar",
      "#{lib_directory}/conf/jets3t.properties",
      "#{project_root}/lib/*",
    ].join(":")
  end

  def pig_classpath(pig_version)
    [ "#{pig_directory(pig_version)}/lib-local/*",
      "#{lib_directory}/lib-local/*",
      "#{pig_directory(pig_version)}/lib-pig/*",
      "#{pig_directory(pig_version)}/lib-cluster/*",
      "#{lib_directory}/lib-pig/*",
      "#{lib_directory}/lib-cluster/*",
      "#{jython_directory}/jython.jar",
      "#{project_root}/lib/*",
    ].join(":")
  end

  def log4j_conf
   "#{lib_directory}/conf/log4j-cli-local-dev.properties"
  end

  def log4j_conf_no_project
   "#{lib_directory}/conf/log4j-cli-local-no-project.properties"
  end

  # Parameters necessary for rendering the bash script template
  def pig_command_script_template_parameters(cmd, pig_version, pig_parameters)
    template_params = {}
    template_params['pig_params_file'] = make_pig_param_file(pig_parameters)
    template_params['pig_dir'] = pig_version.name
    template_params['pig_home'] = pig_directory(pig_version)
    template_params['pig_classpath'] = pig_classpath(pig_version)
    template_params['classpath'] = template_params_classpath
    template_params['log4j_conf'] = log4j_conf
    template_params['no_project_log4j_conf'] = log4j_conf_no_project
    template_params['pig_sub_command'] = cmd
    template_params['pig_opts'] = pig_options
    template_params
  end

  # Returns a hash of settings that need to be passed
  # in via pig options
  def pig_options
    opts = {}
    opts['fs.s3n.awsAccessKeyId'] = ENV['AWS_ACCESS_KEY']
    opts['fs.s3n.awsSecretAccessKey'] = ENV['AWS_SECRET_KEY']
    opts['fs.s3.awsAccessKeyId'] = ENV['AWS_ACCESS_KEY']
    opts['fs.s3.awsSecretAccessKey'] = ENV['AWS_SECRET_KEY']
    opts['pig.events.logformat'] = PIG_LOG_FORMAT
    opts['pig.logfile'] = local_log_dir + "/local-pig.log"
    opts['pig.udf.scripting.log.dir'] = local_udf_log_dir
    opts['python.verbose'] = 'error'
    opts['jython.output'] = true
    opts['python.home'] = jython_directory
    opts['python.path'] = "#{local_install_directory}/../controlscripts/lib:#{local_install_directory}/../vendor/controlscripts/lib"
    opts['python.cachedir'] = jython_cache_directory
    if osx? then
      opts['java.security.krb5.realm'] = 'OX.AC.UK'
      opts['java.security.krb5.kdc'] = 'kdc0.ox.ac.uk:kdc1.ox.ac.uk'
      opts['java.security.krb5.conf'] = '/dev/null'
    else
      opts['java.security.krb5.realm'] = ''
      opts['java.security.krb5.kdc'] = ''
    end
    return opts
  end

  # Given a set of user specified pig parameters, combine with the
  # automatic mortar parameters and write out to a tempfile, returning
  # it's path so it may be referenced later in the process
  def make_pig_param_file(pig_parameters)
    mortar_pig_params = automatic_parameters()
    all_parameters = mortar_pig_params.concat(pig_parameters)
    param_file = Tempfile.new("mortar-pig-parameters")
    all_parameters.each { |p|
      param_file.write("#{p['name']}=#{p['value']}\n")
    }
    param_file.close(false)

    # Keep track a reference the tempfile object so that the
    # garbage collector does not automatically delete the file
    # out from under us
    @temp_file_objects.push(param_file)

    param_file.path
  end

  def automatic_pig_parameters
    warn "[DEPRECATION] Please call automatic_parameters instead"
    automatic_parameters
  end
  
end

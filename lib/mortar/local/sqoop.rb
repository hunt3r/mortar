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

class Mortar::Local::Sqoop
  include Mortar::Local::InstallUtil

  def install_or_update
    @command = "#{local_install_directory}/python/bin/python"
    if should_do_install?
      action "Installing sqoop to #{local_install_directory_name}" do
        do_install
      end
    elsif should_do_update?
      action "Updating to latest sqoop in #{local_install_directory_name}" do
        do_install
      end
    end
    true
  end

  def sqoop_url
    full_host  = (host =~ /^http/) ? host : "https://api.#{host}"
    default_url = full_host + "/" + "resource/sqoop"
    return ENV.fetch('SQOOP_DISTRO_URL', default_url)
  end

  def should_do_install?
    return (not (File.exists?(sqoop_directory)))
  end

  def should_do_update?
    return is_newer_version('sqoop', sqoop_url)
  end

  def sqoop_directory
    return "#{local_install_directory}/sqoop"
  end

  def sqoop_dir_in_tgz
    "sqoop-1.4.4-mortar"
  end

  def do_install
    local_tgz = File.join(local_install_directory, "sqoop-1.4.4-mortar.tar.gz")
    if File.exists?(local_tgz)
      FileUtils.rm(local_tgz)
    end
    download_file(sqoop_url, local_tgz)

    if File.exists?(sqoop_directory)
      FileUtils.rm_rf(sqoop_directory)
    end

    extract_tgz(local_tgz, local_install_directory)

    FileUtils.mv(File.join(local_install_directory, sqoop_dir_in_tgz), sqoop_directory)

    # This has been seening coming out of the tgz w/o +x so we do
    # here to be sure it has the necessary permissions
    FileUtils.chmod(0755, "#{sqoop_directory}/bin/sqoop")
    FileUtils.chmod(0755, "#{sqoop_directory}/hadoop/bin/hadoop")

    File.delete(local_tgz)
    note_install("sqoop")
  end

  def sqoop_command_script_template_path
    File.expand_path("../../templates/script/sqoop.sh", __FILE__)
  end

  def hadoop_home
    "#{sqoop_directory}/hadoop"
  end

  def export(connstr, s3dest, options)
    template_params = sqoop_export_template_parameters(connstr, s3dest, options)
    return run_templated_script(sqoop_command_script_template_path, template_params)
  end

  def sqoop_export_template_parameters(connstr, s3dest, options)
    pig = Mortar::Local::Pig.new()
    parameters = {
      "sqoop_dir" => sqoop_directory,
      "jdb_conn_string" => connstr,
      "destination" => s3dest,
      "hadoop_home" => hadoop_home,
      "classpath" => pig.template_params_classpath,
      "postgres_jar" => "#{pig.lib_directory}/lib-cluster/postgresql.jar",
      "jdbc_conn" => connstr,
      "s3dest" => s3dest,
      "project_root" => project_root,
      "sqoop_opts" => sqoop_java_options
    }
    parameters["dbtable"] = options[:dbtable] if options[:dbtable]
    parameters["sqlquery"] = options[:sqlquery] if options[:sqlquery]
    parameters["inc_column"] = options[:inc_column] if options[:inc_column]
    parameters["inc_value"] = options[:inc_value] if options[:inc_value]
    if options[:inc_value] and 0 == options[:inc_value].to_i
      parameters[:inc_mode] = "lastmodified"
    elsif options[:inc_value]
      parameters[:inc_mode] = "append"
    end
    parameters["dbuser"] = options[:username] if options[:username]
    parameters["dbpass"] = options[:password] if options[:password]
    parameters["jdbcdriver"] = options[:jdbcdriver] if options[:jdbcdriver]
    parameters["driverjar"] = options[:driverjar] if options[:driverjar]
    parameters["direct_import"] = true if options[:direct]
    return parameters
  end

  def sqoop_java_options
    opts = {}
    opts['fs.s3n.awsAccessKeyId'] = ENV['AWS_ACCESS_KEY']
    opts['fs.s3n.awsSecretAccessKey'] = ENV['AWS_SECRET_KEY']
    opts['fs.s3.awsAccessKeyId'] = ENV['AWS_ACCESS_KEY']
    opts['fs.s3.awsSecretAccessKey'] = ENV['AWS_SECRET_KEY']
    return opts
  end

  # So this part kind of sucks.  In order to partition a query across multiple map
  # reduce tasks sqoop does a query to to find the range of identifiying values,
  # divides this range across the number of tasks to be executed and then modifies
  # the query for each m/r task. To do this Sqoop needs to know at what point in the
  # query that it should place its portion of the where clause. This is done via the
  # $CONDITIONS marker. So that's well and good when you're running sqoop on a cluster
  # but our users will be running on their own machine and don't know or care for this
  # parrallel queries stuff.  So to make their lives easier we make a best effort to
  # add the clause for them in a safe way.
  def prep_query(original_query)
    if original_query.include? "$CONDITIONS"
      return original_query
    elsif original_query.downcase.include? "where"
      idxwhere = original_query.downcase.index("where")
      select_where = original_query[0..idxwhere+"where".length-1]
      clause = original_query[idxwhere+"where".length+1..original_query.length]
      return "#{select_where} (#{clause}) AND \$CONDITIONS"
    else
      return "#{original_query} WHERE \$CONDITIONS"
    end
  end

end

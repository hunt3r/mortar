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

require 'zlib'
require 'excon'
require 'time'
require 'rbconfig'
require 'rubygems/package'

require 'mortar/helpers'

module Mortar
  module Local
    module InstallUtil

      include Mortar::Helpers

      def local_install_directory_name
        ".mortar-local"
      end

      def project_root
        # note: assumes that CWD is the project root, is
        # this a safe assumption?
        Dir.getwd
      end

      def local_install_directory
        ENV.fetch('MORTAR_LOCAL_DIR', File.join(project_root, local_install_directory_name))
      end

      def local_log_dir
        project_root + "/logs"
      end

      def local_udf_log_dir
        local_log_dir + "/udf"
      end

      def local_project_gitignore
        project_root + "/.gitignore"
      end

      def jython_directory
        local_install_directory + "/jython"
      end

      def jython_cache_directory
        jython_directory + "/cachedir"
      end

      def gitignore_template_path
        File.expand_path("../../templates/project/gitignore", __FILE__)
      end

      def ensure_mortar_local_directory(relative_dir)
        FileUtils.mkdir_p(File.join(local_install_directory, relative_dir))
      end

      # Drops a marker file for an installed package, used
      # to help determine if updates should be performed
      def note_install(subdirectory)
        install_file = install_file_for(subdirectory)
        File.open(install_file, "w") do |install_file|
          # Write out the current epoch so we know when this
          # dependency was installed
          install_file.write("#{Time.now.to_i}\n")
        end
      end

      def install_date(subsection)
        install_file = install_file_for(subsection)
        if File.exists?(install_file)
          File.open(install_file, "r") do |f|
            file_contents = f.read()
            file_contents.strip.to_i
          end
        end
      end

      def install_file_for(subdirectory)
        File.join(local_install_directory, subdirectory, "install-date.txt")
      end

      # Given a path to a foo.tgz or foo.tar.gz file, extracts its
      # contents to the specified output directory
      def extract_tgz(tgz_path, dest_dir)
        FileUtils.mkdir_p(dest_dir)
        Gem::Package::TarReader.new(Zlib::GzipReader.open(tgz_path)).each do |entry|
          entry_path = File.join(dest_dir, entry.full_name)
          if entry.directory?
            FileUtils.mkdir_p(entry_path)
          elsif entry.file?
            File.open(entry_path, "wb") do |entry_file|
              entry_file.write(entry.read)
            end
          end
        end
      end

      # Downloads the file at a specified url into the supplied directory
      def download_file(url, dest_file_path, command=nil)
        response = get_resource(url, command)
        
        File.open(dest_file_path, "wb") do |dest_file|
          dest_file.write(response.body)
        end
      
      end

      # Perform a get request to a url and follow redirects if necessary.
      def get_resource(url, command=nil)
        make_call(url, 'get', 0, 0, command)
      end

      # Perform a head request to a url and follow redirects if necessary.
      def head_resource(url, command=nil)
        make_call(url, 'head', 0, 0, command)
      end

      # Make a request to a mortar resource url.  Check response for a 
      # redirect and if necessary call the new url.  Excon doesn't currently 
      # support automatically following redirects.  Adds parameter that
      # checks an environment variable to identify the test making this call
      # (if being run by a test).
      def make_call(url, call_func, redirect_times=0, errors=0, command=nil)
        if redirect_times >= 5
          raise RuntimeError, "Too many redirects.  Last url: #{url}"
        end

        if errors >= 5
          raise RuntimeError, "Server Error at #{url}"
        end

        
        query = {}
        if test_name
          query[:test_name] = test_name
        end
        if command
          query[:command] = command
          if Mortar::Auth.has_credentials
            query[:user] = Mortar::Auth.user
          end
        end

        headers = {'User-Agent' => Mortar::USER_AGENT}
        if call_func == 'head'
          response = Excon.head( url, 
                                :headers => headers,
                                :query => query
                               )
        elsif call_func == 'get'
          response = Excon.get( url, 
                                :headers => headers,
                                :query => query
                              )
        else
          raise RuntimeError, "Unknown call type: #{call_func}"
        end

        case response.status
        when 300..303 then 
          make_call(response.headers['Location'], call_func, redirect_times+1, errors)
        when 500..599 then
          sleep(make_call_sleep_seconds)
          make_call(url, call_func, redirect_times, errors+1)
        else
          response
        end
      end

      def make_call_sleep_seconds
        2
      end

      def osx?
        os_platform_name = RbConfig::CONFIG['target_os']
        return os_platform_name.start_with?('darwin')
      end

      def http_date_to_epoch(date_str)
        return Time.httpdate(date_str).to_i
      end

      def url_date(url, command=nil)
        result = head_resource(url, command)
        last_modified = result.get_header('Last-Modified')
        if last_modified
          http_date_to_epoch(last_modified)
        else
          nil
        end
      end

      # Given a subdirectory where we have installed some software
      # and a url to the tgz file it's sourced from, check if the
      # remote version is newer than the installed version
      def is_newer_version(subdir, url, command=nil)
        existing_install_date = install_date(subdir)
        if not existing_install_date then
          # There is no existing install
          return true
        end
        remote_archive_date = url_date(url, command)
        if not remote_archive_date
          return false
        end
        return existing_install_date < remote_archive_date
      end

      def run_templated_script(template, template_params)
        # Insert standard template variables
        template_params['project_home'] = File.expand_path("..", local_install_directory)
        template_params['local_install_dir'] = local_install_directory

        unset_hadoop_env_vars
        reset_local_logs
        # Generate the script for running the command, then
        # write it to a temp script which will be exectued
        script_text = render_script_template(template, template_params)
        script = Tempfile.new("mortar-")
        script.write(script_text)
        script.close(false)
        FileUtils.chmod(0755, script.path)
        system(script.path)
        script.unlink
        return (0 == $?.to_i)
      end

      def render_script_template(template, template_params)
        erb = ERB.new(File.read(template), 0, "%<>")
        erb.result(BindingClazz.new(template_params).get_binding)
      end

      # so Pig doesn't try to load the wrong hadoop jar/configuration
      # this doesn't mess up the env vars in the terminal, just this process (ruby)
      def unset_hadoop_env_vars
        ENV['HADOOP_HOME'] = ''
        ENV['HADOOP_CONF_DIR'] = ''
      end

      def reset_local_logs
        if File.directory? local_log_dir
          FileUtils.rm_rf local_log_dir
        end
        Dir.mkdir local_log_dir
        Dir.mkdir local_udf_log_dir
      end


      # Allows us to use a hash for template variables
      class BindingClazz
        def initialize(attrs)
          attrs.each{ |k, v|
        # set an instance variable with the key name so the binding will find it in scope
            self.instance_variable_set("@#{k}".to_sym, v)
          }
        end
        def get_binding()
          binding
        end
      end

    end
  end
end

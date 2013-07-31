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
        File.join(project_root, local_install_directory_name)
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
      def download_file(url, dest_file_path)
        response = get_resource(url)
        
        File.open(dest_file_path, "wb") do |dest_file|
          dest_file.write(response.body)
        end
      
      end

      # Perform a get request to a url and follow redirects if necessary.
      def get_resource(url)
        make_call(url, 'get')
      end

      # Perform a head request to a url and follow redirects if necessary.
      def head_resource(url)
        make_call(url, 'head')
      end

      # Make a request to a mortar resource url.  Check response for a 
      # redirect and if necessary call the new url.  Excon doesn't currently 
      # support automatically following redirects.  Adds parameter that
      # checks an environment variable to identify the test making this call
      # (if being run by a test).
      def make_call(url, call_func, redirect_times=0, errors=0)
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

      def url_date(url)
        result = head_resource(url)
        http_date_to_epoch(result.get_header('Last-Modified'))
      end

      # Given a subdirectory where we have installed some software
      # and a url to the tgz file it's sourced from, check if the
      # remote version is newer than the installed version
      def is_newer_version(subdir, url)
        existing_install_date = install_date(subdir)
        if not existing_install_date then
          # There is no existing install
          return true
        end
        remote_archive_date = url_date(url)
        return existing_install_date < remote_archive_date
      end

    end
  end
end

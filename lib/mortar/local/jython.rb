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

class Mortar::Local::Jython
  include Mortar::Local::InstallUtil

  JYTHON_VERSION = '2.5.2'
  JYTHON_JAR_NAME = 'jython_installer-' + JYTHON_VERSION + '.jar'
  JYTHON_JAR_DEFAULT_URL_PATH = "resource/jython"

  def install_or_update
    if should_install
      action("Installing jython to #{local_install_directory_name}") do
        install
      end
    elsif should_update
      action("Updating jython in #{local_install_directory_name}") do
        update
      end
    end
  end

  def should_install
    not File.exists?(jython_directory)
  end

  def install
    jython_file = File.join(local_install_directory, JYTHON_JAR_NAME)
    unless File.exists?(jython_file)
        download_file(jython_jar_url, jython_file)
    end

    `$JAVA_HOME/bin/java -jar #{local_install_directory + '/' + JYTHON_JAR_NAME} -s -d #{jython_directory}`
    FileUtils.mkdir_p jython_cache_directory
    FileUtils.chmod_R 0777, jython_cache_directory

    FileUtils.rm(jython_file)
    note_install('jython')
  end

  def should_update
    return is_newer_version('jython', jython_jar_url)
  end

  def update
    FileUtils.rm_r(jython_directory)
    install
  end

  def jython_jar_url
    default_url = host + "/" + JYTHON_JAR_DEFAULT_URL_PATH
    ENV.fetch('JYTHON_JAR_URL', default_url)
  end
end
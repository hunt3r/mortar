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

  SQOOP_URL = "http://apache.mirror.quintex.com/sqoop/1.4.4/sqoop-1.4.4.bin__hadoop-1.0.0.tar.gz"

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
    return ENV.fetch('SQOOP_DISTRO_URL', SQOOP_URL)
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
    File.basename(sqoop_url).split('.')[0..-3].join('.')
  end

  def do_install
    local_tgz = File.join(local_install_directory, File.basename(sqoop_url))
    if File.exists?(local_tgz)
      FileUtils.rm(local_tgz)
    end
    download_file(sqoop_url, local_tgz)

    if File.exists?(sqoop_directory)
      FileUtils.rm_rf(sqoop_directory)
    end

    extract_tgz(local_tgz, local_install_directory)

    FileUtils.mv(File.join(local_install_directory, sqoop_dir_in_tgz), sqoop_directory)

    File.delete(local_tgz)
    note_install("sqoop")
  end



end

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
# Portions of this code from heroku (https://github.com/heroku/heroku/) Copyright Heroku 2008 - 2012,
# used under an MIT license (https://github.com/heroku/heroku/blob/master/LICENSE).
#

require 'mortar/helpers'
require 'mortar/version'

module Mortar
  module Updater
    CONNECT_TIMEOUT = 5
    READ_TIMEOUT = 5

    def self.get_newest_version
      begin
        require "excon"
        gem_data = Mortar::Helpers.json_decode(Excon.get('http://rubygems.org/api/v1/gems/mortar.json', {:connect_timeout => CONNECT_TIMEOUT, :read_timeout => READ_TIMEOUT}).body)
        gem_data.default = "0.0.0"
        gem_data['version']
      rescue Exception => e
        '0.0.0'
      end
    end

    def self.compare_versions(first_version, second_version)
      first_version.split('.').map {|part| Integer(part) rescue part} <=> second_version.split('.').map {|part| Integer(part) rescue part}
    end

    def self.update_check
      local_version = Mortar::VERSION
      newest_version = self.get_newest_version

      if compare_versions(newest_version, local_version) > 0
        if File.directory? ('/opt/mortar')
          Mortar::Helpers.warning("There is a new version of the Mortar development framework available.  Please run 'mortar version:upgrade' to install the latest version.\n\n")
        else
          Mortar::Helpers.warning("There is a new version of the Mortar development framework available.  Please run 'gem install mortar' to install the latest version.\n\n")
        end
      end
    end
  end
end

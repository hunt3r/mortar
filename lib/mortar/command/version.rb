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


require "mortar/command/base"
require "mortar/version"
require "mortar/helpers"

# display version
#
class Mortar::Command::Version < Mortar::Command::Base
  include Mortar::Helpers
  # version
  #
  # show mortar client version
  #
  def index
    validate_arguments!

    display(Mortar::USER_AGENT)
  end

  # version:upgrade [OPTIONAL_VERSION_NUMBER]
  #
  # Upgrades mortar mortar gem using omnibus build.  Makes a curl request to upgrade current version. 
  # 
  # -v, --version   VERSION_NUMBER    # specify which version to upgrade to
  def upgrade
    # require to check if running on a mac, use running_on_a_mac? in Helper.rb  
    validate_arguments!
    if running_on_a_mac? 
      if installed_with_omnibus?
        version_number = ''
        if options[:version] 
          version_number = " -v " + options[:version]
        end
        shell_url = ENV.fetch("MORTAR_INSTALL", "http://install.mortardata.com")
        Kernel.system "curl -sL -o /tmp/install.sh #{shell_url} && sudo bash /tmp/install.sh#{version_number}"
      else
        error("mortar version:upgrade is only for installations not conducted with ruby gem.  Please upgrade by running 'gem install mortar'.")
      end
    else
      error("mortar version:upgrade is currently only supported for OSX.")
    end
  end

end

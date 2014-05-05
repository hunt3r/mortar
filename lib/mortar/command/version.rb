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
require "open3"

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

  # upgrade [OPTIONAL_VERSION_NUMBER]
  # version:upgrade [OPTIONAL_VERSION_NUMBER]
  #
  # Upgrade the Mortar development framework
  #
  # -v, --version   VERSION_NUMBER    # specify which version to upgrade to
  def upgrade
    validate_arguments!
      version_argument = ""
      if installed_with_omnibus?
        if options[:version] 
          version_argument = "MORTAR_VERSION=" + options[:version] +" "
        end
        shell_url = ENV.fetch("MORTAR_INSTALL", "http://install.mortardata.com")
        dir = "/opt/mortar/installer"
        begin
          cmd = "echo 'Upgrading will prompt for your sudo password.\n' && MORTAR_URL=\"#{shell_url}\" #{version_argument}bash -c \"$(curl -sSL #{shell_url})\""
          Kernel.system cmd
        ensure
        end
      else
        error("mortar upgrade is only for installations not conducted with ruby gem.  Please upgrade by running 'gem install mortar'.")
      end
  end

  alias_command "upgrade", "version:upgrade"

end

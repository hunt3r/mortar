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

# display version
#
class Mortar::Command::Version < Mortar::Command::Base

  # version
  #
  # show mortar client version
  #
  def index
    validate_arguments!

    display(Mortar::USER_AGENT)
  end

  # upgrade
  #
  # Upgrades mortar gem without ruby
  #
  def upgrade
    # TODO
    if options[:specify]
      version_number = shift_argument 
      if version_number == ' '
        version_number = ''
      end
      display(version_number)
    end

    Kernel.system "curl -L https://www.opscode.com/chef/install.sh | sudo bash" 
  end

end

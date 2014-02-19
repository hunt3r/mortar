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

require 'spec_helper'
require 'fakefs/spec_helpers'
require 'mortar/local/python'
require 'launchy'


module Mortar::Local
  describe Python do

    context("check_or_install") do

      it "checks for python system requirements if not osx" do
        python = Mortar::Local::Python.new
        mock(python).osx?.returns(true)
        mock(python).install_or_update_osx.returns(true)
        python.check_or_install
      end

      it "installs python on osx" do
        python = Mortar::Local::Python.new
        mock(python).osx?.returns(false)
        mock(python).check_system_python.returns(true)
        python.check_or_install
      end

    end

    context("install_or_update_osx") do

      it "does install if none present" do
        python = Mortar::Local::Python.new
        mock(python).should_do_python_install?.returns(true)
        mock(python).install_osx.returns(true)
        capture_stdout do
          python.install_or_update_osx
        end
      end

      it "does install if an update is available" do
        python = Mortar::Local::Python.new
        mock(python).should_do_python_install?.returns(false)
        mock(python).should_do_update?.returns(true)
        mock(python).install_osx.returns(true)
        capture_stdout do
          python.install_or_update_osx
        end
      end

    end

  end
end

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

    context "mortar python dependencies" do
      it "no install if not necessary" do
        python = Mortar::Local::Python.new
        stub(python).has_valid_virtualenv?.returns(true)
        stub(python).should_do_requirements_install.returns(false)
        mock(python).should_install_python_dependencies?.returns(false)
        stub(python).install_python_dependencies { raise "Shouldn't be called" }
        python.setup_project_python_environment
      end
      it "install if necessary" do
        python = Mortar::Local::Python.new
        stub(python).has_valid_virtualenv?.returns(true)
        stub(python).should_do_requirements_install.returns(false)
        mock(python).should_install_python_dependencies?.returns(true)
        mock(python).install_python_dependencies.returns(true)
        python.setup_project_python_environment
      end

      it "doesn't detect needing any update if all packages up to date" do
        python = Mortar::Local::Python.new
        stub(python).update_mortar_package?.returns(false)
        expect(python.should_install_python_dependencies?).to equal(false)
      end

      it "detects necessary install if any packages need any update" do
        python = Mortar::Local::Python.new
        stub(python).update_mortar_package?.returns(true)
        expect(python.should_install_python_dependencies?).to equal(true)
      end

      it "creates directory where install timestamps are stored" do
        python = Mortar::Local::Python.new
        stub(python).install_mortar_python_package.returns(true)
        FakeFS do
          FileUtils.mkdir_p "#{python.local_install_directory}/pythonenv"
          capture_stdout do
            python.install_python_dependencies
          end
          dir_to_be_created = "#{python.local_install_directory}/#{python.mortar_packages_dir}"
          expect(File.exists?(dir_to_be_created)).to be_true
        end
      end

      it "stops if installation failed" do
        python = Mortar::Local::Python.new
        stub(python).pip_install.returns(false)
        stub(python).note_install { raise "Shouldn't be called" }
        python.install_mortar_python_package "pip"
      end

      it "creates directory to store package install date" do
        python = Mortar::Local::Python.new
        stub(python).pip_install.returns(true)
        mock(python).note_install(python.mortar_package_dir("pip"))
        FakeFS do
          FileUtils.mkdir_p "#{python.local_install_directory}/#{python.mortar_packages_dir}"
          python.install_mortar_python_package "pip"
          dir_to_be_created = "#{python.local_install_directory}/#{python.mortar_packages_dir}/pip"
          expect(File.exists?(dir_to_be_created)).to be_true
        end
      end

    end

  end
end

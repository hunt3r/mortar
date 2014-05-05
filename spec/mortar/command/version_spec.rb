#
# Copyright 2014 Mortar Data Inc.
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
require "spec_helper"
require "mortar/command/version"

module Mortar::Command
  describe Version do

    before(:each) do
      stub_core
      
    end
    
    base_url  = "http://install.mortardata.com"
    base_version = ""
    tmp_dir_dumm = "/opt/mortar/installer"
    curl_command = "echo 'Upgrading will prompt for your sudo password.\n' && MORTAR_URL=\"#{base_url}\" bash -c \"$(curl -sSL #{base_url})\""

    context("version in prod") do
      mortar_install_env = ENV['MORTAR_INSTALL']
      before(:each) do
        ENV['MORTAR_INSTALL'] = nil  
      end

      after(:all) do
        ENV['MORTAR_INSTALL'] = mortar_install_env
      end
      it "makes a curl request to download default version" do
        mock(Kernel).system (curl_command)
        any_instance_of(Mortar::Command::Version) do |base|
          mock(base).installed_with_omnibus? {true}
          execute("version:upgrade");
        end
      end
      
      it "makes curl request for different versions when requested" do
        mortar_version = "0.15.1"
        curl_command_with_version = "echo 'Upgrading will prompt for your sudo password.\n' && MORTAR_URL=\"#{base_url}\" MORTAR_VERSION=#{mortar_version} bash -c \"$(curl -sSL #{base_url})\""
        mock(Kernel).system( curl_command_with_version)
        mock(Kernel).system( curl_command_with_version)
        any_instance_of(Mortar::Command::Version) do |base|
          mock(base).installed_with_omnibus? {true}
          mock(base).installed_with_omnibus? {true}
          execute( "upgrade -v #{mortar_version}");
          execute( "version:upgrade --version #{mortar_version}");
        end
      end
      
    end

    context("version dev") do
      dev_url = "install.m0rtardata.com"
      base_version = "0.15.1"
      dev_curl = "echo 'Upgrading will prompt for your sudo password.\n' && MORTAR_URL=\"#{dev_url}\" bash -c \"$(curl -sSL #{dev_url})\""
      before(:each) do
        ENV['MORTAR_INSTALL'] = dev_url
      end

      it "makes a curl request to download default version on dev" do
        mock(Kernel).system(dev_curl)
        
        any_instance_of(Mortar::Command::Version) do |base|
          mock(base).installed_with_omnibus? {true}
          execute("upgrade");
        end
      end
    end

    context("not installed via omnibus") do
      it "throws an error when running on an install not done via omnibus" do
        any_instance_of(Mortar::Command::Version) do |base|
          mock(base).installed_with_omnibus? {false}
          stderr, stdout = execute("version:upgrade");
          stderr.should == <<-STDERR
 !    mortar upgrade is only for installations not conducted with ruby gem.  Please upgrade by running 'gem install mortar'.
STDERR
        end
      end
    end
  end
end


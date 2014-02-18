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
    base_version = "1.0"
    tmp_dir_dumm = "/opt/mortar/installer"
    curl_command = "sudo curl -sS -L -o #{tmp_dir_dumm}/install.sh #{base_url} && sudo bash #{tmp_dir_dumm}/install.sh"

    context("version in prod") do
      mortar_install_env = ENV['MORTAR_INSTALL']
      before(:each) do
        ENV['MORTAR_INSTALL'] = nil  
      end

      after(:all) do
        ENV['MORTAR_INSTALL'] = mortar_install_env
      end
      it "makes a curl request to download default version" do
        mock(FileUtils).remove_entry_secure(tmp_dir_dumm)
        mock(Kernel).system (curl_command)
        any_instance_of(Mortar::Command::Version) do |base|
          mock(base).installed_with_omnibus? {true}
          execute("version:upgrade");
        end
      end
      
      it "makes curl request for different versions when requested" do
        mortar_version = "1.0"
        curl_command_with_version = curl_command +  " -v " + mortar_version
        mock(FileUtils).remove_entry_secure(tmp_dir_dumm)
        mock(FileUtils).remove_entry_secure(tmp_dir_dumm)
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
      dev_url = "dev_url.com"
      dev_curl =  "sudo curl -sS -L -o #{tmp_dir_dumm}/install.sh #{dev_url} && sudo bash #{tmp_dir_dumm}/install.sh" 
      before(:each) do
        ENV['MORTAR_INSTALL'] = dev_url
      end

      it "makes a curl request to download default version on dev" do
        mock(Kernel).system(dev_curl)
        
        mock(FileUtils).remove_entry_secure(tmp_dir_dumm)
        any_instance_of(Mortar::Command::Version) do |base|
          mock(base).installed_with_omnibus? {true}

          execute("upgrade");
        end
      end
    end

    context("version not Mac OSX") do
      it "throws error when not on mac" do
        any_instance_of(Mortar::Command::Version) do |base|
          mock(base).running_on_a_mac? {false} 
          stderr, stdout = execute("version:upgrade");
          stderr.should == <<-STDERR
 !    mortar upgrade is currently only supported for OSX.
STDERR
        end
      end

      it "throws an error when running on a mac but installed with ruby gem" do
        any_instance_of(Mortar::Command::Version) do |base|
          mock(base).running_on_a_mac? {true}
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


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
require "fakefs/spec_helpers"
require "mortar/command/version"
require "launchy"


module Mortar::Command
  describe Version do
    before(:each) do
      stub_core
    end
    
    base_url  = "https://www.opscode.com/chef/install.sh"
    base_version = "1.0"
    curl_command = "curl -L #{base_url} | sudo bash"

    context("version") do
      it "makes a curl request to download default version " do
        mock(Kernel).system ( curl_command )
        
        execute("version:upgrade");
      end
      
     # it "makes curl request for different versions when requested" do
     #   mortar_version = "1.0"
     #   curl_command_with_version = "curl -L #{base_url} | sudo bash #{mortar_version}"
     #   mock(Kernel).system( curl_command_with_version)
     #   execute( "version:upgrade --specify #{mortar_version}");
     # end
      
    end
  end
    
end

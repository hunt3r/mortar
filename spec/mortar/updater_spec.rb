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

require "spec_helper"
require "mortar/updater"
require "excon"

module Mortar
  describe Updater do
    include Mortar::Updater
    
    context "compare versions" do
      it "same versions" do
        Updater.compare_versions('1.0.0','1.0.0').should == 0
      end

      it "higher version" do
        Updater.compare_versions('1.0.0','0.0.0').should > 0
        Updater.compare_versions('0.1.0','0.0.0').should > 0
        Updater.compare_versions('0.0.1','0.0.0').should > 0
      end

      it "lower version" do
        Updater.compare_versions('1.0.0','2.0.0').should < 0
        Updater.compare_versions('0.1.0','0.2.0').should < 0
        Updater.compare_versions('0.0.1','0.0.2').should < 0
      end
    end

    context "get ruby version" do
      it "makes gem call" do
        Excon.stub({:method => :get, :path => "/api/v1/gems/mortar.json", :connect_timeout => Mortar::Updater::CONNECT_TIMEOUT, :read_timeout => Mortar::Updater::READ_TIMEOUT}) do
          {:body => Mortar::API::OkJson.encode({"version" => "1.0.0"}), :status => 200}
        end
        Updater.get_newest_version.should == "1.0.0"   
      end

      it "has no version field" do
        Excon.stub({:method => :get, :path => "/api/v1/gems/mortar.json", :connect_timeout => Mortar::Updater::CONNECT_TIMEOUT, :read_timeout => Mortar::Updater::READ_TIMEOUT}) do
          {:body => Mortar::API::OkJson.encode({"no_version" => "none"}), :status => 200}
        end
        Updater.get_newest_version.should == "0.0.0"
      end

      it "has an exception" do
        Excon.stub({:method => :get, :path => "/api/v1/gems/mortar.json", :connect_timeout => Mortar::Updater::CONNECT_TIMEOUT, :read_timeout => Mortar::Updater::READ_TIMEOUT}) do
          raise Exception
        end
        Updater.get_newest_version.should == "0.0.0"
      end
    end

    context "update check" do
      it "displays no message when we have a current version" do
        Excon.stub({:method => :get, :path => "/api/v1/gems/mortar.json", :connect_timeout => Mortar::Updater::CONNECT_TIMEOUT, :read_timeout => Mortar::Updater::READ_TIMEOUT}) do
          {:body => Mortar::API::OkJson.encode({"version" => "1.0.0"}), :status => 200}
        end
        capture_stderr do
          Mortar::VERSION = "1.0.0"
        end
        capture_stdout do
          Updater.update_check
        end.should == ""
      end

      it "displays message when we have an outdated version" do
        Excon.stub({:method => :get, :path => "/api/v1/gems/mortar.json", :connect_timeout => Mortar::Updater::CONNECT_TIMEOUT, :read_timeout => Mortar::Updater::READ_TIMEOUT}) do
          {:body => Mortar::API::OkJson.encode({"version" => "2.0.0"}), :status => 200}
        end
        capture_stderr do
          Mortar::VERSION = "1.0.0"
        end
        capture_stdout do
          stub(Updater).installed_with_omnibus?{false}
          stub(Updater).running_on_a_mac?{false}
          Updater.update_check
        end.should == "WARNING: There is a new version of the Mortar development framework available.  Please run 'gem install mortar' to install the latest version.\n\n"
        capture_stdout do
          mock(Updater).installed_with_omnibus?{true}
          mock(Updater).running_on_a_mac?{true}
          Updater.update_check
        end.should == "WARNING: There is a new version of the Mortar development framework available.  Please run 'mortar upgrade' to install the latest version.\n\n"

      end
    end
  end
end

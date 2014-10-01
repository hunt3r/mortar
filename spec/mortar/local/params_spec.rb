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

require 'spec_helper'
require 'mortar/local/params'

module Mortar::Local
  describe Params do
    
    class ParamsClass
      # this is usually mixed in from InstallUtil
      def project_root
        "/tmp/myproject"
      end
    end

    before(:each) do
      @params = ParamsClass.new
      @params.extend(Mortar::Local::Params)
    end

    context "automatic_parameters" do

      def get_param_value(params, name)
        selected = params.select{|p| p["name"] == name}
        selected.length == 1 ? selected[0]["value"] : nil
      end

      it "returns params for a logged-in user" do
        ENV['AWS_ACCESS_KEY'] = "abc"
        ENV['AWS_SECRET_KEY'] = "012"

        # setup fake auth
        stub_core
        params = @params.automatic_parameters()
        get_param_value(params, "MORTAR_EMAIL").should == "email@example.com"
        get_param_value(params, "MORTAR_API_KEY").should == "pass"
        get_param_value(params, "MORTAR_EMAIL_S3_ESCAPED").should == "email-example-com"
        get_param_value(params, "MORTAR_PROJECT_ROOT").should == "/tmp/myproject"
        get_param_value(params, "AWS_ACCESS_KEY").should == "abc"
        get_param_value(params, "AWS_ACCESS_KEY_ID").should == "abc"
        get_param_value(params, "aws_access_key_id").should == "abc"
        get_param_value(params, "AWS_SECRET_KEY").should == "012"
        get_param_value(params, "AWS_SECRET_ACCESS_KEY").should == "012"
        get_param_value(params, "aws_secret_access_key").should == "012"
      end

      it "returns params for a non-logged-in user" do
        ENV['AWS_ACCESS_KEY'] = "abc"
        ENV['AWS_SECRET_KEY'] = "012"

        params = @params.automatic_parameters()
        get_param_value(params, "MORTAR_EMAIL").should == "notloggedin@user.org"
        get_param_value(params, "MORTAR_API_KEY").should == "notloggedin"
        get_param_value(params, "MORTAR_EMAIL_S3_ESCAPED").should == "notloggedin-user-org"
        get_param_value(params, "MORTAR_PROJECT_ROOT").should == "/tmp/myproject"
        get_param_value(params, "AWS_ACCESS_KEY").should == "abc"
        get_param_value(params, "AWS_ACCESS_KEY_ID").should == "abc"
        get_param_value(params, "aws_access_key_id").should == "abc"
        get_param_value(params, "AWS_SECRET_KEY").should == "012"
        get_param_value(params, "AWS_SECRET_ACCESS_KEY").should == "012"
        get_param_value(params, "aws_secret_access_key").should == "012"
      end
    end

    context "merge_parameters" do
      it "merges parameters" do
        @params.merge_parameters([], []).should == []
        @params.merge_parameters(
          [{"name" => "foo", "value" => "bar"}], 
          []).should == 
          [{"name" => "foo", "value" => "bar"}]
        @params.merge_parameters(
          [], 
          [{"name" => "foo", "value" => "bar"}]).should == 
          [{"name" => "foo", "value" => "bar"}]
        @params.merge_parameters(
          [{"name" => "foo", "value" => "bar"}], 
          [{"name" => "foo", "value" => "fish"}]).should == 
          [{"name" => "foo", "value" => "fish"}]
        @params.merge_parameters(
          [{"name" => "tree", "value" => "bar"}], 
          [{"name" => "foo", "value" => "fish"}]).should == 
          [{"name" => "foo", "value" => "fish"}, {"name" => "tree", "value" => "bar"}]
      end
    end
  end
end

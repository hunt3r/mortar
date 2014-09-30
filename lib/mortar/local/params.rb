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

require 'set'
require 'mortar/auth'

module Mortar
  module Local
    module Params

      # Job parameters that are supplied automatically from Mortar when
      # running on the server side.  We duplicate these here.
      def automatic_parameters()
        params = {}

        params['MORTAR_EMAIL']   = Mortar::Auth.user(true)
        params['MORTAR_API_KEY'] = Mortar::Auth.password(true)
        
        if ENV['MORTAR_EMAIL_S3_ESCAPED']
          params['MORTAR_EMAIL_S3_ESCAPED'] = ENV['MORTAR_EMAIL_S3_ESCAPED']
        else
          params['MORTAR_EMAIL_S3_ESCAPED'] = Mortar::Auth.user_s3_safe(true)
        end

        if ENV['MORTAR_PROJECT_ROOT']
          params['MORTAR_PROJECT_ROOT'] = ENV['MORTAR_PROJECT_ROOT']
        else
          params['MORTAR_PROJECT_ROOT'] = project_root
          ENV['MORTAR_PROJECT_ROOT'] = params['MORTAR_PROJECT_ROOT']
        end

        params['AWS_ACCESS_KEY']    = ENV['AWS_ACCESS_KEY']
        params['AWS_ACCESS_KEY_ID'] = ENV['AWS_ACCESS_KEY']
        params['aws_access_key_id'] = ENV['AWS_ACCESS_KEY']

        params['AWS_SECRET_KEY'] = ENV['AWS_SECRET_KEY']
        params['AWS_SECRET_ACCESS_KEY'] = ENV['AWS_SECRET_KEY']
        params['aws_secret_access_key'] = ENV['AWS_SECRET_KEY']
        
        param_list = params.map do |k,v|
          {"name" => k, "value" => v}
        end
      end

      # Merge two lists of parameters, removing dupes.
      # Parameters in param_list_1 override those in param_list_2
      def merge_parameters(param_list_0, param_list_1)
        param_list_1_keys = Set.new(param_list_1.map{|item| item["name"]})
        merged = param_list_1.clone
        merged.concat(param_list_0.select{|item| (! param_list_1_keys.include? item["name"]) })
        merged
      end
    end
  end
end

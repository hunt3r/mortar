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
# Portions of this code from heroku (https://github.com/heroku/heroku/) Copyright Heroku 2008 - 2014,
# used under an MIT license (https://github.com/heroku/heroku/blob/master/LICENSE).
#
require 'mortar/local/controller'
require "mortar/command/base"
require "mortar/helpers"
require 'aws-sdk'
require 'uri'
require 'pathname'


module Mortar
  module S3
    class S3
      include Helpers

      # gets aws::s3 object
      def get_s3
        ctrl = Mortar::Local::Controller.new
        ctrl.require_aws_keys
        return AWS::S3.new(
          :access_key_id => ENV['AWS_ACCESS_KEY'],
          :secret_access_key => ENV['AWS_SECRET_KEY'])
      end

      # returns bucket and key from s3 path
      def get_bucket_and_key(s3_path)
        uri = ''
        begin
          uri = URI.parse(s3_path)
        rescue URI::InvalidURIError => msg
          error("#{msg}.\nIt is strongly suggested that your bucket name does not contain an underscore character.\nPlease see http://blog.mortardata.com/post/58920122308/s3-hadoop-performance at tip #4.") 
        end


        unless uri != '' && is_valid_s3_path(uri)
          error("Requested S3 path, #{s3_path}, is invalid. Please ensure that your S3 path begins with 's3://'.  Example: s3://my-bucket/my-key.")
        end
        return uri.host,uri.path[1, uri.path.length]
      end


      # checks if string is a valid s3 path
      def is_valid_s3_path(uri)
        uri.scheme == 's3' && uri.host && !uri.path[1, uri.path.length].to_s.empty?
      end


      def remove_slash(str)
        if str[-1, 1] == "/"
          str = str[0, str.length-1]
        end
        return str
      end

      def get_file_name(key_str)
          if !key_str.rindex("/") 
            return key_str
          else
            return Pathname.new(key_str).basename.to_s
          end
      end

      def is_file(path, key)
        if is_not_folder(path,key)
          res = Pathname.new(path).basename.to_s
          if !is_hidden_file(res)
            return true 
          end
        end 
        return false 
      end

      def is_not_folder(path, key)
        suffix = ["/", "_$folder$"]
        # not a folder
        path[-1,1] != suffix[0]  && !path.index(suffix[1]) and !path[key.length+1, path.length].index("/")
        #path[-1,1] != suffix[0] && !path.index(suffix[1]) and Pathname.new(path).basename.to_s != '' 
      end

      def is_hidden_file(str)
        str[0,1] == "." || str[0,1] == "_"
      end

      def remove_file(file_path)
        if File.file?(file_path)
          FileUtils.remove(file_path)
        end
      end

      # checks s3 bucket to see if bucket and key exists for given aws keys
      def check_bucket(s3, bucket)
        s3.buckets[bucket].exists?
      end


      # gets s3 object, where each item is a file in bucket and key
      def get_s3_objects(s3, bucket, key)
        buck = s3.buckets[bucket]
        # removes slash at end if it exists
        key = remove_slash(key) 
        if buck.objects[key].exists?
          [buck.objects[key]]
        else
          valid_items = Array.new
          # TODO validate with Collect/Reject functional style 
          buck.objects.with_prefix(key).each do |obj|
            if is_file(obj.key, key) 
              valid_items.push(obj)
            end
          end
          return valid_items
        end
      end

      def write_s3_to_file(s3_object, file_name, write_mode)
        File.open(file_name, write_mode) do |file|
          s3_object.read do |chunk|
            file.write(chunk)
          end
        end
      end


      def download_s3(s3, bucket, key, output_path, concat = nil)
          s3_objects = get_s3_objects(s3, bucket,key)
          concat_file_name = "output"
          concat_target = "#{output_path}/#{concat_file_name}"
          if concat
            remove_file(concat_target)
          end
          if !s3_objects.empty?
            s3_objects.each do |s3_obj|
              key_str = s3_obj.key
              out_file = concat ? concat_file_name : get_file_name(key_str)
              output_target = "#{output_path}/#{out_file}"
              display "Writing s3://#{bucket}/#{key_str} to #{output_target}"
              write_s3_to_file(s3_obj, output_target, concat ? "a" : "w+")
            end
          else
            error("No contents were found at path s3://#{bucket}/#{key}.  Please specify again.")
          end
      end

      # Implementation of the download command
      def do_download(bucket, key, output_path, concat=nil)
        s3 = get_s3
        # check and messages for concatting file
        unless check_bucket(s3, bucket)
         error("Requested S3 bucket #{bucket} in path, s3://#{bucket}/#{key}, does not exist.")
        end
        # creates output directory
        unless File.directory?(output_path)
          FileUtils.mkdir_p(output_path)
        end
        download_s3(s3, bucket, key, output_path, concat)

        display "All done! "
      end

    end
  end
end

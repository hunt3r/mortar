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
require 'fakefs/spec_helpers'
require 'mortar/command/s3'
require 'aws-sdk'
require "mortar/s3"
require 's3_faker'

module Mortar::Command
  describe S3 do
    context "s3:getmerge" do
      good_bucket = "good-bucket"
      bad_bucket = "bad-bucket"
      key = "direc"
      s3_path = "s3://#{good_bucket}/#{key}"
      s3_path_bad = "s3://#{bad_bucket}/key"
      output_path = "out"
      concat_file = "#{output_path}/output"
      keys = [
          FakeObject.new("key1", true),
          FakeObject.new("direc/key2", true),
          FakeObject.new("direc/key3", true),
          FakeObject.new("direc/another_direc/key", true)
        ]
      before(:each) do
        ENV["AWS_ACCESS_KEY"] = "foo"
        ENV["AWS_SECRET_KEY"] = "bar"
        buckets = [
          {:bucket => good_bucket, :keys =>keys, :does_exist => true},
          {:bucket => bad_bucket, :keys=> [], :does_exist => false}]
        stub_s3(buckets, ENV["AWS_ACCESS_KEY"], ENV["AWS_SECRET_KEY"])

      end

      context "s3:get" do
        it "should specify an s3 bucket" do 
          stderr, stdout = execute("s3:get")
          stderr.should == <<-STDERR
 !    Usage: mortar s3:get S3_PATH OUTPUT_PATH
 !    Must specify S3_PATH and OUTPUT_PATH.
STDERR
        end

        it "should throw errors at invalid  s3_bucket and fetch urls" do
          stderr, stdout = execute("s3:get s3://#{bad_bucket} out")
          stderr.should eq(" !    Requested S3 path, s3://#{bad_bucket}, is invalid. Please ensure that your S3 path begins with 's3://'.  Example: s3://my-bucket/my-key.\n")
        end


        it "should throw errors at invalid  s3_bucket and fetch urls" do
          stderr, stdout = execute("s3:get #{s3_path_bad} out")
          stderr.should eq(" !    Requested S3 bucket #{bad_bucket} in path, #{s3_path_bad}, does not exist.\n")
        end

        it "should have no errors when ran" do
          any_instance_of(Mortar::S3::S3) do |s3|
            mock(s3).do_download(good_bucket, key, output_path, nil)
          end
          stderr, stdout = execute("s3:get #{s3_path} #{output_path}")
          stderr.should eq("")
        end
      end

      context "s3:getmerge" do
        it "should have aws-sdk keys properly set for aws-sdk functionality" do
          any_instance_of(Mortar::S3::S3) do |s3|
            mock(s3).do_download(good_bucket, key, output_path, true)
          end
          stderr, stdout = execute("s3:getmerge #{s3_path} #{output_path}")
          stderr.should eq("")
        end
      end
    end
  end
end



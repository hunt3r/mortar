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

require "mortar/command/base"
require "mortar/s3"

# Work with your data on Amazon S3
class Mortar::Command::S3 < Mortar::Command::Base

  # s3:get S3_PATH OUTPUT_PATH
  #
  # Download files from a path in S3 to your local computer.
  #
  #
  # Examples:
  #
  #     Download from your bucket with:
  #         $ mortar s3:get s3://mortar-example/out out/
  def get
    do_get("get")
  end

  # s3:getmerge S3_PATH OUTPUT_PATH
  #
  # Download and concatenate files from a path in S3 to your local computer. Merges together all of the hadoop output into one file called 'output' at specified OUTPUT_PATH
  #
  # Examples:
  #
  #     Download from your bucket with:
  #         $ mortar s3:getmerge s3://mortar-example/out out/
  def getmerge
    do_get("getmerge", true)
  end

  private 
  
  # get functionality
  def do_get(command, concat = nil)
    s3_path = shift_argument
    output_path = shift_argument
    unless s3_path and output_path
      error("Usage: mortar s3:#{command} S3_PATH OUTPUT_PATH\nMust specify S3_PATH and OUTPUT_PATH.")
    end
    s3 = Mortar::S3::S3.new
    bucket, key = s3.get_bucket_and_key(s3_path)
    s3.do_download(bucket, key, output_path, concat)
  end

end

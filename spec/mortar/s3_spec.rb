require 'spec_helper'
require 'mortar/s3'
require 's3_faker'

module Mortar
  describe S3 do
    before(:each) do
      @s3 = Mortar::S3::S3.new
    end
    context("download s3 commands") do
      keys = [
        FakeObject.new("key1", true),
        FakeObject.new("direc/key2", true),
        FakeObject.new("direc/key3", true),
        FakeObject.new("direc/.hidden_key4", true),
        FakeObject.new("direc/another_direc/key", true)
      ]

      before(:each) do
        ENV["AWS_ACCESS_KEY"] = "foo"
        ENV["AWS_SECRET_KEY"] = "bar"
        buckets = [
          {:bucket => "good_bucket", :keys =>keys, :does_exist => true},
          {:bucket => "bad_bucket", :keys=> [], :does_exist => false}]
        stub_s3(buckets, ENV["AWS_ACCESS_KEY"], ENV["AWS_SECRET_KEY"])

      end

      context("string functions") do
        it "should check if the valid path" do
          bucket, key = @s3.get_bucket_and_key('s3://bucket/key')
          bucket.should eq('bucket') 
          key.should eq('key') 
          bucket, key = @s3.get_bucket_and_key('s3://bucket/deeper/level/key')
          bucket.should eq('bucket') 
          key.should eq('deeper/level/key') 
        end

        it "should throw appropriate error if path is not valid" do
          bad_bucket = 'bad'
          previous_stderr, $stderr = $stderr, StringIO.new
          begin
            expect { @s3.get_bucket_and_key(bad_bucket) }.to raise_error(SystemExit)
            $stderr.string.should eq(" !    Requested S3 path, #{bad_bucket}, is invalid. Please ensure that your S3 path begins with 's3://'.  Example: s3://my-bucket/my-key.\n")
          ensure
            $stderr = previous_stderr
          end        
        end

        it "should throw error if bucket has underscore" do
          path = "s3://will_fail/key"
          previous_stderr, $stderr = $stderr, StringIO.new
          begin
            expect { @s3.get_bucket_and_key(path) }.to raise_error(SystemExit)
            $stderr.string.should eq(" !    the scheme s3 does not accept registry part: will_fail (or bad hostname?).\n !    It is strongly suggested that your bucket name does not contain an underscore character.\n !    Please see http://blog.mortardata.com/post/58920122308/s3-hadoop-performance at tip #4.\n")
          ensure
            $stderr = previous_stderr
          end
        end

        it "should remove / if at the end" do
          str = "with/"
          str = @s3.remove_slash(str)
          str.should eq("with")
        end
        it "should not remove / if not at the end" do
          str = "without"
          @s3.remove_slash(str)
          str.should eq("without")
        end

        it "should get just the file" do
          key = "folder"
          path = "folder/file"
          @s3.is_file(path, key).should eq(true)

        end

        it "should get nothing" do
          key = "folder"
          path = "folder/file_$folder$"
          @s3.is_file(path, key).should eq(false)
          path = "folder/folder/"
          @s3.is_file(path, key).should eq(false)
        end

      end


      context("s3 functions") do
        s3 = nil
        before (:each) do
          any_instance_of(Mortar::Local::Controller) do |ctrl|
            mock(ctrl).require_aws_keys
          end
          s3 = @s3.get_s3
        end

        it "should check if bucket and key exists" do
          bucket = "good_bucket"
          key = "key1"
          @s3.check_bucket(s3, bucket).should eq(true)


          bucket = "bad_bucket"
          key = "bad_key"
          @s3.check_bucket(s3, bucket).should eq(false)
        end

        it "should get s3_objects" do
          bucket = "good_bucket"
          key = "key1"
          result = @s3.get_s3_objects(s3, bucket, key)
          result.length.should eq(1)
          result[0].key.should eq(key)

          bucket = "good_bucket"
          key = "direc"
          result = @s3.get_s3_objects(s3, bucket, key)
          result.length.should eq(2)
        end

        it "should return emtpy list if s3_objects are empty" do
          bucket = "good_bucket"
          key = "dire"
          result = @s3.get_s3_objects(s3, bucket, key)
          result.length.should eq(0)
        end

        it "should check content that is written" do
          bucket = "good_bucket"
          key = "key1"
          mock(@s3).write_s3_to_file(keys[0], 'output/key1', 'w+')
          @s3.download_s3(s3, bucket, key, 'output')
        end

        it "should check all files are written" do
          bucket = "good_bucket"
          key = "direc"
          mock(@s3).write_s3_to_file(keys[1], 'output/key2', 'w+')
          mock(@s3).write_s3_to_file(keys[2], 'output/key3', 'w+')
          @s3.download_s3(s3, bucket, key, 'output')
        end

        it "should concat all files to one and delete out file when already exists" do
          bucket = "good_bucket"
          key = "direc"
          mock(File).file?("output/output"){true}
          mock(FileUtils).remove("output/output")
          mock(@s3).write_s3_to_file(keys[1], 'output/output', 'a')
          mock(@s3).write_s3_to_file(keys[2], 'output/output', 'a')
          @s3.download_s3(s3, bucket, key, 'output', true)
        end
      end
    end
  end
end

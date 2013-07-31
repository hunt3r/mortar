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

require 'spec_helper'
require 'fakefs/spec_helpers'
require 'mortar/local/installutil'
require 'launchy'

module Mortar::Local
  describe InstallUtil do
    include FakeFS::SpecHelpers

    class InstallUtilClass
    end

    before(:each) do
      @installutil = InstallUtilClass.new
      @installutil.extend(Mortar::Local::InstallUtil)
    end

    context("install_date") do

      it "nil if never installed" do
        expect(@installutil.install_date('foo')).to be_nil
      end

      it "contents of file if present, converted to int" do
        install_file_path = @installutil.install_file_for("foo")
        install_date = 123456
        FakeFS do
          FileUtils.mkdir_p(File.dirname(install_file_path))
          File.open(install_file_path, "w") do |file|
            file.puts(install_date.to_s)
          end
          expect(@installutil.install_date('foo')).to eq(install_date)
        end
      end

      it "works with file created by note-install" do
        install_file_path = @installutil.install_file_for("foo")
        install_date = 1234568
        stub(Time).now.returns(install_date)
        FakeFS do
          FileUtils.mkdir_p(File.dirname(install_file_path))
          @installutil.note_install('foo')
          expect(@installutil.install_date('foo')).to eq(install_date)
        end
      end

    end

    context("note-install") do

      it "creates a file in the directory with the current time" do
        install_file_path = @installutil.install_file_for("foo")
        current_date = 123456
        stub(Time).now.returns(current_date)
        FakeFS do
          FileUtils.mkdir_p(File.dirname(install_file_path))
          @installutil.note_install("foo")
          expect(File.exists?(install_file_path)).to be_true
        end
      end

    end

    context "is_newer_version" do

      it "is if remote file is newer" do
        stub(@installutil).install_date.returns(1)
        stub(@installutil).url_date.returns(2)
        expect(@installutil.is_newer_version('foo', 'http://bar')).to be_true
      end

      it "is not if remote file is older" do
        stub(@installutil).install_date.returns(2)
        stub(@installutil).url_date.returns(1)
        expect(@installutil.is_newer_version('foo', 'http://bar')).to be_false
      end

      it "if no version is present" do
        install_file_path = @installutil.install_file_for("foo")
        stub(@installutil).url_date.returns(1)
        FakeFS do
          FileUtils.rm_rf(File.dirname(install_file_path), :force => true)
          expect(@installutil.is_newer_version('foo', 'http://bar')).to be_true
        end
      end

    end

    context "url_date" do

      it "returns an epoch" do
        excon_response = Excon::Response.new(:headers => {"Last-Modified" => "Mon, 11 Mar 2013 15:03:55 GMT"})
        mock(Excon).head("http://foo/bar", 
                         :headers => {"User-Agent"=>Mortar::USER_AGENT},
                         :query => {}
                        ).returns(excon_response)
        
        actual_epoch = @installutil.url_date("http://foo/bar")
        expect(actual_epoch).to eq(1363014235)
      end

    end

    context "parse_http_date" do

      it "returns the appropriate epoch" do
        epoch = @installutil.http_date_to_epoch("Mon, 11 Mar 2013 15:03:55 GMT")
        expect(epoch).to eq(1363014235)
      end

    end

    context "download_file" do

      it "follows redirect" do
        excon_first_response = Excon::Response.new(:headers => {"Location" => "http://foo/bar2"}, :status => 302)
        mock(Excon).get("http://foo/bar", 
                        :headers => {'User-Agent' => Mortar::USER_AGENT},
                        :query => {}
                        ).returns(excon_first_response)
        
        excon_second_response = Excon::Response.new(:status => 200, :body => "content")
        mock(Excon).get("http://foo/bar2", 
                        :headers => {'User-Agent' => Mortar::USER_AGENT},
                        :query => {}
                        ).returns(excon_second_response)
        
        local_install_directory = @installutil.local_install_directory
        expected_file_path = File.join(local_install_directory, 'bar2')
        FakeFS do
          FileUtils.mkdir_p(local_install_directory)
          @installutil.download_file('http://foo/bar', expected_file_path)
          expect(File.exists?(expected_file_path)).to be_true
        end
      end

    end

    context "get_resource" do
      it "too many redirects" do
        response = Excon::Response.new(:headers => {"Location" => "http://foo/bar"}, :status => 302)
        mock(Excon).get("http://foo/bar", 
                        :headers => {'User-Agent' => Mortar::USER_AGENT},
                        :query => {}
                       ).times(5).returns(response)
        
        lambda { @installutil.get_resource("http://foo/bar") }.should raise_error(RuntimeError, /Too many redirects/)
      end
    end

    context "head_resource" do
      it "too many redirects" do
        ENV['MORTAR_TEST_NAME'] = "Unit Testor"
        response = Excon::Response.new(:headers => {"Location" => "http://foo/bar"}, :status => 302)
        mock(Excon).head("http://foo/bar", 
                         :headers => {'User-Agent' => Mortar::USER_AGENT},
                         :query => { :test_name => "Unit Testor" }
                        ).times(5).returns(response)
        
        lambda { @installutil.head_resource("http://foo/bar") }.should raise_error(RuntimeError, /Too many redirects/)
      end
    end


  end
end

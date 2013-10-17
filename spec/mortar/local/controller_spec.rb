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
require 'mortar/local/controller'
require 'launchy'

module Mortar::Local
  describe Controller do

    before do
      ENV['AWS_ACCESS_KEY'] = "foo"
      ENV['AWS_SECRET_KEY'] = "BAR"
    end

    context("aws keys") do
      it "exits if they are not present" do
        ENV.delete('AWS_ACCESS_KEY')
        ctrl = Mortar::Local::Controller.new
        previous_stderr, $stderr = $stderr, StringIO.new
        begin
          expect { ctrl.require_aws_keys }.to raise_error(SystemExit)
          $stderr.string.should eq(Mortar::Local::Controller::NO_AWS_KEYS_ERROR_MESSAGE.gsub(/^/, " !    "))
        ensure
          $stderr = previous_stderr
        end
      end

      it "returns if they are present" do
        ctrl = Mortar::Local::Controller.new
        previous_stderr, $stderr = $stderr, StringIO.new
        begin
          ctrl.require_aws_keys()
          $stderr.string.should eq("")
        ensure
          $stderr = previous_stderr
        end
      end

      it "returns if they are not present but override is in place" do
        ENV.delete('AWS_ACCESS_KEY')
        ENV['MORTAR_IGNORE_AWS_KEYS'] = 'true'
        ctrl = Mortar::Local::Controller.new
        previous_stderr, $stderr = $stderr, StringIO.new
        begin
          ctrl.require_aws_keys()
          $stderr.string.should eq("")
        ensure
          $stderr = previous_stderr
        end
      end

    end

    context("run") do

      it "checks for aws keys, checks depenendency installation, runs script" do
        c = Mortar::Local::Controller.new
        mock(c).require_aws_keys
        mock(c).install_and_configure("0.9")
        test_script = "foobar-script"
        the_parameters = []
        any_instance_of(Mortar::Local::Pig) do |p|
          mock(p).run_script(test_script, "0.9", the_parameters)
        end
        c.run(test_script, "0.9", the_parameters)
      end

    end

    context("illustrate") do
      it "checks for aws keys, checks depenendency installation, runs the illustrate process" do
        c = Mortar::Local::Controller.new
        mock(c).require_aws_keys
        mock(c).install_and_configure("0.9")
        test_script = "foobar-script"
        script_alias = "some_alias"
        prune = false
        the_parameters = []
        any_instance_of(Mortar::Local::Pig) do |p|
          mock(p).illustrate_alias(test_script, script_alias, prune, "0.9", the_parameters)
        end
        c.illustrate(test_script, script_alias, "0.9", the_parameters, prune)
      end
    end

  end
end

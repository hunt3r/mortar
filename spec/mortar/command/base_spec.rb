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
require "mortar/command/base"

module Mortar::Command
  describe Base do
    before do
      @base = Base.new
      stub(@base).display
      @client = Object.new
      stub(@client).host {'mortar.com'}
    end
    
    context "error message context" do
      it "get context for missing parameter error message" do
        message = "Undefined parameter : INPUT"
        @base.get_error_message_context(message).should == "Use -p, --parameter NAME=VALUE to set parameter NAME to value VALUE."
      end
      
      it "get context for unhandled error message" do
        message = "special kind of error"
        @base.get_error_message_context(message).should == ""
      end
    end

    context "detecting the project" do
      it "read remotes from git config" do
        stub(Dir).chdir
        stub(@base.git).has_dot_git? {true}
        mock(@base.git).git("remote -v").returns(<<-REMOTES)
staging\tgit@github.com:mortarcode/4dbbd83cae8d5bf8a4000000_myproject-staging.git (fetch)
staging\tgit@github.com:mortarcode/4dbbd83cae8d5bf8a4000000_myproject-staging.git (push)
production\tgit@github.com:mortarcode/4dbbd83cae8d5bf8a4000000_myproject.git (fetch)
production\tgit@github.com:mortarcode/4dbbd83cae8d5bf8a4000000_myproject.git (push)
other\tgit@github.com:other.git (fetch)
other\tgit@github.com:other.git (push)
        REMOTES

        @mortar = Object.new
        stub(@mortar).host {'mortar.com'}
        stub(@base).mortar { @mortar }

        # need a better way to test internal functionality
        @base.git.send(:remotes, 'mortarcode').should == { 'staging' => 'myproject-staging', 'production' => 'myproject' }
      end

      it "gets the project from remotes when there's only one project" do
        stub(@base.git).has_dot_git? {true}
        stub(@base.git).remotes {{ 'mortar' => 'myproject' }}
        mock(@base.git).git("config mortar.remote", false).returns("")
        @base.project.name.should == 'myproject'
      end

      it "accepts a --remote argument to choose the project from the remote name" do
        stub(@base.git).has_dot_git?.returns(true)
        stub(@base.git).remotes.returns({ 'staging' => 'myproject-staging', 'production' => 'myproject' })
        stub(@base).options.returns(:remote => "staging")
        @base.project.name.should == 'myproject-staging'
      end

    end

    context "method_added" do
      it "replaces help templates" do
        lines = Base.replace_templates(["line", "start <PIG_VERSION_OPTIONS>"])
        lines.join("").should == 'linestart 0.9 (default) and 0.12 (beta)'
      end
    end

  end
end

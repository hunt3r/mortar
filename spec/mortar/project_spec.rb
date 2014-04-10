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

require "spec_helper"
require "mortar/project"

module Mortar
  describe Project do    
    context "tmp" do
      it "creates a tmp dir if one does not exist" do
        with_blank_project do |p|
          # create it
          tmp_path_0 = p.tmp_path
          File.directory?(tmp_path_0).should be_true
          
          # reuse it
          p.tmp_path.should == tmp_path_0
        end
      end
    end
    
    context "controlscripts" do
      
      it "does not raise an error when unable to find controlscripts dir" do
        with_blank_project do |p|
          FileUtils.rm_rf p.controlscripts_path
          lambda { p.controlscripts_path }.should_not raise_error(Mortar::Project::ProjectError)
        end
      end
      
    end
    
    context "pigscripts" do

      it "raise when unable to find pigscripts dir" do
        with_blank_project do |p|
          FileUtils.rm_rf p.pigscripts_path
          lambda { p.pigscripts }.should raise_error(Mortar::Project::ProjectError)
        end
      end
      
      it "finds no pigscripts in an empty dir" do
        with_blank_project do |p|
          p.pigscripts.none?.should be_true
        end
      end
      
      it "finds a single pigscript" do
        with_blank_project do |p|
          pigscript_path = File.join(p.pigscripts_path, "my_script.pig")
          write_file pigscript_path
          p.pigscripts.my_script.name.should == "my_script"
          p.pigscripts.my_script.path.should == pigscript_path
          p.pigscripts.my_script.executable_path.should == "pigscripts/my_script.pig"
          p.pigscripts.my_script.rel_path.end_with?('pigscripts').should be_true 
        end
      end

      it "finds a script stored in a subdirectory" do
        with_blank_project do |p|
          pigscript_path = File.join(p.pigscripts_path, "subdir", "my_script.pig")
          write_file pigscript_path
          p.pigscripts.my_script.name.should == "my_script"
          p.pigscripts.my_script.path.should == pigscript_path
          p.pigscripts.my_script.rel_path.end_with?("pigscripts/subdir").should be_true
        end
      end
      
      it "finds multiple scripts in subdirectories with the same name" do
      end
    end
  end
end

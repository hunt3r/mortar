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

require "fileutils"
require "mortar/generators/generator_base"
module Mortar
  module Generators
    class CharacterizeGenerator < Base

      def generate_characterize
        begin
          inside "pigscripts" do
            copy_file "characterize.pig", "characterize.pig"
          end

          inside "controlscripts" do
            inside "lib" do
              copy_file "characterize_control.py", "characterize_control.py"
            end
          end

          inside "macros" do
            copy_file "characterize_macro.pig", "characterize_macro.pig"
          end

          inside "udfs" do
            inside "jython" do
              copy_file "top_5_tuple.py", "top_5_tuple.py"
            end
          end

        # how best to handle exceptions, here?
        rescue => e 
          display("\nCharacterize script generation failed.\n\n")
          raise e
        end
      end

      def cleanup_characterize(project_root)
        @src_path = project_root
        begin
          inside "pigscripts" do
            remove_file "characterize.pig"
          end

          inside "controlscripts" do
            inside "lib" do
              remove_file "characterize_control.py"
            end
          end

          inside "macros" do
            remove_file "characterize_macro.pig"
          end

          inside "udfs" do
            inside "jython" do
              remove_file "top_5_tuple.py"
            end
          end

        # how best to handle exceptions, here?
        rescue => e 
          display("\nCharacterize script cleanup failed.\n\n")
          raise e
        end
      end

      def remove_file(target_file, options={ :recursive => false })
        target_path = File.join(@src_path, @rel_path, target_file)
        msg = File.join(@rel_path, target_file)[1..-1]

        if File.exists?(target_path)
          FileUtils.rm(target_path)
        end
      end
          
      def copy_file(src_file, dest_file, options={ :recursive => false })
        src_path = File.join(@src_path, @rel_path, src_file)
        dest_path = File.join(@dest_path, @rel_path, dest_file)
        msg = File.join(@rel_path, dest_file)[1..-1]

        unless File.exists?(dest_path) and 
            FileUtils.compare_file(src_path, dest_path)
          FileUtils.mkdir_p(File.dirname(dest_path)) if options[:recursive]
          FileUtils.cp(src_path, dest_path)
        end
      end

    end
  end
end

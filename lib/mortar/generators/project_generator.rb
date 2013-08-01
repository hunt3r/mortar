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
    class ProjectGenerator < Base

      def generate_project(project_name, options)

        set_script_binding(project_name, options)
        #TODO: This needs refactoring.  Too many side effects and unnecessary
        #complexity.  Just manage the directory structure explicitly.
        project_path = File.join(@dest_path, project_name)
        project_already_existed = File.exists?(project_path)
        begin
          mkdir project_name, :verbose => false
          @dest_path = File.join(@dest_path, project_name)
          
          copy_file "README.md", "README.md"
          copy_file "gitignore", ".gitignore"
          
          mkdir "pigscripts"
          
          inside "pigscripts" do
            generate_file "pigscript.pig", "#{project_name}.pig"
          end

          mkdir "controlscripts" 

          inside "controlscripts" do
            mkdir "lib"
            inside "lib" do
              copy_file "__init__.py", "__init__.py"
            end
          end
          
          mkdir "macros"
          
          inside "macros" do
            copy_file "gitkeep", ".gitkeep"
          end

          mkdir "fixtures"

          inside "fixtures" do
            copy_file "gitkeep", ".gitkeep"
          end
          
          mkdir "udfs"
          
          inside "udfs" do
            mkdir "python"
            inside "python" do
              copy_file "python_udf.py", "#{project_name}.py"
            end

            mkdir "jython"
            inside "jython" do
              copy_file "gitkeep", ".gitkeep"
            end

            mkdir "java"
            inside "java" do
              copy_file "gitkeep", ".gitkeep"
            end
          end

          mkdir "vendor"

          inside "vendor" do
            mkdir "controlscripts"
            inside "controlscripts" do
              mkdir "lib"
              inside "lib" do
                copy_file "__init__.py", "__init__.py"
              end
            end

            mkdir "pigscripts"
            inside "pigscripts" do
              copy_file "gitkeep", ".gitkeep"
            end

            mkdir "macros"
            inside "macros" do
              copy_file "gitkeep", ".gitkeep"
            end

            mkdir "udfs"
            inside "udfs" do
              mkdir "python"
              inside "python" do
                copy_file "gitkeep", ".gitkeep"
              end

              mkdir "jython"
              inside "jython" do
                copy_file "gitkeep", ".gitkeep"
              end

              mkdir "java"
              inside "java" do
                copy_file "gitkeep", ".gitkeep"
              end
            end
          end
          
        rescue => e 
          #If we can't set up the project correctly and the project folder
          #didn't exist before - remove it.
          unless project_already_existed or not File.exists?(project_path)
            display("\nProject creation failed.  Removing generated files.\n")
            FileUtils.remove_dir project_path
          end
          raise e
        end

      end

      protected

        def set_script_binding(project_name, options)
          options = options
          project_name = project_name
          project_name_alias = project_name.gsub /[^0-9a-z]/i, ''
          @script_binding = binding
        end
    end
  end
end

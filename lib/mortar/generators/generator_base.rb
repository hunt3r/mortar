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

require "erb"
require "fileutils"

module Mortar
  module Generators
    class Base 
      include Mortar::Helpers

      def initialize()
        # This is a really ugly way to turn the subclass name 'Mortar::Generators::ProjectGenerator'
        # into 'project' so we can use it to find the appropriate templates folder

        generator_type = self.class.name.split("::")[2].match(/.*(?=([A-Z]))/)[0].downcase
        @src_path = File.expand_path("../../templates/#{generator_type}", __FILE__)
        @dest_path = Dir.pwd
        @rel_path = ""
        @binding_variables = {}
      end
      
      def inside(folder)
        rel_backup = @rel_path
        @rel_path = File.join(@rel_path, folder)
        yield
        @rel_path = rel_backup
      end

      def copy_file(src_file, dest_file, options={ :recursive => false })
        src_path = File.join(@src_path, @rel_path, src_file)
        dest_path = File.join(@dest_path, @rel_path, dest_file)
        msg = File.join(@rel_path, dest_file)[1..-1]

        if File.exists?(dest_path)
          if FileUtils.compare_file(src_path, dest_path)
            display_identical(msg)
          else
            display_conflict(msg)
          end 
        else
          display_create(msg)  
          FileUtils.mkdir_p(File.dirname(dest_path)) if options[:recursive]
          FileUtils.cp(src_path, dest_path)
        end
      end

      def mkdir(folder, options={ :verbose => true })
        dest_path = File.join(@dest_path, @rel_path, folder)
        msg = File.join(@rel_path, folder)[1..-1]

        if File.exists?(dest_path) 
          display_exists(options[:verbose] ? msg : "") 
        else
          display_create(options[:verbose] ? msg : "")
          FileUtils.mkdir(dest_path)
        end
      end

      def generate_file(src_file, dest_file, options={ :recursive => false })
        src_path = File.join(@src_path, @rel_path, src_file)
        dest_path = File.join(@dest_path, @rel_path, dest_file)
        msg = File.join(@rel_path, dest_file)[1..-1]

        erb = ERB.new(File.read(src_path), 0, "%<>")

        result = erb.result(@script_binding)
        

        if File.exists?(dest_path)
          if result == File.read(dest_path) 
            display_identical(msg)
          else
            display_conflict(msg)
          end 
        else
          FileUtils.mkdir_p(File.dirname(dest_path)) if options[:recursive]
          file = File.new(dest_path, "w")
          file.write(result)
          file.close
          display_create(msg)  
        end
      end

      protected

        def set_script_binding(options)
          options = options
          binding
        end

    end
  end
end

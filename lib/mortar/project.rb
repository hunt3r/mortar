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

require 'fileutils'
require 'pathname'

module Mortar
  module Project
    class ProjectError < RuntimeError; end
    
    class Project
      def self.required_directories
        ["macros", "pigscripts", "udfs"]
      end
      
      attr_accessor :name
      attr_accessor :remote
      attr_accessor :root_path
      
      def initialize(name, root_path, remote)
        @name = name
        @root_path = root_path
        @remote = remote
      end
      
      def python_udfs_path
        File.join(@root_path, "udfs/python")
      end

      def python_udfs
        @python_udfs ||= PythonUDFs.new(
          python_udfs_path,
          "python",
          ".py")
      end
      
      def pigscripts_path
        File.join(@root_path, "pigscripts")
      end

      def pigscripts
        @pigscripts ||= PigScripts.new(
          pigscripts_path,
          "pigscripts",
          ".pig")
        @pigscripts
      end

      def controlscripts_path
        File.join(@root_path, "controlscripts")
      end

      def controlscripts
        @controlscripts ||= ControlScripts.new(
          controlscripts_path,
          "controlscripts",
          ".py",
          :optional => true)
        @controlscripts
      end

      def luigiscripts_path
        File.join(@root_path, "luigiscripts")
      end

      def luigiscripts
        @luigiscripts ||= LuigiScripts.new(
          luigiscripts_path,
          "luigiscripts",
          ".py",
          :optional => true)
        @luigiscripts
      end

      def tmp_path
        path = File.join(@root_path, "tmp")
        unless File.directory? path
          FileUtils.mkdir_p path
        end
        path
      end

      def fixtures_path
        path = File.join(@root_path, "fixtures")
      end

      def embedded_project?()
        File.exists?(File.join(@root_path, ".mortar-project-remote"))
      end
    end
    
    class ProjectEntity
      
      include Enumerable
      
      def initialize(path, name, filename_extension, optional=false)
        @path = path
        @name = name
        @filename_extension = filename_extension
        @optional = optional
        @elements = elements
      end
      
      def method_missing(method, *args)
        method_name = method.to_s
        return @elements[method_name] if @elements[method_name]
        super
      end
      
      def each
        @elements.each {|key, value| yield [key, value]}
      end
      
      def [](key)
        @elements[key]
      end
      
      def keys
        @elements.keys
      end
      
      protected
      
      def element_name(element_path)
        File.basename(element_path, @filename_extension)
      end

      def elements
        if File.directory? @path
          # get {script_name => full_path}
          file_paths = Dir[File.join(@path, "**", "*#{@filename_extension}")]

          scripts = file_paths.collect{|element_path| [element_name(element_path), element(element_name(element_path), element_path)]}

          #Check for duplicates.
          name_groups = scripts.group_by{ |x| x[0] }
          duplicates = name_groups.find_all{ |k,v| v.length > 1 }
          if duplicates.length > 0
            raise ProjectError, "Multiple scripts found with the same name.  Each script must have a unique name regardless of what directory it is in.  Duplicate script names found: #{duplicates.collect{|d| d[0]}}"
          end
          
          file_paths_hsh = scripts.flatten
          return Hash[*file_paths_hsh]
        else
          raise ProjectError, "Unable to find #{@name} directory in project" if not @optional
        end
        return Hash[]
      end
      
      def element(path)
        raise NotImplementedError, "Implement in subclass"
      end
    end
    
    class PigScripts < ProjectEntity
      def element(name, path)
        PigScript.new(name, path)
      end
    end

    class ControlScripts < ProjectEntity
      def element(name, path)
        ControlScript.new(name, path)
      end
    end

    class LuigiScripts < ProjectEntity
      def element(name, path)
        LuigiScript.new(name, path)
      end
    end

    class PythonUDFs < ProjectEntity
      def element(name, path)
        Script.new(name, path)
      end
    end
    
    class Script
      
      attr_reader :name
      attr_reader :path
      
      def initialize(name, path)
        @name = name
        @path = path
      end

      def code
        script_file = File.open(@path, "r")
        script_contents = script_file.read
        script_file.close
        script_contents
      end

      def rel_path
        p = Pathname.new(@path).dirname
        rel_path = p.relative_path_from(Pathname.pwd).to_s
      end
      
      def to_s
        code
      end
    end

    class LuigiScript < Script
      
      def executable_path
        "luigiscripts/#{self.name}.py"
      end
      
    end
    
    class ControlScript < Script
      
      def executable_path
        "controlscripts/#{self.name}.pig"
      end
      
    end
    
    class PigScript < Script
      
      def executable_path
        "pigscripts/#{self.name}.pig"
      end
    
    end
    
  end
end

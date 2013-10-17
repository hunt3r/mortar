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

require 'rexml/document'
require 'mortar/helpers'
require 'mortar/plugin'
require 'mortar/project'
require 'mortar/version'
require 'mortar/api'
require "optparse"


module Mortar
  module Command
    class CommandFailed  < RuntimeError; end

    extend Mortar::Helpers

    def self.load
      Dir[File.join(File.dirname(__FILE__), "command", "*.rb")].each do |file|
        require file
      end
      Mortar::Plugin.load!
    end

    def self.commands
      @@commands ||= {}
    end

    def self.command_aliases
      @@command_aliases ||= {}
    end

    def self.files
      @@files ||= Hash.new {|hash,key| hash[key] = File.readlines(key).map {|line| line.strip}}
    end

    def self.namespaces
      @@namespaces ||= {}
    end

    def self.register_command(command)
      commands[command[:command]] = command
    end

    def self.register_namespace(namespace)
      namespaces[namespace[:name]] = namespace
    end

    def self.current_command
      @current_command
    end

    def self.current_command=(new_current_command)
      @current_command = new_current_command
    end

    def self.current_args
      @current_args
    end

    def self.current_options
      @current_options ||= {}
    end

    def self.global_options
      @global_options ||= []
    end

    def self.invalid_arguments
      @invalid_arguments
    end

    def self.shift_argument
      # dup argument to get a non-frozen string
      @invalid_arguments.shift.dup rescue nil
    end

    def self.validate_arguments!
      unless invalid_arguments.empty?
        arguments = invalid_arguments.map {|arg| "\"#{arg}\""}
        if arguments.length == 1
          message = "Invalid argument: #{arguments.first}"
        elsif arguments.length > 1
          message = "Invalid arguments: "
          message << arguments[0...-1].join(", ")
          message << " and "
          message << arguments[-1]
        end
        $stderr.puts(format_with_bang(message))
        run(current_command, ["--help"])
        exit(1)
      end
    end

    def self.warnings
      @warnings ||= []
    end

    def self.display_warnings
      unless warnings.empty?
        $stderr.puts(warnings.map {|warning| " !    #{warning}"}.join("\n"))
      end
    end

    def self.global_option(name, *args, &blk)
      global_options << { :name => name, :args => args, :proc => blk }
    end

    global_option :help,    "--help", "-h"
    global_option :remote,  "--remote REMOTE"
    global_option :polling_interval, "--polling_interval SECONDS", "-p"
    global_option :no_browser, "--no_browser"
    global_option :pigversion, "--pigversion PIG_VERSION", "-g"

    def self.prepare_run(cmd, args=[])
      command = parse(cmd)

      if args.include?('-h') || args.include?('--help') || args.include?('help')
        args.unshift(cmd) unless cmd =~ /^-.*/
        cmd = 'help'
        command = parse('help')
      end

      unless command
        if %w( -v --version ).include?(cmd)
          cmd = 'version'
          command = parse(cmd)
        # Check if the command tried matches a command file. If it does, the command exists, but doesn't have an index action
        # Otherwise it would have been picked up by the original parse command.
        elsif Dir[File.join(File.dirname(__FILE__), "command", "*.rb")].find { |file| file.include?(cmd) }
          display "#{cmd} command requires arguments"
          display
          # Display the command's help message
          args.unshift(cmd) unless cmd =~ /^-.*/
          cmd = 'help'
          command = parse('help')
        else
          error([
            "`#{cmd}` is not a mortar command.",
            suggestion(cmd, commands.keys + command_aliases.keys),
            "See `mortar help` for a list of available commands."
          ].compact.join("\n"))
        end
      end

      @current_command = cmd

      opts = {}
      invalid_options = []

      parser = OptionParser.new do |parser|
        # overwrite OptionParsers Officious['version'] to avoid conflicts
        # see: https://github.com/ruby/ruby/blob/trunk/lib/optparse.rb#L814
        parser.on("--version") do |value|
          invalid_options << "--version"
        end
        global_options.each do |global_option|
          parser.on(*global_option[:args]) do |value|
            global_option[:proc].call(value) if global_option[:proc]
            opts[global_option[:name]] = value
          end
        end

        command[:options].each do |name, option|
          parser.on("-#{option[:short]}", "--#{option[:long]}", option[:desc]) do |value|
            opt_name_sym = name.gsub("-", "_").to_sym
            if opts[opt_name_sym]
              # convert multiple instances of an option to an array
              unless opts[opt_name_sym].is_a?(Array)
                opts[opt_name_sym] = [opts[opt_name_sym]]
              end
              opts[opt_name_sym] << value
            else
              opts[opt_name_sym] = value
            end
          end
        end
      end

      begin
        parser.order!(args) do |nonopt|
          invalid_options << nonopt
        end
      rescue OptionParser::InvalidOption => ex
        invalid_options << ex.args.first
        retry
      end

      args.concat(invalid_options)

      @current_args = args
      @current_options = opts
      @invalid_arguments = invalid_options

      [ command[:klass].new(args.dup, opts.dup), command[:method] ]
    end

    def self.run(cmd, arguments=[])
      begin
        object, method = prepare_run(cmd, arguments.dup)
        object.send(method)
      rescue Interrupt, StandardError, SystemExit => error
        # load likely error classes, as they may not be loaded yet due to defered loads
        require 'mortar-api-ruby'
        raise(error)
      end
    rescue Mortar::API::Errors::Unauthorized
      puts "Authentication failure"
      unless ENV['MORTAR_API_KEY']
        run "login"
        retry
      end
    rescue Mortar::API::Errors::NotFound => e
      error extract_error(e.response.body) {
        e.response.body =~ /^([\w\s]+ not found).?$/ ? $1 : e.message # "Resource not found"
      }
    rescue Mortar::Git::GitError => e
      error e.message
    rescue Mortar::Project::ProjectError => e
      error e.message
    rescue Mortar::API::Errors::Timeout
      error "API request timed out. Please try again, or contact support@mortardata.com if this issue persists."
    rescue Mortar::API::Errors::ErrorWithResponse => e
      error extract_error(e.response.body)
    rescue CommandFailed => e
      error e.message
    rescue OptionParser::ParseError
      commands[cmd] ? run("help", [cmd]) : run("help")
    ensure
      display_warnings
    end

    def self.parse(cmd)
      commands[cmd] || commands[command_aliases[cmd]]
    end

    def self.extract_error(body, options={})
      default_error = block_given? ? yield : "Internal server error."
      parse_error_xml(body) || parse_error_json(body) || parse_error_plain(body) || default_error
    end

    def self.parse_error_xml(body)
      xml_errors = REXML::Document.new(body).elements.to_a("//errors/error")
      msg = xml_errors.map { |a| a.text }.join(" / ")
      return msg unless msg.empty?
    rescue Exception
    end

    def self.parse_error_json(body)
      json = json_decode(body.to_s) rescue false
      case json
      when Array
        json.first.last # message like [['base', 'message']]
      when Hash
        json['error']   # message like {'error' => 'message'}
      else
        nil
      end
    end

    def self.parse_error_plain(body)
      return unless body.respond_to?(:headers) && body.headers[:content_type].to_s.include?("text/plain")
      body.to_s
    end
  end
end

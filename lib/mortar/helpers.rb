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

require 'fileutils'
require "vendor/mortar/okjson"
require 'open-uri'

module Mortar
  module Helpers

    extend self

    def home_directory
      running_on_windows? ? ENV['USERPROFILE'].gsub("\\","/") : ENV['HOME']
    end

    def running_on_windows?
      RUBY_PLATFORM =~ /mswin32|mingw32/
    end

    def running_on_a_mac?
      RUBY_PLATFORM =~ /-darwin\d/
    end

    def default_host
      "mortardata.com"
    end
    
    def host
      ENV['MORTAR_HOST'] || default_host
    end

    def test_name
      ENV['MORTAR_TEST_NAME']
    end

    def write_to_file(str_data, path, mkdir_p=true)
      if mkdir_p
        FileUtils.mkdir_p File.dirname(path)
      end
      File.open(path, "w"){|f| f.write(str_data)}
    end

    def download_to_file(url, path, mkdir_p=true)
      content_length = 0
      
      set_content_length = lambda do |l|
        content_length = l
      end
      set_progress = lambda do |p|
        redisplay("Downloading #{path}: #{p.to_i} of #{content_length.to_i}")
      end
      
      open(url,
        :content_length_proc => set_content_length,
        :progress_proc => set_progress) do |f|
          write_to_file(f.read, path, mkdir_p)
      end
      
    end

    def display(msg="", new_line=true)
      if new_line
        puts(msg)
      else
        print(msg)
        $stdout.flush
      end
    end

    def warning(msg="", new_line=true)
      message = "WARNING: #{msg}"
      if new_line
        display(message)
      else
        print(msg)
        $stdout.flush
      end
    end

    def redisplay(line, line_break = false)
      display("\r\e[0K#{line}", line_break)
    end

    def deprecate(message)
      display "WARNING: #{message}"
    end

    def confirm(message="Are you sure you wish to continue? (y/n)?")
      display("#{message} ", false)
      ['y', 'yes'].include?(ask.downcase)
    end

    def format_date(date)
      date = Time.parse(date) if date.is_a?(String)
      date.strftime("%Y-%m-%d %H:%M %Z")
    end

    def ask
      $stdin.gets.to_s.strip
    end

    def shell(cmd)
      FileUtils.cd(Dir.pwd) {|d| return `#{cmd}`}
    end

    def retry_on_exception(*exceptions)
      retry_count = 0
      begin
        yield
      rescue *exceptions => ex
        raise ex if retry_count >= 3
        sleep 3
        retry_count += 1
        retry
      end
    end

    def time_ago(elapsed)
      if elapsed <= 60
        "#{elapsed.floor}s ago"
      elsif elapsed <= (60 * 60)
        "#{(elapsed / 60).floor}m ago"
      elsif elapsed <= (60 * 60 * 25)
        "#{(elapsed / 60 / 60).floor}h ago"
      else
        (Time.now - elapsed).strftime("%Y/%m/%d %H:%M:%S")
      end
    end

    def truncate(text, length)
      if text.size > length
        text[0, length - 2] + '..'
      else
        text
      end
    end

    @@kb = 1024
    @@mb = 1024 * @@kb
    @@gb = 1024 * @@mb
    def format_bytes(amount)
      amount = amount.to_i
      return '(empty)' if amount == 0
      return amount if amount < @@kb
      return "#{(amount / @@kb).round}k" if amount < @@mb
      return "#{(amount / @@mb).round}M" if amount < @@gb
      return "#{(amount / @@gb).round}G"
    end

    def quantify(string, num)
      "%d %s" % [ num, num.to_i == 1 ? string : "#{string}s" ]
    end

    def longest(items)
      items.map { |i| i.to_s.length }.sort.last
    end

    def display_table(objects, columns, headers)
      lengths = []
      columns.each_with_index do |column, index|
        header = headers[index]
        lengths << longest([header].concat(objects.map { |o| o[column].to_s }))
      end
      lines = lengths.map {|length| "-" * length}
      lengths[-1] = 0 # remove padding from last column
      display_row headers, lengths
      display_row lines, lengths
      objects.each do |row|
        display_row columns.map { |column| row[column] }, lengths
      end
    end

    def display_row(row, lengths)
      row_data = []
      row.zip(lengths).each do |column, length|
        format = column.is_a?(Fixnum) ? "%#{length}s" : "%-#{length}s"
        row_data << format % column
      end
      display(row_data.join("  "))
    end

    def json_encode(object)
      Mortar::OkJson.encode(object)
    rescue Mortar::OkJson::Error
      nil
    end

    def json_decode(json)
      Mortar::OkJson.decode(json)
    rescue Mortar::OkJson::Error
      nil
    end

    def set_buffer(enable)
      with_tty do
        if enable
          `stty icanon echo`
        else
          `stty -icanon -echo`
        end
      end
    end

    def with_tty(&block)
      return unless $stdin.isatty
      begin
        yield
      rescue
        # fails on windows
      end
    end

    def get_terminal_environment
      { "TERM" => ENV["TERM"], "COLUMNS" => `tput cols`.strip, "LINES" => `tput lines`.strip }
    rescue
      { "TERM" => ENV["TERM"] }
    end

    ## DISPLAY HELPERS

    def action(message, options={})
      display("#{message}... ", false)
      Mortar::Helpers.error_with_failure = true
      ret = yield
      Mortar::Helpers.error_with_failure = false
      display((options[:success] || "done"), false)
      if @status
        display(", #{@status}", false)
        @status = nil
      end
      display
      ret
    end

    def status(message)
      @status = message
    end

    def format_with_bang(message)
      return '' if message.to_s.strip == ""
      " !    " + message.split("\n").join("\n !    ")
    end

    def output_with_bang(message="", new_line=true)
      return if message.to_s.strip == ""
      display(format_with_bang(message), new_line)
    end

    def error(message)
      if Mortar::Helpers.error_with_failure
        display("failed")
        Mortar::Helpers.error_with_failure = false
      end
      $stderr.puts(format_with_bang(message))
      exit(1)
    end

    def self.error_with_failure
      @@error_with_failure ||= false
    end

    def self.error_with_failure=(new_error_with_failure)
      @@error_with_failure = new_error_with_failure
    end

    def self.included_into
      @@included_into ||= []
    end

    def self.extended_into
      @@extended_into ||= []
    end

    def self.included(base)
      included_into << base
    end

    def self.extended(base)
      extended_into << base
    end

    def display_header(message="", new_line=true)
      return if message.to_s.strip == ""
      display("=== " + message.to_s.split("\n").join("\n=== "), new_line)
    end

    def display_object(object)
      case object
      when Array
        # list of objects
        object.each do |item|
          display_object(item)
        end
      when Hash
        # if all values are arrays, it is a list with headers
        # otherwise it is a single header with pairs of data
        if object.values.all? {|value| value.is_a?(Array)}
          object.keys.sort_by {|key| key.to_s}.each do |key|
            display_header(key)
            display_object(object[key])
            hputs
          end
        end
      else
        hputs(object.to_s)
      end
    end

    def hputs(string='')
      Kernel.puts(string)
    end

    def hprint(string='')
      Kernel.print(string)
      $stdout.flush
    end

    def ticking(sleep_time)
      ticks = 0
      loop do
        yield(ticks)
        ticks +=1
        sleep sleep_time
      end
    end

    def spinner(ticks)
      %w(/ - \\ |)[ticks % 4]
    end

    # produces a printf formatter line for an array of items
    # if an individual line item is an array, it will create columns
    # that are lined-up
    #
    # line_formatter(["foo", "barbaz"])                 # => "%-6s"
    # line_formatter(["foo", "barbaz"], ["bar", "qux"]) # => "%-3s   %-6s"
    #
    def line_formatter(array)
      if array.any? {|item| item.is_a?(Array)}
        cols = []
        array.each do |item|
          if item.is_a?(Array)
            item.each_with_index { |val,idx| cols[idx] = [cols[idx]||0, (val || '').length].max }
          end
        end
        cols.map { |col| "%-#{col}s" }.join("  ")
      else
        "%s"
      end
    end

    def styled_array(array, options={})
      fmt = line_formatter(array)
      array = array.sort unless options[:sort] == false
      array.each do |element|
        display((fmt % element).rstrip)
      end
      display
    end

    def styled_error(error, message='Mortar Development Framework internal error.')
      if Mortar::Helpers.error_with_failure
        display("failed")
        Mortar::Helpers.error_with_failure = false
      end
      $stderr.puts(" !    #{message}.")
      $stderr.puts(" !    Search for help at: http://help.mortardata.com")
      $stderr.puts(" !    Or report a bug at: https://github.com/mortardata/mortar/issues/new")
      $stderr.puts
      $stderr.puts("    Error:       #{error.message} (#{error.class})")
      $stderr.puts("    Backtrace:   #{error.backtrace.first}")
      error.backtrace[1..-1].each do |line|
        $stderr.puts("                 #{line}")
      end
      if error.backtrace.length > 1
        $stderr.puts
      end
      command = ARGV.map do |arg|
        if arg.include?(' ')
          arg = %{"#{arg}"}
        else
          arg
        end
      end.join(' ')
      $stderr.puts("    Command:     mortar #{command}")
      unless Mortar::Auth.host == Mortar::Auth.default_host
        $stderr.puts("    Host:        #{Mortar::Auth.host}")
      end
      if http_proxy = ENV['http_proxy'] || ENV['HTTP_PROXY']
        $stderr.puts("    HTTP Proxy:  #{http_proxy}")
      end
      if https_proxy = ENV['https_proxy'] || ENV['HTTPS_PROXY']
        $stderr.puts("    HTTPS Proxy: #{https_proxy}")
      end
      $stderr.puts("    Version:     #{Mortar::USER_AGENT}")
      $stderr.puts
    end

    def styled_header(header)
      display("=== #{header}")
    end

    def styled_hash(hash, keys=nil, indent=0)
      def display_with_indent(indent, msg="", new_line=true)
        display("#{"".ljust(indent)}#{msg.to_s}", new_line)
      end
      
      max_key_length = hash.keys.map {|key| key.to_s.length}.max + 2
      keys ||= hash.keys.sort {|x,y| x.to_s <=> y.to_s}
      keys.each do |key|
        case value = hash[key]
        when Hash
          display_with_indent(indent, "#{key}: ".ljust(max_key_length))
          styled_hash(hash[key], nil, indent + 2)
        when Array
          if value.empty?
            next
          else
            elements = value.sort {|x,y| x.to_s <=> y.to_s}
            display_with_indent(indent, "#{key}: ".ljust(max_key_length))
            elements[0..-1].each do |element|
              case element
              when Hash
                styled_hash(element, nil, indent + 2)
              else
                display_with_indent(indent, "#{' ' * max_key_length}#{element}")
              end
            end
            if elements.length > 1
              display
            end
          end
        when nil
          next
        else
          display_with_indent(indent, "#{key}: ".ljust(max_key_length), false)
          display_with_indent(indent, value)
        end
      end
    end

    def string_distance(first, last)
      distances = [] # 0x0s
      0.upto(first.length) do |index|
        distances << [index] + [0] * last.length
      end
      distances[0] = 0.upto(last.length).to_a
      1.upto(last.length) do |last_index|
        1.upto(first.length) do |first_index|
          first_char = first[first_index - 1, 1]
          last_char = last[last_index - 1, 1]
          if first_char == last_char
            distances[first_index][last_index] = distances[first_index - 1][last_index - 1] # noop
          else
            distances[first_index][last_index] = [
              distances[first_index - 1][last_index],     # deletion
              distances[first_index][last_index - 1],     # insertion
              distances[first_index - 1][last_index - 1]  # substitution
            ].min + 1 # cost
            if first_index > 1 && last_index > 1
              first_previous_char = first[first_index - 2, 1]
              last_previous_char = last[last_index - 2, 1]
              if first_char == last_previous_char && first_previous_char == last_char
                distances[first_index][last_index] = [
                  distances[first_index][last_index],
                  distances[first_index - 2][last_index - 2] + 1 # transposition
                ].min
              end
            end
          end
        end
      end
      distances[first.length][last.length]
    end

    def suggestion(actual, possibilities)
      distances = Hash.new {|hash,key| hash[key] = []}

      possibilities.each do |suggestion|
        distances[string_distance(actual, suggestion)] << suggestion
      end

      minimum_distance = distances.keys.min
      if minimum_distance < 4
        suggestions = distances[minimum_distance].sort
        if suggestions.length == 1
          "Perhaps you meant `#{suggestions.first}`."
        else
          "Perhaps you meant #{suggestions[0...-1].map {|suggestion| "`#{suggestion}`"}.join(', ')} or `#{suggestions.last}`."
        end
      else
        nil
      end
    end

    def ensure_dir_exists(dir)
      unless File.directory? dir
        Dir.mkdir(dir)
      end
    end

    def copy_if_not_present_at_dest(res_src, res_dest)
      unless File.exists?(res_dest)
        FileUtils.cp(res_src, res_dest)
      end
    end

    private

      def create_display_method(name, colour_code, new_line=true)
        define_method("display_#{name}") do |msg|
          if new_line
            printf("\e[#{colour_code}m%12s\e[0m  #{msg}\n", name)
          else
            printf("\e[#{colour_code}m#{name}\e[0m\t#{msg}")
            $stdout.flush
          end
        end
      end

      create_display_method("create", "1;32")
      create_display_method("run", "1;32")
      create_display_method("exists", "1;34")
      create_display_method("identical", "1;34")
      create_display_method("conflict", "1;31")
  end
end

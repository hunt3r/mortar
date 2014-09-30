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

require "mortar"
require "mortar/helpers"
require "mortar/errors"

require "netrc"

class Mortar::Auth
  class << self
    include Mortar::Helpers

    attr_accessor :credentials
    
    def api
      @api ||= begin
        require("mortar-api-ruby")
        api = Mortar::API.new(default_params.merge(:user => user, :api_key => password))

        def api.request(params, &block)
          response = super
          if response.headers.has_key?('X-Mortar-Warning')
            Mortar::Command.warnings.concat(response.headers['X-Mortar-Warning'].split("\n"))
          end
          response
        end

        api
      end
    end

    def login
      delete_credentials
      get_credentials
    end
    
    def logout
      delete_credentials
    end
    
    def check
      @mortar_user = api.get_user.body
      #Need to ensure user has a github_username
      unless @mortar_user.fetch("user_github_username", nil)
        begin
          ask_for_and_save_github_username
        rescue Mortar::CLI::Errors::InvalidGithubUsername => e
          retry if retry_set_github_username?
          raise e
        end
      end
    end
  
    def reauthorize
      @credentials = ask_for_and_save_credentials
    end

    def user(local=false)    # :nodoc:
      if (local && !has_credentials)
        "notloggedin@user.org"
      else
        get_credentials[0]
      end
    end

    def password(local=false)    # :nodoc:
      if (local && !has_credentials)
        "notloggedin"
      else
        get_credentials[1]
      end
    end

    def user_s3_safe(local = false)
      user_email = user(local)
      return user_email.gsub(/[^0-9a-zA-Z]/i, '-')
    end

    def api_key(user = get_credentials[0], password = get_credentials[1])
      require("mortar-api-ruby")
      api = Mortar::API.new(default_params)
      api.post_login(user, password).body["api_key"]
    end

    def has_credentials
      (nil != read_credentials)
    end

    def get_credentials    # :nodoc:
      @credentials ||= (read_credentials || ask_for_and_save_credentials)
    end

    def delete_credentials
      if netrc
        netrc.delete("api.#{host}")
        netrc.save
      end
      @api, @client, @credentials = nil, nil
    end

    def netrc_path
      default = Netrc.default_path
      encrypted = default + ".gpg"
      from_env = ENV['MORTAR_LOGIN_FILE']
      if from_env
        from_env
      elsif File.exists?(encrypted)
        encrypted
      else
        default
      end
    end

    def netrc   # :nodoc:
      @netrc ||= begin
        File.exists?(netrc_path) && Netrc.read(netrc_path)
      rescue => error
        if error.message =~ /^Permission bits for/
          perm = File.stat(netrc_path).mode & 0777
          abort("Permissions #{perm} for '#{netrc_path}' are too open. You should run `chmod 0600 #{netrc_path}` so that your credentials are NOT accessible by others.")
        else
          raise error
        end
      end
    end

    def read_credentials
      if ENV['MORTAR_API_KEY']
        ['', ENV['MORTAR_API_KEY']]
      else
        if netrc
          netrc["api.#{host}"]
        end
      end
    end

    def write_credentials
      FileUtils.mkdir_p(File.dirname(netrc_path))
      FileUtils.touch(netrc_path)
      unless running_on_windows?
        FileUtils.chmod(0600, netrc_path)
      end
      netrc["api.#{host}"] = self.credentials
      netrc.save
    end

    def echo_off
      with_tty do
        system "stty -echo"
      end
    end

    def echo_on
      with_tty do
        system "stty echo"
      end
    end

    def ask_for_credentials
      puts
      puts "Enter your Mortar credentials."

      print "Email: "
      user = ask

      print "Password (typing will be hidden): "
      password = running_on_windows? ? ask_for_password_on_windows : ask_for_password

      [user, api_key(user, password)]
    end

    def ask_for_github_username
      puts
      puts "Please enter your GitHub username (not email address)."

      print "GitHub Username: "
      github_username = ask
      github_username
    end

    def ask_for_password_on_windows
      require "Win32API"
      char = nil
      password = ''

      while char = Win32API.new("crtdll", "_getch", [ ], "L").Call do
        break if char == 10 || char == 13 # received carriage return or newline
        if char == 127 || char == 8 # backspace and delete
          password.slice!(-1, 1)
        else
          # windows might throw a -1 at us so make sure to handle RangeError
          (password << char.chr) rescue RangeError
        end
      end
      puts
      return password
    end

    def ask_for_password
      echo_off
      password = ask
      puts
      echo_on
      return password
    end

    def ask_for_and_save_credentials
      require("mortar-api-ruby") # for the errors
      begin
        @credentials = ask_for_credentials
        write_credentials
        check
      rescue Mortar::API::Errors::NotFound, Mortar::API::Errors::Unauthorized => e
        delete_credentials
        display "Authentication failed."
        retry if retry_login?
        exit 1
      rescue Mortar::CLI::Errors::InvalidGithubUsername => e
        #Too many failures at setting github username
        display "Authentication failed."
        delete_credentials
        exit 1
      rescue Exception => e
        delete_credentials
        raise e
      end
      # TODO: ensure that keys exist
      #check_for_associated_ssh_key unless Mortar::Command.current_command == "keys:add"
      @credentials
    end

    def ask_for_and_save_github_username
      require ("mortar-api-ruby")
      begin
        @github_username = ask_for_github_username
        save_github_username
      end
    end

    def save_github_username
      task_id = api.update_user(@mortar_user['user_id'], {'user_github_username' => @github_username}).body['task_id']

      task_result = nil
      user_result = nil
      ticking(polling_interval) do |ticks|
        task_result = api.get_task(task_id).body
        is_finished =
          Mortar::API::Task::STATUSES_COMPLETE.include?(task_result["status_code"])
        if is_finished
          user_result = api.get_user().body
        end

        redisplay("Setting github username: %s" % 
          [is_finished ? " Done!" : spinner(ticks)],
          is_finished) # only display newline on last message
        if is_finished
          display
          break
        end
      end

      case task_result['status_code']
      when Mortar::API::Task::STATUS_FAILURE
        error_message = "Setting github username failed with #{task_result['error_type'] || 'error'}"
        error_message += ":\n\n#{task_result['error_message']}\n\n"
        output_with_bang error_message
        raise Mortar::CLI::Errors::InvalidGithubUsername.new
      when Mortar::API::Task::STATUS_SUCCESS
        display "Successfully set github username." 

        if user_result['github_team_state'] == 'pending'
          display pending_github_team_state_message(user_result['github_accept_invite_url'])
        end
      else
        #Raise error so .netrc file is wiped out.
        raise RuntimeError, "Unknown task status: #{task_result['status_code']}"
      end
    end

    
    def retry_login?
      @login_attempts ||= 0
      @login_attempts += 1
      @login_attempts < 3
    end

    def retry_set_github_username?
      @set_github_username_attempts ||= 0
      @set_github_username_attempts += 1
      @set_github_username_attempts < 3
    end

    def polling_interval
      (2.0).to_f
    end
    

    protected

    def default_params
      full_host  = (host =~ /^http/) ? host : "https://api.#{host}"
      verify_ssl = ENV['MORTAR_SSL_VERIFY'] != 'disable' && full_host =~ %r|^https://api.mortardata.com|
      uri = URI(full_host)
      {
        :headers          => {
          'User-Agent'    => Mortar::USER_AGENT
        },
        :host             => uri.host,
        :port             => uri.port.to_s,
        :scheme           => uri.scheme,
        :ssl_verify_peer  => verify_ssl
      }
    end
  end
end

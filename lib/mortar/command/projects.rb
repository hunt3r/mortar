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

require "mortar/command"
require "mortar/command/base"
require "mortar/git"

# manage projects (create, register, clone, delete, set_remote)
#
class Mortar::Command::Projects < Mortar::Command::Base
  
  # projects
  #
  # Display the available set of Mortar projects.
  def index
    validate_arguments!
    projects = api.get_projects().body["projects"]
    if projects.any?
      styled_header("projects")
      styled_array(projects.collect{ |x| x["name"] })
    else
      display("You have no projects.")
    end
  end

  # projects:list
  #
  # Display the available set of Mortar projects.
  def list
    index
  end
  
  # projects:delete PROJECTNAME
  #
  # Delete the Mortar project PROJECTNAME.
  def delete
    name = shift_argument
    unless name
      error("Usage: mortar projects:delete PROJECTNAME\nMust specify PROJECTNAME.")
    end
    validate_arguments!
    projects = api.get_projects().body['projects']
    project_id = nil
    if projects.any?
      projects.each do |project|
        if project['name'] == name
          project_id = project['project_id']
        end
      end
    end

    if project_id.nil?
      display "\nNo project with name: #{name}"
    else
      # delete embedded project mirror if one exists
      mirror_dir = "#{git.mortar_mirrors_dir()}/#{name}"
      if File.directory? mirror_dir
        FileUtils.rm_r mirror_dir
      end

      # delete Mortar remote
      action("Sending request to delete project: #{name}") do
        api.delete_project(project_id).body['project_id']
      end
      display "\nYour project has been deleted."
    end
    
  end
  
  # projects:create PROJECTNAME
  #
  # Used when you want to start a new Mortar project using Mortar generated code.
  #
  # --embedded    # Create a Mortar project that is not its own git repo. Your code will still be synced with a git repo in the cloud.
  # --public      # Register a public project, which can be viewed and forked by anyone.
  #
  def create
    name = shift_argument
    unless name
      error("Usage: mortar projects:create PROJECTNAME\nMust specify PROJECTNAME")
    end

    args = [name,]
    is_public = false 
    if options[:public]
      is_public= true
      ask_public(is_public)
    end 
    validate_project_name(name)
    validate_github_username

    project_id = register_api_call(name,is_public) 
    Mortar::Command::run("generate:project", [name])
    FileUtils.cd(name)
    is_embedded = false
    if options[:embedded]
      is_embedded = true
      register_do(name, is_public, is_embedded, project_id)
    else
      git.git_init
      git.git("add .")
      git.git("commit -m \"Mortar project scaffolding\"")      
      register_do(name, is_public, is_embedded, project_id)
      display "NOTE: You'll need to change to the new directory to use your project:\n    cd #{name}\n\n"
    end
  end
  alias_command "new", "projects:create"
  
  # projects:register PROJECTNAME
  #
  # Used when you want to start a new Mortar project using your existing code in the current directory.
  #
  # --embedded    # Register code that is not its own git repo as a Mortar project. Your code will still be synced with a git repo in the cloud.
  # --public      # Register a public project, which can be viewed and forked by anyone.
  #
  def register
    name = shift_argument
    unless name
      error("Usage: mortar projects:register PROJECT\nMust specify PROJECT.")
    end
    validate_arguments!
    ask_public(options[:public])
    #nil is non existant project_id because it hasn't been posted yet
    register_do(name, options[:public], options[:embedded], nil) 
    
  end
  alias_command "register", "projects:register"


  # projects:set_remote PROJECTNAME
  #
  # Used after you checkout code for an existing Mortar project from a non-Mortar git repository.  
  # Adds a remote to your local git repository to the Mortar git repository.  For example if a 
  # co-worker creates a Mortar project from an internal repository you would clone the internal
  # repository and then after cloning call mortar projects:set_remote.
  #
  # --embedded    # make this a embedded project tied to the specified remote
  #
  def set_remote
    project_name = shift_argument

    unless project_name
      error("Usage: mortar projects:set_remote PROJECT\nMust specify PROJECT.")
    end

    unless options[:embedded]
      unless git.has_dot_git?
        error("Can only set the remote for an existing git project.  Please run:\n\ngit init\ngit add .\ngit commit -a -m \"first commit\"\n\nto initialize your project in git.")
      end

      if git.remotes(git_organization).include?("mortar")
        display("The remote has already been set for project: #{project_name}")
        return
      end
    end

    projects = api.get_projects().body["projects"]
    project = projects.find { |p| p['name'] == project_name}
    unless project
      error("No project named: #{project_name} exists. You can create this project using:\n\n mortar projects:create")
    end

    if options[:embedded]
      File.open(".mortar-project-remote", "w") do |f|
        f.puts project["git_url"]
      end
      git.sync_embedded_project(project, embedded_project_user_branch, git_organization)
    else
      git.remote_add("mortar", project["git_url"])
    end

    display("Successfully added the mortar remote to the #{project_name} project")

  end
  
  # projects:clone PROJECTNAME
  #
  # Used when you want to clone an existing Mortar project into the current directory.
  def clone
    name = shift_argument
    unless name
      error("Usage: mortar projects:clone PROJECT\nMust specify PROJECT.")
    end
    validate_arguments!
    validate_github_username
    projects = api.get_projects().body["projects"]
    project = projects.find{|p| p['name'] == name}
    unless project
      error("No project named: #{name} exists.  Your valid projects are:\n#{projects.collect{ |x| x["name"]}.join("\n")}")
    end

    project_dir = File.join(Dir.pwd, project['name'])
    unless !File.exists?(project_dir)
      error("Can't clone project: #{project['name']} since directory with that name already exists.")
    end

    git.clone(project['git_url'], project['name'])

    display "\nYour project is ready for use.  Type 'mortar help' to see the commands you can perform on the project.\n\n"
  end


  # projects:fork GIT_URL PROJECT_NAME
  #
  # Used when you want to fork an existing Git repository into your own Mortar project.
  #
  # --public      # Register a public project, which can be viewed and forked by anyone.
  #
  def fork
    git_url = shift_argument
    name = shift_argument
    unless git_url and name
      error("Usage: mortar projects:fork GIT_URL PROJECT\nMust specify GIT_URL and PROJECT.")
    end
    validate_arguments!
    validate_project_name(name)
    validate_github_username

    if git.has_dot_git?
      begin
        error("Currently in git repo.  You can not fork a new project inside of an existing git repository.")
      rescue Mortar::Command::CommandFailed => cf
        error("Currently in git repo.  You can not fork a new project inside of an existing git repository.")
      end
    end
    is_public = options[:public]
    ask_public(is_public)
    git.clone(git_url, name, git.fork_base_remote_name)
    Dir.chdir(name)
    # register a nil project id because it hasn't been created yet
    register_project(name, is_public, nil) do |project_result|
      git.remote_add("mortar", project_result['git_url'])
      git.push_master
      # We want the default remote to be the Mortar managed repo.
      git.git("fetch --all")
      git.set_upstream('mortar/master')
      display "Your project is ready for use.  Type 'mortar help' to see the commands you can perform on the project.\n\n"
    end
  end
  alias_command "fork", "projects:fork"

end

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

$stdin = File.new("/dev/null")

require "rubygems"
require "vendor/mortar/uuid"

require "excon"
Excon.defaults[:mock] = true

# ensure these are around for errors
# as their require is generally deferred
require "mortar-api-ruby"

require "mortar/cli"
require "mortar/git"
require "rspec"
require "rr"
require "fakefs/dir"
require "fakefs/safe"
require 'tmpdir'

def execute(command_line, project=nil, git=nil)
  stderr, stdout, command = execute_and_return_command(command_line, project, git)  
  [stderr, stdout]
end

def execute_and_return_command(command_line, project=nil, git=nil)
  args = command_line.split(" ")
  command = args.shift

  Mortar::Command.load
  object, method = Mortar::Command.prepare_run(command, args)

  # stub the project
  if project
    any_instance_of(Mortar::Command::Base) do |base|
      stub(base).project.returns(project)
    end
  end

  # stub the relative paths which get messed up in tests
  any_instance_of(Mortar::Project::PigScript) do |s|
    stub(s).rel_path.returns('pigscripts')
  end
  any_instance_of(Mortar::Project::ControlScript) do |s|
    stub(s).rel_path.returns('controlscripts')
  end


  # stub git
  if git
    # stub out any operations that affect remote resources
    stub(git).push
    
    any_instance_of(Mortar::Command::Base) do |base|
      stub(base).git.returns(git)
      stub(base).git_organization.returns("mortarcode-dev")
    end
  end

  original_stdin, original_stderr, original_stdout = $stdin, $stderr, $stdout

  $stdin  = captured_stdin  = StringIO.new
  $stderr = captured_stderr = StringIO.new
  $stdout = captured_stdout = StringIO.new


  begin
    object.send(method)
  rescue SystemExit
  ensure
    $stdin, $stderr, $stdout = original_stdin, original_stderr, original_stdout
    Mortar::Command.current_command = nil
  end

  [captured_stderr.string, captured_stdout.string, object]
end

def any_instance_of(klass, &block)
  any_instance_of(klass, &block)
end

def run(command_line)
  capture_stdout do
    begin
      Mortar::CLI.start(*command_line.split(" "))
    rescue SystemExit
    end
  end
end

alias mortar run

def capture_stderr(&block)
  original_stderr = $stderr
  $stderr = captured_stderr = StringIO.new
  begin
    yield
  ensure
    $stderr = original_stderr
  end
  captured_stderr.string
end

def capture_stdout(&block)
  original_stdout = $stdout
  $stdout = captured_stdout = StringIO.new
  begin
    yield
  ensure
    $stdout = original_stdout
  end
  captured_stdout.string
end

def fail_command(message)
  raise_error(Mortar::Command::CommandFailed, message)
end

def stub_core
  @stubbed_core ||= begin
    stubbed_core = nil
    stub(Mortar::Auth).user.returns("email@example.com")
    stub(Mortar::Auth).password.returns("pass")
    stubbed_core
  end
end

def with_no_git_directory(&block)
  starting_dir = Dir.pwd
  sandbox = File.join(Dir.tmpdir, "mortar", Mortar::UUID.create_random.to_s)
  FileUtils.mkdir_p(sandbox)
  Dir.chdir(sandbox)
  
  begin
    block.call()
  ensure
    # return to the original starting dir,
    # if one is defined.  If using FakeFS, it will not
    # be defined
    if starting_dir && (! starting_dir.empty?)
      Dir.chdir(starting_dir)
    end

    FileUtils.rm_rf(sandbox)
  end
end

def with_blank_project(&block)
  with_blank_project_with_name("myproject", &block)
end

def with_blank_project_with_name(name, &block)
  # setup a sandbox directory
  starting_dir = Dir.pwd
  sandbox = File.join(Dir.tmpdir, "mortar", Mortar::UUID.create_random.to_s)
  FileUtils.mkdir_p(sandbox)
  
  # setup project directory
  project_name = name
  project_path = File.join(sandbox, project_name)
  FileUtils.mkdir_p(project_path)
  
  # setup project subdirectories
  FileUtils.mkdir_p(File.join(project_path, "pigscripts"))
  FileUtils.mkdir_p(File.join(project_path, "macros"))
  FileUtils.mkdir_p(File.join(project_path, "udfs"))
  FileUtils.mkdir_p(File.join(project_path, "udfs/python"))
  FileUtils.mkdir_p(File.join(project_path, "udfs/jython"))
  FileUtils.mkdir_p(File.join(project_path, "udfs/java"))

  Dir.chdir(project_path)
  
  # initialize git repo
  `git init`
  
  project = Mortar::Project::Project.new(project_name, project_path, nil)
  
  begin
    block.call(project)
  ensure
    # return to the original starting dir,
    # if one is defined.  If using FakeFS, it will not
    # be defined
    if starting_dir && (! starting_dir.empty?)
      Dir.chdir(starting_dir)
    end

    FileUtils.rm_rf(sandbox)
  end
end

def with_forked_git_project(&block)
  with_git_initialized_project do |project|
    git = Mortar::Git::Git.new
    remote = git.fork_base_remote_name
    `git remote add #{remote} git@github.com:mortarcode-dev/fork_#{project.name}.git`
    block.call(project)
  end
end

def with_git_initialized_project(&block)
  remote_prefix = "4dbbd83cae8d5bf8a4000000_"
  with_git_initialized_project_with_remote_prefix(remote_prefix, &block)
end

def with_git_initialized_project_with_remote_prefix(remote_prefix, name="myproject", &block)
    # wrap block in a proc that does a commit
  commit_proc = Proc.new do |project|
    git = Mortar::Git::Git.new
    git.create_mortar_project_manifest(project.root_path)

    remote = "mortar"
    `git add project.manifest`
    `git commit -a -m "First commit"`
    `git remote add #{remote} git@github.com:mortarcode-dev/#{remote_prefix}#{project.name}.git`
    project.remote = remote
    block.call(project)
  end
  
  with_blank_project_with_name(name, &commit_proc)
end

def with_embedded_project(&block)
  with_blank_project do |project|
    File.open(File.join(project.root_path, ".mortar-project-remote"), "w") do |f|
      f.puts "git@github.com:mortarcode-dev/4dbbd83cae8d5bf8a4000000_#{project.name}.git"
    end
    block.call(project)
  end
end

def write_file(path, contents="")
  FileUtils.mkdir_p File.dirname(path)
  File.open(path, 'w') {|f| f.write(contents)}
end

def git_create_conflict(git, project)
  filename = "conflict_file.txt"
  
  # add to master
  git.git("checkout master")
  write_file(File.join(project.root_path, filename), Mortar::UUID.create_random.to_s)
  git.add(filename)
  git.git("commit -a -m \"initial\"")
  
  # checkin change on branch
  git.git("checkout -b conflict_branch")
  write_file(File.join(project.root_path, filename), Mortar::UUID.create_random.to_s)
  git.add(filename)
  git.git("commit -a -m \"conflict from branch\"")
  
  # checkin change on master
  git.git("checkout master")
  write_file(File.join(project.root_path, filename), Mortar::UUID.create_random.to_s)
  git.add(filename)
  git.git("commit -a -m \"conflict from master\"")
  
  # merge
  git.git("merge conflict_branch", check_success=false)
  
  filename
end

def create_fake_gem(path)
  mortar_fake_gem = <<-EOS
Gem::Specification.new do |s|
  s.name = "mortar_fake_gem"
  s.version = "0.0.1"
  s.summary = "mortar_fake_gem is the best"
  s.files = [
    "lib/mortar_fake_gem.rb"
  ]
  s.require_paths = ["lib"]
end
EOS
  
  mortar_fake_gem_rb = <<-EOS
module MortarFakeGem
  class WhoIs
    def self.awesome?
      return true
    end
  end
end
EOS

  files = { 
    "mortar_fake_gem.gemspec" => mortar_fake_gem,
    "lib/mortar_fake_gem.rb" => mortar_fake_gem_rb,
  }

  FileUtils.mkdir_p(File.join(path, "mortar_fake_gem/lib"))
  files.each { |file_name, contents|
    File.open(File.join(path, "/mortar_fake_gem/#{file_name}"), 'w') do |f|
      f.puts contents
    end
  }

  return File.join(path, "mortar_fake_gem")

end

def git_add_file(git, project)
  # add a new file
  added_file = "added_file.txt"
  write_file(File.join(project.root_path, added_file))
  git.add(added_file)
  added_file
end

def git_create_untracked_file(project)
  # add an untracked file
  untracked_file = "untracked_file.txt"
  write_file(File.join(project.root_path, untracked_file))
  untracked_file
end

def create_and_validate_git_snapshot(git)
  initial_status = git.status
  initial_git_branches = git.branches
  snapshot_dir, snapshot_branch = git.create_snapshot_branch

  snapshot_dir.should_not be_nil
  snapshot_branch.should_not be_nil
  snapshot_branch.should_not == "master"
  git.current_branch.should == "master"
  git.status.should == initial_status
  git.has_conflicts?.should be_false

  # ensure snapshot is in a temp directory
  File.exists?(snapshot_dir).should be_true

  curdir = Dir.pwd
  Dir.chdir(snapshot_dir)
  
  # ensure the snapshot branch exists
  git.git("branch").include?(snapshot_branch).should be_true

  snapshotted_paths = Dir.glob("**/*")
  snapshotted_paths.should include("pigscripts")
  snapshotted_paths.should include("macros")
  snapshotted_paths.should include("udfs/python")
  snapshotted_paths.should include("udfs/jython")
  snapshotted_paths.should include("udfs/java")

  Dir.chdir(curdir)
  FileUtils.remove_entry_secure(snapshot_dir)
end


require "mortar/helpers"
module Mortar::Helpers
  @home_directory = Dir.mktmpdir
  undef_method :home_directory
  def home_directory
    @home_directory
  end
end

require "support/display_message_matcher"

# Dir.exists? wasn't added until ruby 1.9.x, but FakeFS includes this
# method regardless of ruby version. Monkey patching it away for now to
# prevent false positive test passes.
if RUBY_VERSION == "1.8.7"
  module FakeFS
    class <<Dir
      remove_method :exists?
    end
  end
end

RSpec.configure do |config|
  config.mock_with :rr
  config.color_enabled = true
  config.filter_run_excluding :broken => true
  config.include DisplayMessageMatcher
  config.before { Mortar::Helpers.error_with_failure = false }
  config.after { RR.verify; RR.reset }
end


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
require "mortar/git"
require "mortar/helpers"

module Mortar

  describe Git do
    
    before do
      @git = Mortar::Git::Git.new
    end

    context "has_git?" do
      it "returns false with no git installed" do
        mock(@git).run_cmd("git --version").returns(["-bash: git: command not found",-1])
        @git.has_git?.should be_false
      end

      it "returns false with unsupported git version" do
        mock(@git).run_cmd("git --version").returns(["git version 1.7.6",0])
        @git.has_git?.should be_false
      end

      it "returns true with supported git version 2.0.0" do
        mock(@git).run_cmd("git --version").returns(["git version 2.0.0", 0])
        @git.has_git?.should be_true
      end

      it "returns true with supported git version 1.8.0" do
        mock(@git).run_cmd("git --version").returns(["git version 1.8.0", 0])
        @git.has_git?.should be_true 
      end

      it "returns false with unsupported git version" do
        @git.has_git?.should be_true
      end

      it "returns true with supported version with params" do
        mock(@git).run_cmd("git --version").returns(["git version 1.8.0", 0])
        @git.has_git?(major_version=1,minor_version=8,revision_version=0).should be_true
      end

      it "returns false with unsupported version with params" do
        mock(@git).run_cmd("git --version").returns(["git version 1.7.12", 0])
        @git.has_git?(major_version=1,minor_version=8,revision_version=0).should be_false
      end

    end
    
    context "has_any_commits" do
      
      it "finds no commits on a blank project" do
        with_blank_project do |p|
          @git.has_commits?.should be_false
        end
      end
      
      it "finds commits when a project has them" do
        with_git_initialized_project do |p|
          @git.has_commits?.should be_true
        end
      end
    end
    
    context "git-rev" do
      it "looks up a revision" do
        with_git_initialized_project do |p|
          @git.git_ref("master").nil?.should be_false
        end
      end
    end
    
    context "git" do
      
      it "raises on git failure" do
        with_blank_project do |p|
          lambda { @git.git("not_a_git_command") }.should raise_error(Mortar::Git::GitError)
        end
      end

      it "does not raise on git success" do
        with_blank_project do |p|
          lambda { @git.git("--version") }.should_not raise_error
        end
      end

      it "raises error on no .git file" do
        with_no_git_directory do
          lambda {@git.git("--version") }.should raise_error(Mortar::Git::GitError)
        end
      end
      
      it "does not raise error on no .git file with check disabled" do
        with_no_git_directory do
          lambda {@git.git("--version", true, false) }.should_not raise_error(Mortar::Git::GitError)
        end
      end
            
    end
    
    context "working directory" do
      it "finds clean and dirty working directories" do
        with_git_initialized_project do |p|
          @git.is_clean_working_directory?.should be_true
          write_file(File.join(p.root_path, "new_file.txt"))
          @git.is_clean_working_directory?.should be_false
        end
      end
    end
    
    context "untracked_files" do
      it "does not find ignored files" do
        with_git_initialized_project do |p|
          write_file(File.join(p.root_path, ".gitignore"), "tmp\n")
          write_file(File.join(p.root_path, "tmp", "ignored_file.txt"), "some text")
          write_file(File.join(p.root_path, "included_file.txt"), "some text")
          untracked_files = @git.untracked_files
          untracked_files.include?(".gitignore").should be_true
          untracked_files.include?("included_file.txt").should be_true
          untracked_files.include?("tmp/ignored_file.txt").should be_false
        end
      end
    end
    
    context "stash" do
      context "did_stash_changes" do
        it "finds that no changes were stashed" do
          with_git_initialized_project do |p|
            @git.did_stash_changes?("No local changes to save").should be_false
          end
        end
        
        it "finds that changes were stashed" do
          stash_message = <<-STASH
Saved working directory and index state On master: myproject
HEAD is now at f3d74e8 Add an example
STASH
          @git.did_stash_changes?(stash_message).should be_true
        end
      end
      
      context "stash_working_dir" do
        it "does not error on a clean working directory" do
          with_git_initialized_project do |p|
            @git.stash_working_dir("my_description").should be_false
          end
        end
        
        it "stashes an added file" do
          with_git_initialized_project do |p|
            git_add_file(@git, p)
            @git.is_clean_working_directory?.should be_false
            
            # stash
            @git.stash_working_dir("my_description").should be_true
            @git.is_clean_working_directory?.should be_true
          end
        end
        
        it "stashes an untracked file" do
          with_git_initialized_project do |p|
            git_create_untracked_file(p)
            @git.is_clean_working_directory?.should be_false
            
            # stash
            @git.stash_working_dir("my_description").should be_true
            @git.is_clean_working_directory?.should be_true
          end
        end
      end
    end
    
    context "branch" do
      
      it "fetches current branch with one branch" do
        with_git_initialized_project do |p|
          @git.current_branch.should == "master"
        end
      end
      
      it "fetches current branch with multiple branches" do
        with_git_initialized_project do |p|
          @git.git("checkout -b branch_01")
          @git.git("checkout -b branch_02")
          @git.current_branch.should == "branch_02"
        end
      end
      
      it "raises if no branches found" do
        with_blank_project do |p|
          lambda { @git.current_branch }.should raise_error(Mortar::Git::GitError)
        end
      end
      
      it "deletes a branch" do
        with_git_initialized_project do |p|
          new_branch_name = "new_branch_to_delete"
          @git.current_branch.should == "master"
          @git.git("checkout -b #{new_branch_name}")
          @git.branches.include?(new_branch_name).should be_true
          @git.git("checkout master")
          @git.branch_delete(new_branch_name)
          @git.branches.include?(new_branch_name).should be_false
          @git.current_branch.should == "master"
        end
      end
    end
    
    context "remotes" do
      it "handles when no remotes are defined" do
        with_git_initialized_project do |p|
          @git.git("remote rm mortar")
          @git.remotes("mortarcode").empty?.should be_true
        end
      end
      
      it "finds a single remote" do
        with_git_initialized_project do |p|
          remotes = @git.remotes("mortarcode-dev")
          remotes["mortar"].should == p.name
        end
      end

      it "finds new style project name remote" do
        with_git_initialized_project_with_remote_prefix("", "myproject") do |p|
          remotes = @git.remotes("mortarcode-dev")
          remotes["mortar"].should == p.name
        end
      end

      it "finds new style project name remote with underscore" do
        with_git_initialized_project_with_remote_prefix("", "my_project") do |p|
          remotes = @git.remotes("mortarcode-dev")
          remotes["mortar"].should == p.name
        end
      end
      
    end
    
    context "status" do
      it "detects conflicts" do
        with_git_initialized_project do |p|
          
          @git.is_clean_working_directory?.should be_true
          @git.has_conflicts?.should be_false
          git_create_conflict(@git, p)
          @git.is_clean_working_directory?.should be_false
          @git.has_conflicts?.should be_true
        end
      end
      
      it "detects no conflicts" do
        with_git_initialized_project do |p|
          @git.has_conflicts?.should be_false
        end
      end
    end
    
    context "snapshot with git project" do
      it "raises when no commits are found in the repo" do
        with_blank_project do |p|
          lambda { @git.create_snapshot_branch }.should raise_error(Mortar::Git::GitError)
        end
      end
      
      it "raises when a conflict exists in working directory" do
         with_git_initialized_project do |p|
           git_create_conflict(@git, p)
           lambda { @git.create_snapshot_branch }.should raise_error(Mortar::Git::GitError)
         end
      end
      
      it "creates a snapshot branch for a clean working directory" do
        with_git_initialized_project do |p|
          create_and_validate_git_snapshot(@git)
        end
      end
      
      it "creates a snapshot branch for an added file" do
        with_git_initialized_project do |p|
          git_add_file(@git, p)
          create_and_validate_git_snapshot(@git)
        end
      end
      
      it "creates a snapshot branch for an untracked file" do
        with_git_initialized_project do |p|
          git_create_untracked_file(p)
          create_and_validate_git_snapshot(@git)
        end
      end
      
      it "retries pushing the snapshot branch if there is a socket error" do
        with_git_initialized_project do |p|
          # RR seems to only count a method as being called if it completes
          # So we expect "never", even though it's actually tried N times (tested below)
          mock(@git).push.never { raise Exception.new }
          mock(@git).sleep.times(10).with_any_args

          original_stdin, original_stderr, original_stdout = $stdin, $stderr, $stdout
          $stdin, $stderr, $stdout = StringIO.new, StringIO.new, StringIO.new

          begin
            @git.create_and_push_snapshot_branch(p)
          rescue SystemExit
          ensure
            $stdin, $stderr, $stdout = original_stdin, original_stderr, original_stdout
          end
        end
      end
    end

    # we manually create and destroy "mirror_dir" instead of using FakeFS
    # because FakeFS doesn't clean up properly when you use Dir.chdir inside of it
    context "snapshot with embedded project" do

      it "creates a mirror directory for the project when one does not already exist" do
        with_embedded_project do |p|
          mirror_dir = File.join(Dir.tmpdir, "mortar", "test-git-mirror")
          FileUtils.rm_rf(mirror_dir)
          mock(@git).mortar_mirrors_dir.any_times { mirror_dir }

          mock(@git).git.with_any_args.any_times { true }
          mock(@git).remotes.with_any_args.any_times { {"origin"=> "git@github.com:mortarcode-dev/4dbbd83cae8d5bf8a4000000_#{p.name}.git"} }
          mock(@git).clone.with_any_args.times(1) { FileUtils.mkdir("#{mirror_dir}/#{p.name}") }
          mock(@git).push_with_retry.with_any_args.times(3) { true }
          mock(@git).is_clean_working_directory? { false }
          mock(@git).did_stash_changes?.with_any_args.any_times { false }
          mock(@git).branches.any_times { "master" }
          mock(@git).all_branches.any_times { "master\nremotes/mortar/master" }
          
          @git.sync_embedded_project(p, "master", "mortarcode-dev")

          File.directory?(mirror_dir).should be_true
          FileUtils.rm_rf(mirror_dir)
        end
      end

      it "recreates an empty mirror directory" do
        with_embedded_project do |p|
          mirror_dir = File.join(Dir.tmpdir, "mortar", "test-git-mirror")
          FileUtils.rm_rf(mirror_dir)

          # only create top-level directory, but don't add contents.
          # this can happen when tmp is cleaned
          project_mirror_dir = File.join(mirror_dir, p.name)
          FileUtils.mkdir_p(project_mirror_dir)

          mock(@git).mortar_mirrors_dir.any_times { mirror_dir }

          mock(@git).git.with_any_args.any_times { true }
          mock(@git).remotes.with_any_args.any_times { {"origin"=> "git@github.com:mortarcode-dev/4dbbd83cae8d5bf8a4000000_#{p.name}.git"} }
          mock(@git).clone.with_any_args.times(1) { FileUtils.mkdir("#{mirror_dir}/#{p.name}") }
          mock(@git).push_with_retry.with_any_args.times(3) { true }
          mock(@git).is_clean_working_directory? { false }
          mock(@git).did_stash_changes?.with_any_args.any_times { false }
          mock(@git).branches.any_times { "master" }
          mock(@git).all_branches.any_times { "master\nremotes/mortar/master" }
          
          @git.sync_embedded_project(p, "master", "mortarcode-dev")

          File.directory?(mirror_dir).should be_true
          FileUtils.rm_rf(mirror_dir)
        end
      end

      it "recreates an empty mirror .git directory" do
        with_embedded_project do |p|
          mirror_dir = File.join(Dir.tmpdir, "mortar", "test-git-mirror")
          FileUtils.rm_rf(mirror_dir)

          # create .git directory in project, but make it empty
          project_mirror_dit_dir = File.join(mirror_dir, p.name, ".git")
          FileUtils.mkdir_p(project_mirror_dit_dir)

          mock(@git).mortar_mirrors_dir.any_times { mirror_dir }

          mock(@git).git.with_any_args.any_times { true }
          mock(@git).remotes.with_any_args.any_times { {"origin"=> "git@github.com:mortarcode-dev/4dbbd83cae8d5bf8a4000000_#{p.name}.git"} }
          mock(@git).clone.with_any_args.times(1) { FileUtils.mkdir("#{mirror_dir}/#{p.name}") }
          mock(@git).push_with_retry.with_any_args.times(3) { true }
          mock(@git).is_clean_working_directory? { false }
          mock(@git).did_stash_changes?.with_any_args.any_times { false }
          mock(@git).branches.any_times { "master" }
          mock(@git).all_branches.any_times { "master\nremotes/mortar/master" }
          
          @git.sync_embedded_project(p, "master", "mortarcode-dev")

          File.directory?(mirror_dir).should be_true
          FileUtils.rm_rf(mirror_dir)
        end
      end

      it "syncs files to the project mirror" do
        with_embedded_project do |p|
          mirror_dir = File.join(Dir.tmpdir, "mortar", "test-git-mirror")
          FileUtils.rm_rf(mirror_dir)
          mock(@git).mortar_mirrors_dir.any_times { mirror_dir }

          project_mirror_dir = File.join(mirror_dir, p.name)
          project_mirror_git_dir = File.join(project_mirror_dir, ".git")
          FileUtils.mkdir_p(project_mirror_git_dir)
          FileUtils.touch(File.join(project_mirror_git_dir, "index"))
          FileUtils.touch("#{p.root_path}/pigscripts/calydonian_boar.pig")

          mock(@git).git.with_any_args.any_times { true }
          mock(@git).remotes.with_any_args.any_times { {"origin"=> "git@github.com:mortarcode-dev/4dbbd83cae8d5bf8a4000000_#{p.name}.git"} }
          mock(@git).clone.with_any_args.never
          mock(@git).push_with_retry.with_any_args.times(2) { true }
          mock(@git).is_clean_working_directory? { false }
          mock(@git).did_stash_changes?.with_any_args.any_times { true }
          mock(@git).branches.any_times { "master" }
          mock(@git).all_branches.any_times { "master\nremotes/mortar/master" }

          @git.sync_embedded_project(p, "bob-the-builder-base", "mortarcode-dev")

          File.exists?("#{project_mirror_dir}/pigscripts/calydonian_boar.pig").should be_true
          FileUtils.rm_rf(mirror_dir)
        end
      end

      it "syncs deleted files to the project mirror" do
        with_embedded_project do |p|
          mirror_dir = File.join(Dir.tmpdir, "mortar", "test-git-mirror")
          FileUtils.rm_rf(mirror_dir)
          mock(@git).mortar_mirrors_dir.any_times { mirror_dir }

          project_mirror_dir = File.join(mirror_dir, p.name)
          project_mirror_git_dir = File.join(project_mirror_dir, ".git")
          FileUtils.mkdir_p(project_mirror_git_dir)
          FileUtils.touch(File.join(project_mirror_git_dir, "index"))
          FileUtils.cp_r(Dir.glob("#{p.root_path}/*"), project_mirror_dir)
          FileUtils.touch("#{project_mirror_dir}/pigscripts/calydonian_boar.pig")

          mock(@git).git.with_any_args.any_times { true }
          mock(@git).remotes.with_any_args.any_times { {"origin"=> "git@github.com:mortarcode-dev/4dbbd83cae8d5bf8a4000000_#{p.name}.git"} }
          mock(@git).clone.with_any_args.never
          mock(@git).push_with_retry.with_any_args.times(2) { true }
          mock(@git).is_clean_working_directory? { false }
          mock(@git).did_stash_changes?.with_any_args.any_times { true }
          mock(@git).branches.any_times { "master" }
          mock(@git).all_branches.any_times { "master\nremotes/mortar/master" }

          @git.sync_embedded_project(p, "bob-the-builder-base", "mortarcode-dev")

          File.exists?("#{project_mirror_dir}/pigscripts/calydonian_boar.pig").should be_false
          FileUtils.rm_rf(mirror_dir)
        end
      end
    end

    context "checking updates for forked projects" do
      it "skips non forked projects" do
        with_git_initialized_project do |p|
          @git.is_fork_repo_updated("mortarcode-dev").should be_false
        end
      end

      it "returns true with no .mortar-fork file and new commits" do
        with_forked_git_project do |p|
          mock(@git).fetch(@git.fork_base_remote_name)
          new_commit_hash = "ANewCommitHash"
          mock(@git).get_latest_hash(@git.fork_base_remote_name) {new_commit_hash}
          
          @git.is_fork_repo_updated("mortarcode-dev").should be_true
          File.exists?(@git.mortar_fork_meta_file).should be_true
          File.open(@git.mortar_fork_meta_file, "r") do |f|
            file_contents = f.read()
            file_contents.strip
            file_contents.eql?(new_commit_hash).should be_true
          end
        end
      end

      it "returns false with up to date .mortar-fork file and new commits" do
        with_forked_git_project do |p|
          mock(@git).fetch(@git.fork_base_remote_name)
          new_commit_hash = "ANewCommitHash"
          mock(@git).get_latest_hash(@git.fork_base_remote_name) {new_commit_hash}
          File.open(@git.mortar_fork_meta_file, "wb") do |f|
            f.write(new_commit_hash)
          end
          File.exists?(@git.mortar_fork_meta_file).should be_true
          
          @git.is_fork_repo_updated("mortarcode-dev").should be_false
        end
      end

      it "returns false with no .mortar-fork file and no new commits" do
        with_forked_git_project do |p|
          mock(@git).fetch(@git.fork_base_remote_name)
          current_latest_hash = @git.get_latest_hash("")
          mock(@git).get_latest_hash(@git.fork_base_remote_name) {current_latest_hash}
          
          @git.is_fork_repo_updated("mortarcode-dev").should be_false
        end
      end
    end 

    context "safe_copy for_snapshot" do
      it "safe copies properly" do 
        tmp_dir_src = Dir.mktmpdir
        Dir.chdir(tmp_dir_src)

        root_file = File.join("root_file")
        root_dir_file = File.join("root_dir", "root_dir_file")
        non_root_dir_file = File.join("dir", "non_root_dir", "non_root_dir_file")
        dir_file = File.join("dir", "dir_file")

        ex_root_file = File.join("excluded_root_file")
        ex_root_dir_file = File.join("excluded_dir", "excluded_dir_file")
        ex_dir_file = File.join("dir", "excluded_dir_file")
        ex_non_root_dir_file = File.join("dir", "excluded_non_root_dir", "excluded_non_root_dir_file")

        write_file(root_file)
        write_file(root_dir_file)
        write_file(non_root_dir_file)
        write_file(dir_file)
        write_file(ex_root_file)
        write_file(ex_root_dir_file)
        write_file(ex_dir_file)
        write_file(ex_non_root_dir_file)

        pathlist = ["root_file", "root_dir", "dir/non_root_dir", "dir/dir_file"]
        new_tmp_dir = @git.safe_copy(pathlist)

        Dir.chdir(new_tmp_dir)
        File.exists?(root_file).should be_true
        File.exists?(root_dir_file).should be_true
        File.exists?(non_root_dir_file).should be_true
        File.exists?(dir_file).should be_true

        File.exists?(ex_root_file).should be_false
        File.exists?(ex_root_dir_file).should be_false
        File.exists?(ex_dir_file).should be_false
        File.exists?(ex_non_root_dir_file).should be_false
      end
    end

      
=begin
    #TODO: Fix this.

    context "clone" do
      it "clones repo successfully" do
        with_no_git_directory do
          File.directory?("rollup").should be_false
          @git.clone("git@github.com:mortarcode-dev/4fbbd83cce875be8a4000000_rollup", "rollup")
          File.directory?("rollup").should be_true
          Dir.chdir("rollup")
          lambda { @git.git("--version") }.should_not raise_error
        end
      end
    end
=end
  end
end

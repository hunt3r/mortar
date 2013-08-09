require "spec_helper"
require "mortar/auth"
require "mortar/plugin"

module Mortar
  describe Plugin do
    
    it "lives in ~/.mortar/plugins" do
      stub(Mortar::Plugin).home_directory.returns '/home/user' 
      Plugin.directory.should == '/home/user/.mortar/plugins'
    end

    it "extracts the name from git urls" do
      Plugin.new('git://github.com/mortar/plugin.git').name.should == 'plugin'
    end

    describe "management" do
      before(:each) do
        @sandbox = "/tmp/mortar_plugins_spec_#{Process.pid}"
        FileUtils.mkdir_p(@sandbox)
        stub(Dir).pwd.returns @sandbox
        stub(Plugin).directory.returns @sandbox
      end

      after(:each) do
        FileUtils.rm_rf(@sandbox)
      end

      it "lists installed plugins" do
        FileUtils.mkdir_p(@sandbox + '/plugin1')
        FileUtils.mkdir_p(@sandbox + '/plugin2')
        Plugin.list.should include 'plugin1'
        Plugin.list.should include 'plugin2'
      end

      it "installs pulling from the plugin url" do
        plugin_folder = "/tmp/mortar_plugin"
        FileUtils.rm_rf(plugin_folder)
        FileUtils.mkdir_p(plugin_folder)
        `cd #{plugin_folder} && git init && echo 'test' > README && git add . && git commit -m 'my plugin'`
        Plugin.new(plugin_folder).install
        File.directory?("#{@sandbox}/mortar_plugin").should be_true
        File.read("#{@sandbox}/mortar_plugin/README").should == "test\n"
      end

      it "reinstalls over old copies" do
        plugin_folder = "/tmp/mortar_plugin"
        FileUtils.rm_rf(plugin_folder)
        FileUtils.mkdir_p(plugin_folder)
        `cd #{plugin_folder} && git init && echo 'test' > README && git add . && git commit -m 'my plugin'`
        Plugin.new(plugin_folder).install
        Plugin.new(plugin_folder).install
        File.directory?("#{@sandbox}/mortar_plugin").should be_true
        File.read("#{@sandbox}/mortar_plugin/README").should == "test\n"
      end

      context "update" do

        before(:each) do
          plugin_folder = "/tmp/mortar_plugin"
          FileUtils.mkdir_p(plugin_folder)
          `cd #{plugin_folder} && git init && echo 'test' > README && git add . && git commit -m 'my plugin'`
          Plugin.new(plugin_folder).install
          `cd #{plugin_folder} && echo 'updated' > README && git add . && git commit -m 'my plugin update'`
        end

        it "updates existing copies" do
          Plugin.new('mortar_plugin').update
          File.directory?("#{@sandbox}/mortar_plugin").should be_true
          File.read("#{@sandbox}/mortar_plugin/README").should == "updated\n"
        end

        it "raises exception on symlinked plugins" do
          `cd #{@sandbox} && ln -s mortar_plugin mortar_plugin_symlink`
          lambda { Plugin.new('mortar_plugin_symlink').update }.should raise_error Mortar::Plugin::ErrorUpdatingSymlinkPlugin
        end

      end


      it "uninstalls removing the folder" do
        FileUtils.mkdir_p(@sandbox + '/plugin1')
        Plugin.new('git://github.com/mortar/plugin1.git').uninstall
        Plugin.list.should == []
      end

      it "adds the lib folder in the plugin to the load path, if present" do
        FileUtils.mkdir_p(@sandbox + '/plugin/lib')
        File.open(@sandbox + '/plugin/lib/my_custom_plugin_file.rb', 'w') { |f| f.write "" }
        Plugin.load!
        $:.should include(@sandbox + '/plugin/lib')
      end

      it "loads init.rb, if present" do
        FileUtils.mkdir_p(@sandbox + '/plugin')
        File.open(@sandbox + '/plugin/init.rb', 'w') { |f| f.write "LoadedInit = true" }
        Plugin.load!
        LoadedInit.should be_true
      end

      describe "installing plugins with dependencies" do
        it "should install plugin dependencies" do
          ## Setup Fake Gem
          mortar_fake_gem_folder = create_fake_gem("/tmp")
          plugin_folder = "/tmp/mortar_plugin"
          FileUtils.mkdir_p(plugin_folder)
          File.open(plugin_folder + '/Gemfile', 'w') { |f|
            f.write "gem 'mortar_fake_gem', :path => '#{mortar_fake_gem_folder}'" 
          }
          File.open(plugin_folder + '/init.rb', 'w') { |f|
            f.write <<-EOS
require File.join(File.dirname(__FILE__), "bundle/bundler/setup")
require "mortar_fake_gem"

PluginTest = MortarFakeGem::WhoIs.awesome?
EOS
          }
          `cd #{plugin_folder} && git init && echo 'test' > README && git add . && git commit -m 'my plugin'`
          Plugin.new(plugin_folder).install
          File.directory?("#{@sandbox}/mortar_plugin").should be_true
          File.directory?("#{@sandbox}/mortar_plugin/bundle").should be_true
          File.exist?("#{@sandbox}/mortar_plugin/Gemfile").should be_true
          File.read("#{@sandbox}/mortar_plugin/README").should == "test\n"

          Plugin.load!
          PluginTest.should be_true
        end

        it "should fail to install plugin with bad dependencies" do
          mock(Plugin).install_bundle { system("exit 1") } 
          plugin_folder = "/tmp/mortar_plugin"
          FileUtils.mkdir_p(plugin_folder)
          File.open(plugin_folder + '/Gemfile', 'w') { |f| f.write "# dummy content" }
          `cd #{plugin_folder} && git init && echo 'test' > README && git add . && git commit -m 'my plugin'`
          lambda { Plugin.new(plugin_folder).install }.should raise_error Mortar::Plugin::ErrorInstallingDependencies
        end

        it "should have logs when bundle install fails" do
          plugin_folder = "/tmp/mortar_plugin"
          FileUtils.mkdir_p(plugin_folder)
          File.open(plugin_folder + '/Gemfile', 'w') { |f| f.write "non_existent_command" }
          `cd #{plugin_folder} && git init && echo 'test' > README && git add . && git commit -m 'my plugin'`
          lambda { Plugin.new(plugin_folder).install }.should raise_error Mortar::Plugin::ErrorInstallingDependencies 
          File.exists?("#{Plugin.directory}/plugin_install.log").should be_true
        end

        it "should clean plugin if bundler isn't installed" do
          class BundlerNotInstalledError < StandardError; end
          mock(Plugin).ensure_bundler_installed { raise BundlerNotInstalledError }
          plugin_folder = "/tmp/mortar_plugin"
          FileUtils.mkdir_p(plugin_folder)
          File.open(plugin_folder + '/Gemfile', 'w') { |f| f.write "# dummy content" }
          `cd #{plugin_folder} && git init && echo 'test' > README && git add . && git commit -m 'my plugin'`
          lambda { Plugin.new(plugin_folder).install }.should raise_error BundlerNotInstalledError 
          File.exist?("#{@sandbox}/mortar_plugin").should be_false
        end
      end

      describe "when there are plugin load errors" do
        before(:each) do
          FileUtils.mkdir_p(@sandbox + '/some_plugin/lib')
          File.open(@sandbox + '/some_plugin/init.rb', 'w') { |f| f.write "require 'some_non_existant_file'" }
        end

        it "should not throw an error" do
          capture_stderr do
            lambda { Plugin.load! }.should_not raise_error
          end
        end

        it "should fail gracefully" do
          stderr = capture_stderr do
            Plugin.load!
          end
          stderr.should include('some_non_existant_file (LoadError)')
        end

        it "should still load other plugins" do
          FileUtils.mkdir_p(@sandbox + '/some_plugin_2/lib')
          File.open(@sandbox + '/some_plugin_2/init.rb', 'w') { |f| f.write "LoadedPlugin2 = true" }
          stderr = capture_stderr do
            Plugin.load!
          end
          stderr.should include('some_non_existant_file (LoadError)')
          LoadedPlugin2.should be_true
        end
      end
    end
  end
end

require 'excon'

require "mortar/command/base"
require "mortar/helpers"

module Mortar::Command

  # manage plugins to the mortar gem
  class Plugins < Base

    # plugins
    #
    # list installed plugins
    #
    #Example:
    #
    # $ mortar plugins
    # === Installed Plugins
    # watchtower 
    #
    def index
      validate_arguments!

      plugins = ::Mortar::Plugin.list

      if plugins.length > 0
        styled_header("Installed Plugins")
        styled_array(plugins)
      else
        display("You have no installed plugins.")
      end
    end

    # plugins:install git@github.com:user/repo.git
    #
    # install a plugin
    #
    #Example:
    #
    # $ mortar plugins:install https://github.com/mortardata/watchtower.git
    # Installing watchtower... done
    #
    def install
      plugin = Mortar::Plugin.new(shift_argument)
      validate_arguments!

      action("Installing #{plugin.name}") do
        begin
          record_usage("plugin_install", plugin.name)
          plugin.install
          Mortar::Plugin.load_plugin(plugin.name)
        rescue StandardError => e
          error e.message
        end
      end
    end

    # plugins:uninstall PLUGIN
    #
    # uninstall a plugin
    #
    #Example:
    #
    # $ mortar plugins:uninstall watchtower
    # Uninstalling watchtower... done
    #
    def uninstall
      plugin = Mortar::Plugin.new(shift_argument)
      validate_arguments!

      action("Uninstalling #{plugin.name}") do
        begin
          record_usage("plugin_uninstall", plugin.name)
          plugin.uninstall
        rescue Mortar::Plugin::ErrorPluginNotFound => e
          error e.message
        end
      end
    end

    # plugins:update [PLUGIN]
    #
    # updates all plugins or a single plugin by name
    #
    #Example:
    #
    # $ mortar plugins:update
    # Updating watchtower... done
    #
    # $ mortar plugins:update watchtower
    # Updating watchtower... done
    #
    def update
      plugins = if plugin = shift_argument
        [plugin]
      else
        ::Mortar::Plugin.list
      end
      validate_arguments!

      plugins.each do |plugin|
        action("Updating #{plugin}") do
          begin
            record_usage("plugin_update", plugin)
            Mortar::Plugin.new(plugin).update
          rescue Mortar::Plugin::ErrorUpdatingSymlinkPlugin
            status "skipped symlink"
          rescue StandardError => e
            status "error"
            display e.message
          end
        end
      end
    end


    private

    def record_usage(usage_type, plugin_name)
      full_host  = (host =~ /^http/) ? host : "https://api.#{host}"
      url = full_host + "/usage/#{usage_type}"

      headers = {'User-Agent' => Mortar::USER_AGENT}
      query = {'plugin_name' => plugin_name}
      begin
        response = Excon.get(url, :headers => headers, :query => query)
      rescue
        #Don't block plugin if usage fails
      end

    end

  end
end

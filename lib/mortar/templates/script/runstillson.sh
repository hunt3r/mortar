#!/bin/bash

set -e

# Setup python environment
source <%= @local_install_dir %>/pythonenv/bin/activate

# template config file
export LUIGI_CONFIG_TEMPLATE_PATH=`pwd`/`dirname <%= @luigi_script %>`/client.cfg.template

# expanded config file
export LUIGI_CONFIG_PATH=`pwd`/`dirname <%= @luigi_script %>`/client.cfg

# Setup parameters in environment variables
<% @parameters.each do |p| %>
export <%= p['name'] %>="<%= p['value'] %>";
<% end %>

# Run stillson to expand the configuration template
if [ -f "$LUIGI_CONFIG_TEMPLATE_PATH" ] 
then 
    stillson "$LUIGI_CONFIG_TEMPLATE_PATH" -o $LUIGI_CONFIG_PATH
else
    echo "No luigi client configuration template found in expected location $LUIGI_CONFIG_TEMPLATE_PATH. Not expanding."
fi

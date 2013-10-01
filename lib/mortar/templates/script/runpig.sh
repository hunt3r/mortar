#!/bin/bash

set -e

export PIG_HOME=<%= @pig_home %>
export PIG_CLASSPATH=<%= @pig_classpath %>
export CLASSPATH=<%= @classpath %>
export PIG_MAIN_CLASS=com.mortardata.hawk.HawkMain
export PIG_OPTS="<% @pig_opts.each do |k,v| %>-D<%= k %>=<%= v %> <% end %>"

# UDF paths are relative to this direectory
cd <%= @project_home %>/pigscripts

# Setup python environment
source <%= @local_install_dir %>/pythonenv/bin/activate

# Run Pig
<%= @local_install_dir %>/pig-0.9.0/bin/pig -exectype local \
    -log4jconf <%= @local_install_dir %>/lib-common/conf/log4j-cli-local-dev.properties \
    -propertyFile <%= @local_install_dir %>/lib-common/conf/pig-hawk-global.properties \
    -propertyFile <%= @local_install_dir %>/lib-common/conf/pig-cli-local-dev.properties \
    -param_file <%= @pig_params_file %> \
    <%= @pig_sub_command %>

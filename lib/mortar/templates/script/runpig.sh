#!/bin/bash

set -e

export PIG_HOME=<%= @pig_home %>
export PIG_CLASSPATH=<%= @pig_classpath %>
export CLASSPATH=<%= @classpath %>
export PIG_MAIN_CLASS=com.mortardata.hawk.HawkMain
export PIG_OPTS="<% @pig_opts.each do |k,v| %>-D<%= k %>=<%= v %> <% end %>"
export HADOOP_OPTS="<% @hadoop_opts.each do |k,v| %>-D<%= k %>=<%= v %> <% end %>"

# UDF paths are relative to this direectory
if [ -d "<%= @project_home %>/pigscripts" ]; then
    export LOG4J_CONF_FILE=<%= @log4j_conf %>
    cd <%= @project_home %>/pigscripts
else
    export LOG4J_CONF_FILE=<%= @no_project_log4j_conf %>
fi

# Setup python environment
source <%= @local_install_dir %>/pythonenv/bin/activate

# Run Pig
<%= @local_install_dir %>/<%= @pig_dir %>/bin/pig -exectype local \
    -log4jconf "$LOG4J_CONF_FILE" \
    -propertyFile <%= @local_install_dir %>/lib-common/conf/pig-hawk-global.properties \
    -propertyFile <%= @local_install_dir %>/lib-common/conf/pig-cli-local-dev.properties \
    -param_file <%= @pig_params_file %> \
    <%= @pig_sub_command %>

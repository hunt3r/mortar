#!/bin/bash

set -e

export HADOOP_CLASSPATH="<%= @project_root %>/lib/*"
<% if @driverjar %>
export HADOOP_CLASSPATH="$HADOOP_CLASSPATH:<%= @driverjar %>"
<% end %>
export HADOOP_COMMON_HOME="<%= @hadoop_home %>"
export HADOOP_MAPRED_HOME="<%= @hadoop_home %>"

# Only setting these to get rid of warnings that sqoop is showing
export HCAT_HOME="<%= @hadoop_home %>"
export HBASE_HOME="<%= @hadoop_home %>"

SQOOP_OPTS="<% @sqoop_opts.each do |k,v| %>-D <%= k %>=<%= v %> <% end %>"
OPTARGS='<%= "--driver #{@jdbcdriver}" if @jdbcdriver %>'
OPTARGS="$OPTARGS <%= "--username #{@dbuser}" if @dbuser %>"
OPTARGS="$OPTARGS <%= "--password #{@dbpass}" if @dbpass %>"
OPTARGS="$OPTARGS <%= "--direct" if @direct_import %>"
<% if @inc_column and @inc_value %>
OPTARGS="$OPTARGS --incremental <%= @inc_mode %>"
OPTARGS="$OPTARGS --check-column <%= @inc_column %> "
SQOOP_OPTS="$SQOOP_OPTS -Dsqoop.test.import.rootDir=<%= @s3dest %>/.tmp"
<% end %>

<%= @sqoop_dir %>/bin/sqoop \
    import \
    $SQOOP_OPTS \
    <%= "--table #{@dbtable}" if @dbtable %> \
    <%= "--query '#{@sqlquery}'" if @sqlquery %> \
    -m 1 \
    --connect <%= @jdbc_conn %> \
    --target-dir <%= @s3dest %> \
    $OPTARGS \
    <% if @inc_column and @inc_value %>--last-value '<%= @inc_value %>'<% end %>


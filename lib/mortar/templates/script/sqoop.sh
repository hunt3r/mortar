#!/bin/bash

set -e

export HADOOP_CLASSPATH="<%= @classpath %>"
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

<%= @sqoop_dir %>/bin/sqoop \
    import \
    -m 1 \
    $SQOOP_OPTS \
    --table <%= @dbtable %> \
    --connect <%= @jdbc_conn %> \
    --target-dir <%= @s3dest %> \
    $OPTARGS \


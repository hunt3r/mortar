#!/bin/bash

set -e

# Setup python environment
source <%= @local_install_dir %>/pythonenv/bin/activate

export LUIGI_CONFIG_PATH=`pwd`/`dirname <%= @python_script %>`/client.cfg

# Run Python
<%= @local_install_dir %>/pythonenv/bin/python \
    <%= @python_arugments %> \
    <%= @python_script %> \
    <%= @script_arguments %>

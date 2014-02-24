#!/bin/bash

set -e


# Setup python environment
source <%= @local_install_dir %>/pythonenv/bin/activate

# Run Pig
<%= @local_install_dir %>/pythonenv/bin/python \
    <%= @python_arugments %> \
    <%= @python_script %> \
    <%= @script_arguments %>

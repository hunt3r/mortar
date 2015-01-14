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

require "mortar/command/base"

# view running and recent clusters
#
class Mortar::Command::Clusters < Mortar::Command::Base
    
  # clusters
  #
  # Display running and recently terminated clusters.
  #
  def index
    validate_arguments!
    
    clusters = api.get_clusters(Mortar::API::Jobs::CLUSTER_BACKEND__ALL).body['clusters']
    if not clusters.empty?
      display_table(clusters,
      %w( cluster_id size status_description cluster_type_description start_timestamp duration cluster_backend_description),
      ['cluster_id', 'Size (# of Nodes)', 'Status', 'Type', 'Start Timestamp', 'Elapsed Time', 'Cluster Backend'])
    else
      display("There are no running or recent clusters")
    end
    
  end
  
   # clusters: stop CLUSTER_ID
   #
   # Stop a running cluster.
   #
   def stop
     cluster_id = shift_argument
     unless cluster_id
       error("Usage: mortar clusters:stop CLUSTER_ID\nMust specify CLUSTER_ID.")
     end   
         
     response = api.stop_cluster(cluster_id) .body  

     if response['message'].nil?
        display("Stopping cluster #{cluster_id}.")
     else
       display(response['message'])
     end
   end
end

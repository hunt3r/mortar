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

require 'spec_helper'
require 'mortar/command/clusters'

module Mortar::Command
  describe Clusters do
    
    before(:each) do
      stub_core
    end
        
    context("index") do
      
      it "lists running and recently started clusters" do
        # stub api request
        clusters = [{"cluster_id" => "50fbe5a23004292547fc2224", 
                     "size" => 2,
                     "status_description" => "Running",
                     "start_timestamp" => "2012-08-27T21:27:15.669000+00:00",
                     "duration" => "2 mins",
                     "cluster_backend_description" => "Hadoop 1 (Pig)" },
                    {"cluster_id" => "50fbe5a23004292547fc2225", 
                     "size" => 10,
                     "status_description" => "Shut Down",
                     "start_timestamp" => "2011-08-27T21:27:15.669000+00:00",
                     "duration" => "20 mins",
                     "cluster_backend_description" => "Hadoop 2 (Spark)" }]
         mock(Mortar::Auth.api).get_clusters(Mortar::API::Jobs::CLUSTER_BACKEND__ALL).returns(Excon::Response.new(:body => {"clusters" => clusters}))
         stderr, stdout = execute("clusters", nil, nil)
         stdout.should == <<-STDOUT
cluster_id                Size (# of Nodes)  Status     Type  Start Timestamp                   Elapsed Time  Cluster Backend
------------------------  -----------------  ---------  ----  --------------------------------  ------------  ----------------
50fbe5a23004292547fc2224                  2  Running          2012-08-27T21:27:15.669000+00:00  2 mins        Hadoop 1 (Pig)
50fbe5a23004292547fc2225                 10  Shut Down        2011-08-27T21:27:15.669000+00:00  20 mins       Hadoop 2 (Spark)
STDOUT
      end

      it "handles no clusters running" do
        mock(Mortar::Auth.api).get_clusters(Mortar::API::Jobs::CLUSTER_BACKEND__ALL).returns(Excon::Response.new(:body => {"clusters" => []}))
         stderr, stdout = execute("clusters", nil, nil)
         stdout.should == <<-STDOUT
There are no running or recent clusters
STDOUT
      end
    end
    
     context("stop") do
        it "Stops a running cluster with default message" do
          cluster_id = "1234abcd"
          mock(Mortar::Auth.api).stop_cluster(cluster_id) {Excon::Response.new(:body => {"success" => true})}

          stderr, stdout = execute("clusters:stop #{cluster_id}")
          stdout.should == <<-STDOUT
Stopping cluster #{cluster_id}.
STDOUT
      end

        it "Stops a running cluster with server message" do
          cluster_id = "1234abcd"
          message = "some awesome message"
          mock(Mortar::Auth.api).stop_cluster(cluster_id) {Excon::Response.new(:body => {"success" => true, "message" => message})}

          stderr, stdout = execute("clusters:stop #{cluster_id}")
          stdout.should == "#{message}\n"
        end
      end
    
  end
    
end

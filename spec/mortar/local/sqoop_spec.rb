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
require 'fakefs/spec_helpers'
require 'mortar/local/sqoop'
require 'launchy'


module Mortar::Local
  describe Sqoop do

    context "prepare query" do

      it "adds a where clause if none exists" do
        sqoop = Mortar::Local::Sqoop.new
        expect(sqoop.prep_query("SELECT * FROM customers")).to eq("SELECT * FROM customers WHERE \$CONDITIONS")
      end

      it "wraps existing where clause and appends condition" do
        original = "SELECT * FROM customers WHERE customer_id = 1"
        expected = "SELECT * FROM customers WHERE (customer_id = 1) AND \$CONDITIONS"
        sqoop = Mortar::Local::Sqoop.new
        expect(sqoop.prep_query(original)).to eq(expected)
      end

      it "wraps a complex where clause and appends condition" do
        original = "SELECT * FROM customers WHERE (customer_id = 1 and customer_name = 'tom') or customer_id=2"
        expected = "SELECT * FROM customers WHERE ((customer_id = 1 and customer_name = 'tom') or customer_id=2) AND \$CONDITIONS"
        sqoop = Mortar::Local::Sqoop.new
        expect(sqoop.prep_query(original)).to eq(expected)
      end

      it "does nothing if the user was polite enough to supply the clause themselves" do
        query = "SELECT * FROM customers WHERE (customer_id = 1) AND \$CONDITIONS"
        sqoop = Mortar::Local::Sqoop.new
        expect(sqoop.prep_query(query)).to eq(query)
      end


    end

  end
end

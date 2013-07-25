/*
    Copyright 2013 Mortar Data Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

/*
 * A pig macro to characterize some data.
 * Take an alias to some pre-loaded data and return a relation
 * containing statistics about that data in a bag.
 * Each field is listed up to five times (with their five most common
 * example values) as a tuple of the following form:
 *     (
 *      Field Name (embedded fields have their parent's field name prepended), 
 *      Number of distinct values associated with the field, 
 *      Total number of values,
 *      Deciles,
 *      Number of null appearences,
 *      Percentage null,
 *      Minimum value,
 *      Maximum value,
 *      Range of values (Max - Min),
 *      Type,
 *      Values (tuple of top 5 values, bags/chararrays/tuples are converted to length)
 *      Value Counts (tuple of corresponding number of value occurrences)
 *      Original Values (tuple of corresponding original values)
 *     )
 *
 * data: {anything}
 * inferTypes: when true, characterize will infer numeric types for values
 *   without an explicit schema (e.g. values in a complex map object)
 *
 * Example:
 * data = LOAD '/path/to/data' USING JsonLoader();
 * characterized = Characterize(data, 'true')
 */

REGISTER 's3://mhc-software-mirror/datafu/datafu-0.0.10.jar';
REGISTER 's3://mhc-software-mirror/bacon-bits/udfs/java/bacon-bits-0.1.0.jar';
REGISTER '../udfs/jython/top_5_tuple.py' USING jython AS top5;

DEFINE Deciles                  datafu.pig.stats.StreamingQuantile('11');

DEFINE Characterize(data, inferTypes)
RETURNS out {

DEFINE Characterize__ExtractFields              com.mortardata.pig.ExtractFields('$inferTypes');

raw_fields =  FOREACH $data
              GENERATE FLATTEN(Characterize__ExtractFields(*)) as 
              (keyname:chararray, type:chararray, val:double, orig:chararray);

--Group the rows by field name and find the number of unique values for each field in the collection
key_groups = GROUP raw_fields BY (keyname);
unique_vals = FOREACH key_groups {
    v = raw_fields.val;
    null_fields = filter raw_fields by val is null;
    unique_v = distinct v;
    GENERATE flatten(group)  as keyname:chararray,
             COUNT(unique_v) as num_distinct_vals_count:long, COUNT(v) as num_vals:long, COUNT(null_fields) as num_null:long,
             (double) COUNT(null_fields) / (double) COUNT(raw_fields) as percentage_null:double, 
             MIN(unique_v.val) as min_val:double, MAX(unique_v.val) as max_val:double;
}

-- calculate decile tuples for each key (filtering out null values to make datafu happy)
no_nulls = filter raw_fields by val is not null;
no_null_groups = GROUP no_nulls BY keyname;
key_deciles = FOREACH no_null_groups {
  GENERATE flatten(group) as keyname:chararray, Deciles(no_nulls.val) as deciles:tuple();
}      

-- Find the number of times each value occurs for each field
key_val_groups = GROUP raw_fields BY (keyname, type, val, orig);
key_val_groups_with_counts =  FOREACH key_val_groups
                             GENERATE flatten(group),
                                      COUNT($1) as val_count:long;

-- Find the top 5 most common values for each field
key_vals = GROUP key_val_groups_with_counts BY (keyname);
top_5_vals = FOREACH key_vals {
    ordered_vals = ORDER key_val_groups_with_counts BY val_count DESC;
    limited_vals = LIMIT ordered_vals 5;
    GENERATE flatten(limited_vals);
}

cogroup_result = COGROUP unique_vals BY keyname, 
                         top_5_vals BY keyname;

flat_vals = FOREACH cogroup_result {
     top_vals = top5.key_bag_to_tuple(top_5_vals);
     GENERATE flatten(unique_vals) as 
              (keyname:chararray, num_distinct_vals_count:long, num_vals:long, 
               num_null:long, percent_null:double, min_val:double, max_val:double), top_vals.vals as vals,
               top_vals.type as type:chararray, top_vals.orig as orig:tuple(), top_vals.val_counts as val_counts:tuple();
}

join_result = JOIN flat_vals BY keyname,
            key_deciles  BY keyname;

-- Clean up columns (remove duplicate keyname field)
result =  FOREACH join_result
         GENERATE flat_vals::keyname as Key,
                  num_distinct_vals_count as NDistinct,
                  num_vals as NVals,
                  deciles as Deciles,        
                  num_null as NNull,
                  percent_null as PctNull,
                  min_val as Min,
                  max_val as Max,
                  max_val - min_val as Range,
                  type as Type,
                  vals as Vals,
                  val_counts as ValCounts,
                  orig as OrigVals;

-- -- Sort by field name and number of values
$out = ORDER result BY Key;

};

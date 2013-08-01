/**
 * <%= project_name %>
 */
 
/** 
 * Parameters - set default values here; you can override with -p on the command-line.
 */
 
<%= '%default'%> INPUT_PATH 's3n://mortar-example-data/tutorial/excite.log.bz2'
<%= '%default'%> OUTPUT_PATH 's3n://my-output-bucket/$MORTAR_EMAIL_S3_ESCAPED/<%= project_name %>'

/**
 * User-Defined Functions (UDFs)
 */

REGISTER '../udfs/python/<%= project_name %>.py' USING streaming_python AS <%= project_name_alias %>;

-- This is an example of loading up input data
my_input_data = LOAD '$INPUT_PATH' 
               USING PigStorage('\t') 
                  AS (field0:chararray, field1:chararray, field2:chararray);

-- This is an example pig operation
filtered = FILTER my_input_data
               BY field0 IS NOT NULL;

-- This is an example call to a python user-defined function
with_udf_output = FOREACH filtered 
                 GENERATE field0..field2, 
                          <%= project_name_alias %>.example_udf(field0) AS example_udf_field;

-- remove any existing data
rmf $OUTPUT_PATH;

-- store the results
STORE with_udf_output 
 INTO '$OUTPUT_PATH' 
USING PigStorage('\t');


-- update attribute values for given topo object

CREATE OR REPLACE FUNCTION topo_update.apply_attr_on_topo_layer(json_feature text,
  layer_schema text, layer_table text, server_json_feature text default null) 
RETURNS int AS $$DECLARE

num_rows int;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- holds the num rows affected when needed
num_rows_affected int;

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the target table
update_fields text[];

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the temp table
update_fields_t text[];

-- holde the computed value for json input reday to use
json_input_structure topo_update.json_input_structure;  

use_default_dates boolean = false;
BEGIN

	-- parse the input values
	json_input_structure := topo_update.handle_input_json_props(json_feature::json,server_json_feature::json,4258,use_default_dates);

	
	RAISE NOTICE 'topo_update.apply_attr_on_topo_layer json_input_structure %', json_input_structure;


	-- Create temporary table ttt2_aaotl_new_topo_rows_in_org_table to receive the new record
	command_string := topo_update.create_temp_tbl_as(
	  'ttt2_aaotl_new_topo_rows_in_org_table',
	  format('SELECT * FROM %I.%I LIMIT 0',
	         layer_schema,
	         layer_table));
	EXECUTE command_string;

	
  	-- Insert all matching column names into temp table ttt2_aaotl_new_topo_rows_in_org_table 
	INSERT INTO ttt2_aaotl_new_topo_rows_in_org_table
	SELECT * FROM json_populate_record(null::ttt2_aaotl_new_topo_rows_in_org_table,json_input_structure.json_properties);
	
	RAISE NOTICE 'topo_update.apply_attr_on_topo_layer Added all attributes to ttt2_aaotl_new_topo_rows_in_org_table';

	-- Update felles egenskaper with new values
	command_string := format('UPDATE ttt2_aaotl_new_topo_rows_in_org_table AS s
	SET felles_egenskaper = topo_rein.get_rein_felles_egenskaper_update(r.felles_egenskaper, %L)
	FROM  %I.%I r
	WHERE r.id = s.id',
	json_input_structure.sosi_felles_egenskaper,
    layer_schema,
    layer_table
	);
	RAISE NOTICE 'topo_update.apply_attr_on_topo_layer command_string %', command_string;
	EXECUTE command_string;

  RAISE NOTICE 'topo_update.apply_attr_on_topo_layer Set felles_egenskaper field';

  -- Extract name of fields with not-null values:
  -- Extract name of fields with not-null values and append the table prefix n.:
  -- Only update json value that exits 
  SELECT
  	array_agg(quote_ident(update_column)) AS update_fields,
  	array_agg('n.'||quote_ident(update_column)) as update_fields_t
  INTO
  	update_fields,
  	update_fields_t
  FROM (
   SELECT distinct(key) AS update_column
   FROM ttt2_aaotl_new_topo_rows_in_org_table t, json_each_text(to_json((t)))  ,
   (SELECT json_object_keys(json_input_structure.json_properties) as res) as key_list
   WHERE key != 'id' AND 
   key = key_list.res 
  ) AS keys;
  
  -- This is hardcoding if a column name that should have been done i a better way
  update_fields := array_append(update_fields, 'felles_egenskaper');
  update_fields_t := array_append(update_fields_t, 'n.felles_egenskaper');
  
  RAISE NOTICE 'topo_update.apply_attr_on_topo_layer Extract name of not-null fields: %', update_fields_t;
  RAISE NOTICE 'topo_update.apply_attr_on_topo_layer Euuxtract name of not-null fields: %', update_fields;
  
  -- update the org table with not null values
  command_string := format(
    'UPDATE %I.%I s SET
	(%s) = (%s) 
	FROM ttt2_aaotl_new_topo_rows_in_org_table n WHERE n.id = s.id',
    layer_schema,
    layer_table,
    array_to_string(update_fields, ','),
    array_to_string(update_fields_t, ',')
    );
	RAISE NOTICE 'topo_update.apply_attr_on_topo_layer command_string %', command_string;
	EXECUTE command_string;
	
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'topo_update.apply_attr_on_topo_layer Number num_rows_affected  %',  num_rows_affected;
	

	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;




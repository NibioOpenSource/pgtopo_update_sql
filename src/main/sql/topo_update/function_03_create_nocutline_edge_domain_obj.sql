-- This a function that will be called from the client when user is drawing a line
-- This line will be applied the data in the line layer

-- The result is a set of id's of the new line objects created

-- TODO set attributtes for the line


-- {
CREATE OR REPLACE FUNCTION
topo_update.create_nocutline_edge_domain_obj(json_feature text,
  layer_schema text, layer_table text, layer_column text,
  snap_tolerance float8,
  server_json_feature text default null)
RETURNS TABLE(id integer) AS $$
DECLARE

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this is the tolerance used for snap to 
-- TODO use as parameter put for testing we just have here for now
border_topo_info topo_update.input_meta_info ;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- the number times the input line intersects
num_edge_intersects int;

input_geo geometry;

-- holds the value for felles egenskaper from input
felles_egenskaper_linje topo_rein.sosi_felles_egenskaper;

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the target table
not_null_fields text[];

-- holde the computed value for json input reday to use
json_input_structure topo_update.json_input_structure;  

BEGIN
	
	-- TODO totally rewrite this code
	json_input_structure := topo_update.handle_input_json_props(json_feature::json,server_json_feature::json,4258);
	input_geo := json_input_structure.input_geo;

	
	-- Read parameters
	border_topo_info.layer_schema_name := layer_schema;
	border_topo_info.layer_table_name := layer_table;
	border_topo_info.layer_feature_column := layer_column;
	border_topo_info.snap_tolerance := snap_tolerance;

	-- Find out topology name and element_type from layer identifier
  BEGIN
    SELECT t.name, l.feature_type
    FROM topology.topology t, topology.layer l
    WHERE l.level = 0 -- need be primitive
      AND l.schema_name = border_topo_info.layer_schema_name
      AND l.table_name = border_topo_info.layer_table_name
      AND l.feature_column = border_topo_info.layer_feature_column
      AND t.id = l.topology_id
    INTO STRICT border_topo_info.topology_name,
                border_topo_info.element_type;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE EXCEPTION 'Cannot find info for primitive layer %.%.%',
        border_topo_info.layer_schema_name,
        border_topo_info.layer_table_name,
        border_topo_info.layer_feature_column;
  END;

		-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);

	
	RAISE NOTICE 'The JSON input %',  json_feature;

	RAISE NOTICE 'border_layer_id %', border_layer_id;


	-- get the json values
	command_string := topo_update.create_temp_tbl_def('credo_ttt2_new_attributes_values','(geom geometry,properties json)');
	RAISE NOTICE 'command_string %', command_string;

	EXECUTE command_string;

	-- TRUNCATE TABLE credo_ttt2_new_attributes_values;
	INSERT INTO credo_ttt2_new_attributes_values(geom,properties)
	VALUES(json_input_structure.input_geo,json_input_structure.json_properties) ;

		-- check that it is only one row put that value into 
	-- TODO rewrite this to not use table in
	
	RAISE NOTICE 'Step::::::::::::::::: 1';

	-- TODO find another way to handle this

	felles_egenskaper_linje := json_input_structure.sosi_felles_egenskaper;
	

	RAISE NOTICE 'Step::::::::::::::::: 2';

	-- Create temporary table to receive the new record
	command_string := topo_update.create_temp_tbl_as(
	  'ttt2_new_topo_rows_in_org_table',
	  format('SELECT * FROM %I.%I LIMIT 0',
	         border_topo_info.layer_schema_name,
	         border_topo_info.layer_table_name));
	EXECUTE command_string;

  -- Insert all matching column names into temp table
	INSERT INTO ttt2_new_topo_rows_in_org_table
		SELECT r.* --, t2.geom
		FROM credo_ttt2_new_attributes_values t2,
         json_populate_record(
            null::ttt2_new_topo_rows_in_org_table,
            t2.properties) r;

  RAISE NOTICE 'Added all attributes to ttt2_new_topo_rows_in_org_table';

  -- Convert geometry to TopoGeometry, write it in the temp table
  command_string := format('UPDATE ttt2_new_topo_rows_in_org_table
    SET %I = topology.toTopoGeom(%L, %L, %L, %L)',
    border_topo_info.layer_feature_column, input_geo,
    border_topo_info.topology_name, border_layer_id,
    border_topo_info.snap_tolerance);
	EXECUTE command_string;

  RAISE NOTICE 'Converted to TopoGeometry';

  -- Add the common felles_egenskaper field
  command_string := format('UPDATE ttt2_new_topo_rows_in_org_table
    SET felles_egenskaper = %L', felles_egenskaper_linje);
	EXECUTE command_string;

  RAISE NOTICE 'Set felles_egenskaper field';

  -- Extract name of fields with not-null values:
  SELECT array_agg(quote_ident(key))
    FROM ttt2_new_topo_rows_in_org_table t, json_each_text(to_json((t)))
   WHERE value IS NOT NULL
    INTO not_null_fields;

  RAISE NOTICE 'Extract name of not-null fields: %', not_null_fields;

  -- Copy full record from temp table to actual table and
  -- update temp table with actual table values
  command_string := format(
    'WITH inserted AS ( INSERT INTO %I.%I (%s) SELECT %s FROM
ttt2_new_topo_rows_in_org_table RETURNING * ), deleted AS ( DELETE
FROM ttt2_new_topo_rows_in_org_table ) INSERT INTO
ttt2_new_topo_rows_in_org_table SELECT * FROM inserted ',
    border_topo_info.layer_schema_name,
    border_topo_info.layer_table_name,
    array_to_string(not_null_fields, ','),
    array_to_string(not_null_fields, ',')
    );
	EXECUTE command_string;

	RAISE NOTICE 'Step::::::::::::::::: 3';

	-- Find topto that intersects with the new line drawn by the end user
	-- This lines should be returned, together with the topo object created
	command_string :=
topo_update.create_temp_tbl_as('ttt2_intersection_id','SELECT * FROM ttt2_new_topo_rows_in_org_table limit 0');
	EXECUTE command_string;
	-- TRUNCATE TABLE ttt2_intersection_id;

  command_string := format('
	INSERT INTO ttt2_intersection_id
	SELECT distinct a.*  
	FROM 
	%I.%I a, 
	credo_ttt2_new_attributes_values a2,
	%I.relation re, 
	topology.layer tl,
	%I.edge_data  ed
	WHERE ST_intersects(ed.geom,a2.geom)
	AND topo_rein.get_relation_id(a.%I) = re.topogeo_id AND
re.layer_id = tl.layer_id AND tl.schema_name = %L AND 
	tl.table_name = %L AND ed.edge_id=re.element_id
	AND NOT EXISTS (SELECT 1 FROM ttt2_new_topo_rows_in_org_table nr
where a.id = nr.id)',
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name,
  border_topo_info.topology_name,
  border_topo_info.topology_name,
  border_topo_info.layer_feature_column,
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name
  );
	EXECUTE command_string;

	RAISE NOTICE 'StepA::::::::::::::::: 4';

	
	-- create a empty table hold list og id's changed.
	-- TODO this should have moved to anothe place, but we need the result below
	command_string := topo_update.create_temp_tbl_as('ttt2_id_return_list','SELECT * FROM  ttt2_new_topo_rows_in_org_table limit 0');
	EXECUTE command_string;
	-- TRUNCATE TABLE ttt2_id_return_list;

	-- update the return table with intersected rows
	INSERT INTO ttt2_id_return_list(id)
	SELECT a.id FROM ttt2_new_topo_rows_in_org_table a ;

	-- update the return table with intersected rows
	INSERT INTO ttt2_id_return_list(id)
	SELECT a.id FROM ttt2_intersection_id a ;
	
	RAISE NOTICE 'StepA::::::::::::::::: 5';

		
	
	-- TODO should we also return lines that are close to or intersects and split them so it's possible to ??? 
	command_string := ' SELECT distinct tg.id AS id FROM ttt2_id_return_list tg';
	-- command_string := 'SELECT tg.id AS id FROM ' || border_topo_info.layer_schema_name || '.' || border_topo_info.layer_table_name || ' tg, new_rows_added_in_org_table new WHERE new.linje::geometry && tg.linje::geometry';
	RAISE NOTICE '%', command_string;
    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;
--}


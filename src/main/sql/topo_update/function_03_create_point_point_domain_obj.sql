-- This a function that will be called from the client when user is drawing a point 
-- This line will be applied the data in the point layer

-- The result is a set of id's of the new line objects created

-- TODO set attributtes for the line


-- DROP FUNCTION FUNCTION topo_update.create_point_point_domain_obj(geo_in geometry) cascade;


CREATE OR REPLACE FUNCTION topo_update.create_point_point_domain_obj(json_feature text,
  layer_schema text, layer_table text, layer_column text,
  snap_tolerance float8) 
RETURNS TABLE(id integer) AS $$
DECLARE

json_result text;

-- this border layer id will picked up by input parameters
point_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

-- TODO use as parameter put for testing we just have here for now
point_topo_info topo_update.input_meta_info ;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- used for logging
num_rows_affected int;

-- holds the value for felles egenskaper from input
felles_egenskaper_linje topo_rein.sosi_felles_egenskaper;
simple_sosi_felles_egenskaper_linje topo_rein.simple_sosi_felles_egenskaper;

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the target table
not_null_fields text[];

input_geo geometry;

BEGIN
	
	-- get meta data
	point_topo_info := topo_update.make_input_meta_info(layer_schema, layer_table , layer_column );
	
			-- find border layer id
	point_layer_id := topo_update.get_topo_layer_id(point_topo_info);



	DROP TABLE IF EXISTS ttt_new_attributes_values;

	CREATE TEMP TABLE ttt_new_attributes_values(geom geometry,properties json);
	
	-- get json data
	INSERT INTO ttt_new_attributes_values(geom,properties)
	SELECT 
		topo_rein.get_geom_from_json(feat,4258) as geom,
		to_json(feat->'properties')::json  as properties
	FROM (
	  	SELECT json_feature::json AS feat
	) AS f;

		-- check that it is only one row put that value into 
	-- TODO rewrite this to not use table in
	
	IF (SELECT count(*) FROM ttt_new_attributes_values) != 1 THEN
		RAISE EXCEPTION 'Not valid json_feature %', json_feature;
	ELSE 
		-- TODO find another way to handle this
		SELECT * INTO simple_sosi_felles_egenskaper_linje 
		FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
		(select properties from ttt_new_attributes_values) );

		felles_egenskaper_linje := topo_rein.get_rein_felles_egenskaper(simple_sosi_felles_egenskaper_linje);
	END IF;
	
	-- TODO find another way to handle this
	SELECT * INTO simple_sosi_felles_egenskaper_linje
	FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
	(select properties from ttt_new_attributes_values) );
	
	felles_egenskaper_linje := topo_rein.get_rein_felles_egenskaper(simple_sosi_felles_egenskaper_linje);
	SELECT geom INTO input_geo FROM ttt_new_attributes_values;

		-- Create temporary table to receive the new record
	command_string := topo_update.create_temp_tbl_as(
	  'ttt2_new_topo_rows_in_org_table',
	  format('SELECT * FROM %I.%I LIMIT 0',
	         point_topo_info.layer_schema_name,
	         point_topo_info.layer_table_name));
	EXECUTE command_string;

	  -- Insert all matching column names into temp table
	INSERT INTO ttt2_new_topo_rows_in_org_table
		SELECT r.* --, t2.geom
		FROM ttt_new_attributes_values t2,
         json_populate_record(
            null::ttt2_new_topo_rows_in_org_table,
            t2.properties) r;

 	 RAISE NOTICE 'Added all attributes to ttt2_new_topo_rows_in_org_table';

   	command_string := format('UPDATE ttt2_new_topo_rows_in_org_table
    SET %I = topology.toTopoGeom(%L, %L, %L, %L)',
    point_topo_info.layer_feature_column, input_geo,
    point_topo_info.topology_name, point_layer_id,
    point_topo_info.snap_tolerance);
	EXECUTE command_string;

  	RAISE NOTICE 'Converted to TopoGeometry';

  	  -- Add the common felles_egenskaper field
 	command_string := format('UPDATE ttt2_new_topo_rows_in_org_table
    SET felles_egenskaper = %L', felles_egenskaper_linje);
	EXECUTE command_string;

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
    point_topo_info.layer_schema_name,
    point_topo_info.layer_table_name,
    array_to_string(not_null_fields, ','),
    array_to_string(not_null_fields, ',')
    );
	EXECUTE command_string;

	

	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number num_rows_affected  %',  num_rows_affected;
	
	-- TODO should we also return lines that are close to or intersects and split them so it's possible to ??? 
	command_string := ' SELECT tg.id AS id FROM  ttt2_new_topo_rows_in_org_table tg';
	-- command_string := 'SELECT tg.id AS id FROM ' || border_topo_info.layer_schema_name || '.' || border_topo_info.layer_table_name || ' tg, new_rows_added_in_org_table new WHERE new.punkt::geometry && tg.punkt::geometry';
	RAISE NOTICE '%', command_string;
    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;

--{ kept for backward compatility
CREATE OR REPLACE FUNCTION topo_update.create_point_point_domain_obj(json_feature text) 
RETURNS TABLE(id integer) AS $$
  SELECT topo_update.create_point_point_domain_obj($1, 'topo_rein', 'reindrift_anlegg_punkt', 'punkt', 1e-10);
$$ LANGUAGE 'sql';
--}


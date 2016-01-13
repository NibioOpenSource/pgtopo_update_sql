

-- update attribute values for given topo object
CREATE OR REPLACE FUNCTION topo_update.apply_attr_on_topo_point(json_feature text,
  layer_schema text, layer_table text, layer_column text, snap_tolerance float8) 
RETURNS int AS $$DECLARE

num_rows int;


-- this point layer id will picked up by input parameters
point_layer_id int;


-- TODO use as parameter put for testing we just have here for now
point_topo_info topo_update.input_meta_info ;

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- holds the num rows affected when needed
num_rows_affected int;

-- used to hold values
felles_egenskaper_flate topo_rein.sosi_felles_egenskaper;
simple_sosi_felles_egenskaper_linje topo_rein.simple_sosi_felles_egenskaper;

geo_point geometry;

row_id int;



BEGIN
	
	point_topo_info := topo_update.make_input_meta_info(layer_schema, layer_table , layer_column );
	point_layer_id := topo_update.get_topo_layer_id(point_topo_info);
	
	DROP TABLE IF EXISTS ttt_new_attributes_values;

	CREATE TEMP TABLE ttt_new_attributes_values(geom geometry,properties json);
	
	-- update attributtes by common proc
	num_rows_affected := topo_update.apply_attr_on_topo_line(json_feature,
 	point_topo_info.layer_schema_name, point_topo_info.layer_table_name, point_topo_info.layer_feature_column) ;

	
	-- get json data because we should also update the geometry
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
		SELECT geom FROM ttt_new_attributes_values INTO geo_point;
		SELECT (properties->>'id')::int FROM ttt_new_attributes_values INTO row_id;
	END IF;

	RAISE NOTICE 'geo_point %', geo_point;

	-- if move point
	IF geo_point is not NULL THEN
	
	
		command_string := format('SELECT topology.clearTopoGeom(%s) FROM  %I.%I r WHERE id = %s',
		point_topo_info.layer_feature_column,
	    point_topo_info.layer_schema_name,
	    point_topo_info.layer_table_name,
	    row_id
		);

		RAISE NOTICE 'command_string update point geom %', command_string;
		EXECUTE command_string;

		command_string := format('UPDATE  %I.%I r
		SET %s = topology.toTopoGeom(%L, %L, %L, %L)
		WHERE id = %s',
	    point_topo_info.layer_schema_name,
	    point_topo_info.layer_table_name,
		point_topo_info.layer_feature_column,
		geo_point,
    	point_topo_info.topology_name, 
    	point_layer_id,
    	point_topo_info.snap_tolerance,
	    row_id
		);

		RAISE NOTICE 'command_string %', command_string;
		EXECUTE command_string;

	
	END IF;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Number num_rows_affected  %',  num_rows_affected;
	

	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;





--{ kept for backward compatility
CREATE OR REPLACE FUNCTION  topo_update.apply_attr_on_topo_point(json_feature text) 
RETURNS int AS $$
  SELECT topo_update.apply_attr_on_topo_point($1, 'topo_rein', 'reindrift_anlegg_punkt', 'punkt',  1e-10);
$$ LANGUAGE 'sql';
--}

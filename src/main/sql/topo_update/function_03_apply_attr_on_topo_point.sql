

-- update attribute values for given topo object
CREATE OR REPLACE FUNCTION topo_update.apply_attr_on_topo_point(json_feature text,
  layer_schema text, layer_table text, layer_column text, snap_tolerance float8,server_json_feature text default null) 
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

geo_point geometry;

row_id int;

-- holde the computed value for json input reday to use
json_input_structure topo_update.json_input_structure;  


BEGIN
	
	point_topo_info := topo_update.make_input_meta_info(layer_schema, layer_table , layer_column );
	point_layer_id := topo_update.get_topo_layer_id(point_topo_info);
	
	-- parse the input values
	json_input_structure := topo_update.handle_input_json_props(json_feature::json,server_json_feature::json,4258);
	geo_point := json_input_structure.input_geo;

	RAISE NOTICE 'geo_point from json %',  ST_AsEWKT(geo_point);

	-- update attributtes by common proc
	num_rows_affected := topo_update.apply_attr_on_topo_line(json_feature,
 	point_topo_info.layer_schema_name, point_topo_info.layer_table_name, point_topo_info.layer_feature_column,server_json_feature) ;

 	
	RAISE NOTICE 'geo_point %',  ST_AsEWKT(geo_point);

	-- if move point
	IF geo_point is not NULL THEN
	
		row_id := (json_input_structure.json_properties->>'id')::int;
	
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

		
		GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	
	END IF;
	
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



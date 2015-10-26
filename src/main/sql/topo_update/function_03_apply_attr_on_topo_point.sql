

-- update attribute values for given topo object
CREATE OR REPLACE FUNCTION topo_update.apply_attr_on_topo_point(json_feature text) 
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

BEGIN
	
	-- TODO to be moved is justed for testing now
	point_topo_info.topology_name := 'topo_rein_sysdata';
	point_topo_info.layer_schema_name := 'topo_rein';
	point_topo_info.layer_table_name := 'reindrift_anlegg_punkt';
	point_topo_info.layer_feature_column := 'punkt';
	point_topo_info.snap_tolerance := 0.0000000001;
	point_topo_info.element_type = 1;
	-- find point layer id
	point_layer_id := topo_update.get_topo_layer_id(point_topo_info);
	
	DROP TABLE IF EXISTS new_attributes_values;

	CREATE TEMP TABLE new_attributes_values(geom geometry,properties json);
	
	-- get json data
	INSERT INTO new_attributes_values(properties)
	SELECT 
--		topo_rein.get_geom_from_json(feat,4258) as geom,
		to_json(feat->'properties')::json  as properties
	FROM (
	  	SELECT json_feature::json AS feat
	) AS f;

	--  
	
	-- We now know which rows we can reuse clear out old data rom the realation table
	UPDATE topo_rein.reindrift_anlegg_punkt r
	SET 
		reindriftsanleggstype = (t2.properties->>'reindriftsanleggstype')::int,
		reinbeitebruker_id = (t2.properties->>'reinbeitebruker_id')::text
	FROM new_attributes_values t2
	-- WHERE ST_Intersects(r.omrade::geometry,t2.geom);
	WHERE id = (t2.properties->>'id')::int;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Number num_rows_affected  %',  num_rows_affected;
	

	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;






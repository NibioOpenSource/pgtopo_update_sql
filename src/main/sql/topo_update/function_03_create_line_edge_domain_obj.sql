-- This a function that will be called from the client when user is drawing a line
-- This line will be applied the data in the line layer

-- The result is a set of id's of the new line objects created

-- TODO set attributtes for the line


CREATE OR REPLACE FUNCTION topo_update.create_line_edge_domain_obj(json_feature text) 
RETURNS TABLE(id integer) AS $$
DECLARE

json_result text;

new_border_data topogeometry;

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

-- TODO use as parameter put for testing we just have here for now
border_topo_info topo_update.input_meta_info ;

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- used for logging
num_rows_affected int;

-- used for logging
add_debug_tables int = 0;

-- the number times the inlut line intersects
num_edge_intersects int;

line_intersection_result geometry;

BEGIN
	
	
	-- TODO to be moved is justed for testing now
	border_topo_info.topology_name := 'topo_rein_sysdata';
	border_topo_info.layer_schema_name := 'topo_rein';
	border_topo_info.layer_table_name := 'reindrift_anlegg_linje';
	border_topo_info.layer_feature_column := 'linje';
	border_topo_info.snap_tolerance := 0.0000000001;
	border_topo_info.element_type = 2;
	
		-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);

	
	RAISE NOTICE 'The JSON input %',  json_feature;


	-- get the json values
	
	DROP TABLE IF EXISTS new_attributes_values;

	CREATE TEMP TABLE new_attributes_values(geom geometry,properties json);
	
	-- get json data
	INSERT INTO new_attributes_values(geom,properties)
	SELECT 
		topo_rein.get_geom_from_json(feat,4258) as geom,
		to_json(feat->'properties')::json  as properties
	FROM (
	  	SELECT json_feature::json AS feat
	) AS f;

	-- insert the data the new table
	INSERT INTO topo_rein.reindrift_anlegg_linje(linje, felles_egenskaper, reindriftsanleggstype,reinbeitebruker_id)
	SELECT  
		topology.toTopoGeom(t2.geom, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance) AS linje,
		topo_rein.get_rein_felles_egenskaper_linje(0) AS felles_egenskaper,
		(t2.properties->>'reindriftsanleggstype')::int AS reindriftsanleggstype,
		(t2.properties->>'reinbeitebruker_id')::text AS reinbeitebruker_id
	FROM new_attributes_values t2;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Number num_rows_affected  %',  num_rows_affected;

	
	command_string := ' SELECT tg.id AS id FROM topo_rein.reindrift_anlegg_linje tg';

	--command_string := 'SELECT tg.id AS id FROM ' || border_topo_info.layer_schema_name || '.' || border_topo_info.layer_table_name || ' tg, new_reindrift_anlegg_linje new WHERE (new.linje).id = (tg.linje).id';
	RAISE NOTICE '%', command_string;

    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;


--select topo_update.create_line_edge_domain_obj('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.55375, 5.70152 58.55373)');

--select topo_update.create_line_edge_domain_obj('SRID=4258;LINESTRING (5.701884 58.552517, 5.705113 58.552631)');

--select topo_update.create_line_edge_domain_obj('SRID=4258;LINESTRING (5.701884 58.552517, 5.705113 58.552631, 5.70403 58.55375)');


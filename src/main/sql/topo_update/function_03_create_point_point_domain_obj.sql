-- This a function that will be called from the client when user is drawing a point 
-- This line will be applied the data in the point layer

-- The result is a set of id's of the new line objects created

-- TODO set attributtes for the line


-- DROP FUNCTION FUNCTION topo_update.create_point_point_domain_obj(geo_in geometry) cascade;


CREATE OR REPLACE FUNCTION topo_update.create_point_point_domain_obj(geo_in geometry) 
RETURNS TABLE(id integer) AS $$
DECLARE

json_result text;

new_border_data topogeometry;

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

-- TODO use as parameter put for testing we just have here for now
point_topo_info topo_update.input_meta_info ;

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

-- the orignal geo that is from the user
org_geo_in geometry;

-- 
line_intersection_result geometry;

BEGIN
	
	
	-- TODO to be moved is justed for testing now
	point_topo_info.topology_name := 'topo_rein_sysdata';
	point_topo_info.layer_schema_name := 'topo_rein';
	point_topo_info.layer_table_name := 'reindrift_anlegg_punkt';
	point_topo_info.layer_feature_column := 'punkt';
	point_topo_info.snap_tolerance := 0.0000000001;
	point_topo_info.element_type = 1;
	
		-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(point_topo_info);

	org_geo_in := geo_in;
	
	RAISE NOTICE 'The input as %',  ST_AsText(geo_in);

	-- create the new topo object for the egde layer
	new_border_data := topology.toTopoGeom(geo_in, point_topo_info.topology_name, border_layer_id, point_topo_info.snap_tolerance); 
	RAISE NOTICE 'The new topo object created for based on the input geo  %',  new_border_data;

	-- TODO insert some correct value for attributes
	
		-- clean up old surface and return a list of the objects
	DROP TABLE IF EXISTS new_reindrift_anlegg_punkt; 
	CREATE TEMP TABLE new_reindrift_anlegg_punkt AS 
	(SELECT new_border_data AS punkt);
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number_of_rows removed from topo_update.update_domain_surface_layer   %',  num_rows_affected;

	
	INSERT INTO topo_rein.reindrift_anlegg_punkt(punkt, felles_egenskaper)
	SELECT new_border_data, topo_rein.get_rein_felles_egenskaper_linje(0);

	-- return all the lines created
	-- SELECT tg.id AS id FROM topo_rein.reindrift_anlegg_punkt tg, new_reindrift_anlegg_punkt new WHERE (new.punkt).id = (tg.punkt).id

	command_string := 'SELECT tg.id AS id FROM ' || point_topo_info.layer_schema_name || '.' || point_topo_info.layer_table_name || ' tg, new_reindrift_anlegg_punkt new WHERE (new.punkt).id = (tg.punkt).id';
	RAISE NOTICE '%', command_string;

    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;

-- select topo_update.create_point_point_domain_obj('SRID=4258;POINT (5.70182 58.55131)');


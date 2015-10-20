-- This a function that will be called from the client when user is drawing a line
-- This line will be applied the data in the line layer

-- The result is a set of id's of the new line objects created

-- TODO set attributtes for the line


-- DROP FUNCTION FUNCTION topo_update.create_line_edge_domain_obj(geo_in geometry) cascade;


CREATE OR REPLACE FUNCTION topo_update.create_line_edge_domain_obj(geo_in geometry) 
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

-- the orignal geo that is from the user
org_geo_in geometry;

-- 
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

	org_geo_in := geo_in;
	
	RAISE NOTICE 'The input as it used before check/fixed %',  ST_AsText(geo_in);

		-- Only used for debug
	IF add_debug_tables = 1 THEN
		DROP TABLE IF EXISTS topo_rein.create_line_edge_domain_obj_t0; 
		CREATE TABLE topo_rein.create_line_edge_domain_obj_t0(geo_in geometry, IsSimple boolean, IsClosed boolean);
		INSERT INTO topo_rein.create_line_edge_domain_obj_t0(geo_in,IsSimple,IsClosed) VALUES(geo_in,St_IsSimple(geo_in),St_IsSimple(geo_in));
	END IF;

--  Accept any lines 	
--	IF NOT ST_IsSimple(geo_in) THEN
--		RAISE EXCEPTION 'The is not a valid geo for a simple line  %', org_geo_in;
--	ELSIF ST_IsClosed(geo_in) THEN
--		RAISE EXCEPTION 'Do not use a closed line for line object %', org_geo_in;
--	END IF;

	IF add_debug_tables = 1 THEN
		INSERT INTO topo_rein.create_line_edge_domain_obj_t0(geo_in,IsSimple,IsClosed) VALUES(geo_in,St_IsSimple(geo_in),St_IsSimple(geo_in));
	END IF;

	RAISE NOTICE 'The input as it used after check/fixed %',  ST_AsText(geo_in);

	-- create the new topo object for the egde layer
	new_border_data := topology.toTopoGeom(geo_in, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance); 
	RAISE NOTICE 'The new topo object created for based on the input geo  %',  new_border_data;

	-- TODO insert some correct value for attributes
	
		-- clean up old surface and return a list of the objects
	DROP TABLE IF EXISTS new_reindrift_anlegg_linje; 
	CREATE TEMP TABLE new_reindrift_anlegg_linje AS 
	(SELECT new_border_data AS linje);
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number_of_rows removed from topo_update.update_domain_surface_layer   %',  num_rows_affected;

	
	INSERT INTO topo_rein.reindrift_anlegg_linje(linje, felles_egenskaper)
	SELECT new_border_data, topo_rein.get_rein_felles_egenskaper_linje(0);

	-- return all the lines created
	-- SELECT tg.id AS id FROM topo_rein.reindrift_anlegg_linje tg, new_reindrift_anlegg_linje new WHERE (new.linje).id = (tg.linje).id

	command_string := 'SELECT tg.id AS id FROM ' || border_topo_info.layer_schema_name || '.' || border_topo_info.layer_table_name || ' tg, new_reindrift_anlegg_linje new WHERE (new.linje).id = (tg.linje).id';
	RAISE NOTICE '%', command_string;

    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;



--select topo_update.create_line_edge_domain_obj('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.55375, 5.70152 58.55373)');

--select topo_update.create_line_edge_domain_obj('SRID=4258;LINESTRING (5.701884 58.552517, 5.705113 58.552631)');

--select topo_update.create_line_edge_domain_obj('SRID=4258;LINESTRING (5.701884 58.552517, 5.705113 58.552631, 5.70403 58.55375)');


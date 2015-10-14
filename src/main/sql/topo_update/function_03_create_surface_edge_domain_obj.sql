-- This a function that will be called from the client when user is drawing a line
-- This line will be applied the data in the line layer first
-- After that will find the new surfaces created. 
-- new surfaces that was part old serface should inherit old values

-- The result is a set of id's of the new surface objects created

-- TODO set attributtes for the line
-- TODO set attributtes for the surface


-- DROP FUNCTION FUNCTION topo_update.create_surface_edge_domain_obj(geo_in geometry) cascade;


CREATE OR REPLACE FUNCTION topo_update.create_surface_edge_domain_obj(geo_in geometry) 
RETURNS TABLE(id integer) AS $$
DECLARE

json_result text;

new_border_data topogeometry;

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this surface layer id will picked up by input parameters
surface_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

-- TODO use as parameter put for testing we just have here for now
border_topo_info topo_update.input_meta_info ;
surface_topo_info topo_update.input_meta_info ;

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

BEGIN
	
	-- TODO to be moved is justed for testing now
	border_topo_info.topology_name := 'topo_rein_sysdata';
	border_topo_info.layer_schema_name := 'topo_rein';
	border_topo_info.layer_table_name := 'arstidsbeite_var_grense';
	border_topo_info.layer_feature_column := 'grense';
	border_topo_info.snap_tolerance := 0.0000000001;
	border_topo_info.element_type = 2;
	
	
	surface_topo_info.topology_name := 'topo_rein_sysdata';
	surface_topo_info.layer_schema_name := 'topo_rein';
	surface_topo_info.layer_table_name := 'arstidsbeite_var_flate';
	surface_topo_info.layer_feature_column := 'omrade';
	surface_topo_info.snap_tolerance := 0.0000000001;

		-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.create_surface_edge_domain_obj_t0; 
		CREATE TABLE topo_rein.create_surface_edge_domain_obj_t0(geo_in geometry, IsSimple boolean, IsClosed boolean);
		INSERT INTO topo_rein.create_surface_edge_domain_obj_t0(geo_in,IsSimple,IsClosed) VALUES(geo_in,St_IsSimple(geo_in),St_IsSimple(geo_in));
	END IF;
	
	IF NOT ST_IsSimple(geo_in) THEN
		-- This is probably a crossing line so we try to build a surface
		geo_in := ST_ExteriorRing(ST_BuildArea(ST_UnaryUnion(geo_in)));
		-- check the object after a fix
		RAISE NOTICE 'Fixed a non simple line to be valid simple line by using by buildArea %',  geo_in;
	ELSIF NOT ST_IsClosed(geo_in) THEN
		-- If this is not closed just check that it intersects two times with a exting border
		-- TODO make more precice check that only used edges that in varbeite surface
		num_edge_intersects :=  (SELECT ST_NumGeometries(ST_collect(ST_Intersection(geo_in,e.geom))) FROM topo_rein_sysdata.edge_data e WHERE ST_Intersects(geo_in,e.geom))::int;
		RAISE NOTICE 'Found a non closed linestring does intersect % times, with any borders by using buildArea %', num_edge_intersects, geo_in;
		IF num_edge_intersects is null OR num_edge_intersects < 2 THEN
			geo_in := ST_ExteriorRing(ST_BuildArea(ST_UnaryUnion(ST_AddPoint(geo_in, ST_StartPoint(geo_in)))));
		ELSEIF num_edge_intersects > 2 THEN
			RAISE EXCEPTION 'Found a non valid linestring does intersect % times, with any borders by using buildArea %', num_edge_intersects, geo_in;
		END IF;
	END IF;

	IF add_debug_tables = 1 THEN
		INSERT INTO topo_rein.create_surface_edge_domain_obj_t0(geo_in,IsSimple,IsClosed) VALUES(geo_in,St_IsSimple(geo_in),St_IsSimple(geo_in));
	END IF;
	
	-- create the new topo object for the egde layer
	new_border_data := topo_update.create_surface_edge(geo_in);
	RAISE NOTICE 'The new topo object created for based on the input geo  %',  new_border_data;

	-- TODO insert some correct value for attributes
	INSERT INTO topo_rein.arstidsbeite_var_grense(grense, felles_egenskaper)
	SELECT new_border_data, topo_rein.get_rein_felles_egenskaper_linje(0);

	-- create the new topo object for the surfaces
	DROP TABLE IF EXISTS new_surface_data_for_edge; 
	-- find out if any old topo objects overlaps with this new objects using the relation table
	-- by using the surface objects owned by the both the new objects and the exting one
	CREATE TEMP TABLE new_surface_data_for_edge AS 
	(SELECT topo::topogeometry AS surface_topo FROM topo_update.create_edge_surfaces(new_border_data));
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of topo surfaces added to table new_surface_data_for_edge   %',  num_rows_affected;
	
	-- clean up old surface and return a list of the objects
	DROP TABLE IF EXISTS res_from_update_domain_surface_layer; 
	CREATE TEMP TABLE res_from_update_domain_surface_layer AS 
	(SELECT topo::topogeometry AS surface_topo FROM topo_update.update_domain_surface_layer('new_surface_data_for_edge'));
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number_of_rows removed from topo_update.update_domain_surface_layer   %',  num_rows_affected;

	-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.create_surface_edge_domain_obj_t1; 
		CREATE TABLE topo_rein.create_surface_edge_domain_obj_t1 AS 
		(SELECT surface_topo::geometry AS geo , surface_topo::text AS topo FROM new_surface_data_for_edge);

		-- get the reslt from topo_update.update_domain_surface_layer
		DROP TABLE IF EXISTS topo_rein.create_surface_edge_domain_obj_t2; 
		CREATE TABLE topo_rein.create_surface_edge_domain_obj_t2 AS 
		(SELECT surface_topo::geometry AS geo , surface_topo::text AS topo FROM res_from_update_domain_surface_layer);
	END IF;
	
	command_string := 'SELECT tg.id AS id FROM ' || surface_topo_info.layer_schema_name || '.' || surface_topo_info.layer_table_name || ' tg, new_surface_data_for_edge new WHERE (new.surface_topo).id = (tg.omrade).id';
    -- RAISE NOTICE '%', command_string;

    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;



--select topo_update.create_surface_edge_domain_obj('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.55375, 5.70152 58.55373, 5.70182 58.55131)');

-- select topo_update.create_surface_edge_domain_obj('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 4.80403 58.95375, 4.70152 58.55373, 5.70182 58.55131)');



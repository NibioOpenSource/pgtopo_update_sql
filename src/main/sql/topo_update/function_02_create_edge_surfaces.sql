-- Create new new surface object after after the new valid intersect line is dranw

-- DROP FUNCTION topo_update.create_edge_surfaces(topo topogeometry) cascade;


CREATE OR REPLACE FUNCTION topo_update.create_edge_surfaces(new_border_data topogeometry) 
RETURNS SETOF topo_update.topogeometry_def AS $$
DECLARE

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

-- holds the num rows affected when needed
num_rows_affected int;

-- number of rows to delete from org table
num_rows_to_delete int;

-- used for logging
add_debug_tables int = 1;


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
	
	-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);
	RAISE NOTICE 'border_layer_id   %',  border_layer_id ;
	
	-- find surface layer id
	surface_layer_id := topo_update.get_topo_layer_id(surface_topo_info);
	RAISE NOTICE 'surface_layer_id   %',  surface_layer_id ;

	RAISE NOTICE 'The topo objected added  %',  new_border_data;
	
	-------------------- Surface ---------------------------------

	DROP TABLE IF EXISTS new_surface_data; 
	-- Create a temp table to hold new surface data
	CREATE TEMP TABLE new_surface_data(surface_topo topogeometry);

	-- create surface geometry if a surface exits for the left side
	INSERT INTO new_surface_data(surface_topo)
	SELECT surface_topo FROM (
	SELECT 	topology.CreateTopoGeom('topo_rein_sysdata',3,surface_layer_id,topoelementarray  ) AS surface_topo 
	FROM ( 
			SELECT topology.TopoElementArray_Agg(ARRAY[b.face_id,3]) AS topoelementarray 
			FROM 
			(	
				SELECT DISTINCT(fa.face_id) as face_id
				FROM 
				topo_rein_sysdata.relation re,
				topo_rein_sysdata.edge_data ed,
				topo_rein_sysdata.face fa
				WHERE 
				(new_border_data).id = re.topogeo_id AND
			    re.layer_id =  border_layer_id AND 
			    re.element_type = 2 AND  -- TODO use variable element_type_edge=2
			    ed.edge_id = re.element_id AND
			    fa.face_id=ed.left_face AND -- How do I know if a should use left or right ?? 
			    fa.mbr IS NOT NULL
			) AS b
		) AS c
	) AS f
	WHERE surface_topo IS NOT NULL;
	    	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of topo objects found on the left side  % ',  num_rows_affected;

	
	-- create surface geometry if a surface exits for the rght side
	INSERT INTO new_surface_data(surface_topo)
	SELECT surface_topo FROM (
	SELECT 	topology.CreateTopoGeom('topo_rein_sysdata',3,surface_layer_id,topoelementarray  ) AS surface_topo 
	FROM ( 
			SELECT topology.TopoElementArray_Agg(ARRAY[b.face_id,3]) AS topoelementarray 
			FROM 
			(	
				SELECT DISTINCT(fa.face_id) as face_id
				FROM 
				topo_rein_sysdata.relation re,
				topo_rein_sysdata.edge_data ed,
				topo_rein_sysdata.face fa
				WHERE 
				(new_border_data).id = re.topogeo_id AND
			    re.layer_id =  border_layer_id AND 
			    re.element_type = 2 AND  -- TODO use variable element_type_edge=2
			    ed.edge_id = re.element_id AND
			    fa.face_id=ed.right_face AND -- How do I know if a should use left or right ?? 
			    fa.mbr IS NOT NULL
			) AS b
		) AS c
	) AS f
	WHERE surface_topo IS NOT NULL;

	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of topo objects found on the right side  % ',  num_rows_affected;
	
	-- create other tbales
	
		-- Only used for debug
	IF add_debug_tables = 1 THEN
	
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.create_edge_surfaces_t1; 
		CREATE TABLE topo_rein.create_edge_surfaces_t1 AS 
		(SELECT * FROM topo_rein_sysdata.relation where element_type = 2 and (new_border_data).id = topogeo_id);

		DROP TABLE IF EXISTS topo_rein.create_edge_surfaces_t2; 
		CREATE TABLE topo_rein.create_edge_surfaces_t2 AS 
		(SELECT * FROM topo_rein_sysdata.edge_data);

		DROP TABLE IF EXISTS topo_rein.create_edge_surfaces_t3; 
		CREATE TABLE topo_rein.create_edge_surfaces_t3 AS 
		(SELECT * FROM topo_rein_sysdata.face);
			
	END IF;

	
	
	-- We now objects that are missing attribute values that should be inheretaded from mother object.

		
	RETURN QUERY SELECT a.surface_topo::topogeometry as t FROM new_surface_data a;
	
END;
$$ LANGUAGE plpgsql;



-- SELECT * FROM topo_update.create_edge_surfaces((select topo_update.create_surface_edge('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.55375, 5.70152 58.55373, 5.70182 58.55131)'))::topogeometry)
		
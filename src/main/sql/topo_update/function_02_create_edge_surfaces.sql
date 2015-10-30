-- Create new new surface object after after the new valid intersect line is dranw

-- DROP FUNCTION topo_update.create_edge_surfaces(topo topogeometry) cascade;


CREATE OR REPLACE FUNCTION topo_update.create_edge_surfaces(new_border_data topogeometry, valid_user_geometry geometry) 
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
add_debug_tables int = 0;

-- used for looping
rec RECORD;

-- used for creating new topo objects
new_surface_topo topogeometry;

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

	-- find new facec that needs to be creted
	DROP TABLE IF EXISTS new_faces; 
	CREATE TEMP TABLE new_faces(face_id int);

	-- find left faces
	INSERT INTO new_faces(face_id) 
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
    fa.mbr IS NOT NULL;
    GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of face objects found on the left side  % ',  num_rows_affected;

    -- find right faces
	INSERT INTO new_faces(face_id) 
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
    fa.mbr IS NOT NULL;
    GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of face objects found on the right side  % ',  num_rows_affected;

	DROP TABLE IF EXISTS new_surface_data; 
	-- Create a temp table to hold new surface data
	CREATE TEMP TABLE new_surface_data(surface_topo topogeometry);
	-- create surface geometry if a surface exits for the left side

	-- if input is a closed ring only geneate objects for faces

	-- find faces used by exting topo objects to avoid duplicates
--	DROP TABLE IF EXISTS used_topo_faces; 
--	CREATE TEMP TABLE used_topo_faces AS (
--		SELECT used_faces.face_id 
--		FROM 
--		(SELECT (GetTopoGeomElements(v.omrade))[1] AS face_id 
--		FROM topo_rein.arstidsbeite_var_flate v) as used_faces,
--		topo_rein_sysdata.face f
--		WHERE f.face_id = used_faces.face_id AND
--		f.mbr && valid_user_geometry
--	);

	-- dont't create objects faces 
--	DROP TABLE IF EXISTS valid_topo_faces; 
--	CREATE TEMP TABLE  valid_topo_faces AS (
--		SELECT f.face_id FROM
--		topo_rein_sysdata.face f
--		WHERE ST_Covers(ST_Envelope(ST_buffer(valid_user_geometry,0.0000002)),f.mbr)
--	);


	FOR rec IN SELECT distinct face_id FROM new_faces
	LOOP
		--IF  NOT EXISTS(SELECT 1 FROM used_topo_faces WHERE face_id = rec.face_id) AND
		--EXISTS(SELECT 1 FROM valid_topo_faces WHERE face_id = rec.face_id) THEN 
		-- Test if this surface already used by another topo object
			new_surface_topo := topology.CreateTopoGeom('topo_rein_sysdata',3,surface_layer_id,topology.TopoElementArray_Agg(ARRAY[rec.face_id,3])  );
			-- if not null
			IF new_surface_topo IS NOT NULL THEN
				-- check if this topo already exist
				-- TODO find out this chck is needed then we can only check on id 
	--			IF NOT EXISTS(SELECT 1 FROM topo_rein.arstidsbeite_var_flate WHERE (omrade).id = (new_surface_topo).id) AND
	--			   NOT EXISTS(SELECT 1 FROM new_surface_data WHERE (surface_topo).id = (new_surface_topo).id)
	--			THEN
					INSERT INTO new_surface_data(surface_topo) VALUES(new_surface_topo);
					RAISE NOTICE 'Use new topo object % for face % created from user input %',  new_surface_topo, rec.face_id, new_border_data;
	--			ELSE
	--				RAISE NOTICE 'Not Use new topo object % for face %',  new_surface_topo, rec.face_id;
	--			END IF;
			END IF;
		--END IF;
    END LOOP;

    
	
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
		
		DROP TABLE IF EXISTS topo_rein.create_edge_surfaces_t4; 
		CREATE TABLE topo_rein.create_edge_surfaces_t4 AS 
		(SELECT * FROM new_faces);

			
	END IF;

	
	
	-- We now objects that are missing attribute values that should be inheretaded from mother object.

		
	RETURN QUERY SELECT a.surface_topo::topogeometry as t FROM new_surface_data a;
	
END;
$$ LANGUAGE plpgsql;



-- SELECT * FROM topo_update.create_edge_surfaces((select topo_update.create_surface_edge('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.55375, 5.70152 58.55373, 5.70182 58.55131)'))::topogeometry)
		
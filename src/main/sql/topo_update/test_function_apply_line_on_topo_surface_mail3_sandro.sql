DROP FUNCTION IF EXISTS  topo_update.apply_line_on_topo_surface(
geo_in geometry
);

-- TODO use default value maybe ??

CREATE OR REPLACE FUNCTION topo_update.apply_line_on_topo_surface(
geo_in geometry
) RETURNS int AS $$DECLARE
num_rows int;


-- this border layer id will picked up by input parameters
border_layer_id int;

-- this surface layer id will picked up by input parameters
surface_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

-- TODO use as parameter put for testing we just have here for now
border_topo_info topo_update.input_meta_info ;
surface_topo_info topo_update.input_meta_info ;


-- has loose_ends, default no
has_loose_ends int = -1;

-- hold striped gei

edge_with_out_loose_ends geometry = null;


BEGIN
	
	-- TODO to be moved is justed for testing now
	border_topo_info.topology_name := 'topo_rein_sysdata';
	border_topo_info.layer_schema_name := 'topo_rein';
	border_topo_info.layer_table_name := 'arstidsbeite_var_grense';
	border_topo_info.layer_feature_column := 'grense';
	border_topo_info.snap_tolerance := 0.0000000001;
	surface_topo_info.topology_name := 'topo_rein_sysdata';
	surface_topo_info.layer_schema_name := 'topo_rein';
	surface_topo_info.layer_table_name := 'arstidsbeite_var_flate';
	surface_topo_info.layer_feature_column := 'omrade';
	surface_topo_info.snap_tolerance := 0.0000000001;
	
	-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);
	
	-- find surface layer id
	surface_layer_id := topo_update.get_topo_layer_id(surface_topo_info);

	-- Create a border temp to hold data while we build them up to the data should into the org table
	-- This table created with no constraints, which means that all attributs may null in this temp table
	CREATE TEMP TABLE new_border_data AS (SELECT * FROM topo_rein.arstidsbeite_var_grense LIMIT 0);
	
	-- Holds of the id of rows inserted, we need this to keep track rows added to the main table
	CREATE TEMP TABLE IF NOT EXISTS ids_added_border_layer (
	        id integer
	);

	-- insert new top data into temp table.
	INSERT INTO new_border_data(grense) 
	SELECT topology.toTopoGeom(geo_in, 'topo_rein_sysdata', border_layer_id, border_topo_info.snap_tolerance) as grense;

	-- check if loos ends
	SELECT count(ed.*) INTO has_loose_ends
	FROM 
	topo_rein_sysdata.relation re,
	new_border_data ud, 
	topo_rein_sysdata.edge_data ed
	WHERE 
	(ud.grense).id = re.topogeo_id AND
	re.layer_id =  border_layer_id AND 
	re.element_type = 2 AND  -- TODO use variable element_type_edge=2
	ed.edge_id = re.element_id AND
	ed.left_face = 0 AND
	ed.right_face = 0;

	-- Test if there are any loose ends	
	IF has_loose_ends > 0 THEN
	-- Clean up loose ends	
	
		-- get the new line string with no loose ends
		SELECT ST_union(ed.geom) INTO edge_with_out_loose_ends 
		FROM 
		topo_rein_sysdata.relation re,
		new_border_data ud, 
		topo_rein_sysdata.edge_data ed
		WHERE 
		(ud.grense).id = re.topogeo_id AND
		re.layer_id =  border_layer_id AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		NOT (ed.left_face = 0 AND ed.right_face = 0);
		
		-- get a copy of the relation data we will need this for delete later
		CREATE TEMP TABLE re_copy AS 
		SELECT re.*
		FROM 
		topo_rein_sysdata.relation re,
		new_border_data ud 
		WHERE 
		(ud.grense).id = re.topogeo_id AND
		re.layer_id =  border_layer_id AND 
		re.element_type = 2;  -- TODO use variable element_type_edge=2

		-- clear the topo geometry 
		PERFORM topology.clearTopoGeom(ud.grense) 
		FROM new_border_data ud;
	
		-- Remove the edges 
		PERFORM ST_RemEdgeModFace(border_topo_info.topology_name, ed.edge_id)
		FROM 
		topo_rein_sysdata.relation re,
		new_border_data ud, 
		topo_rein_sysdata.edge_data ed
		WHERE 
		(ud.grense).id = re.topogeo_id AND
		re.layer_id =  border_layer_id AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		ed.left_face = 0 AND
		ed.right_face = 0;

-- 		failed to delete loose ends the hard way
--		DELETE FROM topo_rein_sysdata.edge_data ed
--		USING
--		re_copy re,
--		new_border_data ud
--		WHERE 
--		(ud.grense).id = re.topogeo_id AND
--		re.layer_id =  border_layer_id AND 
--		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
--		ed.edge_id = re.element_id AND
--		ed.left_face = 0 AND
--		ed.right_face = 0;
--	LOCATION:  exec_stmt_raise, pl_exec.c:3068
--psql:/Users/lop/dev/git/topologi/pgtopo_update/kode/trunk/src/main/sql/topo_update/test_function_apply_line_on_topo_surface_mail2_sandro.sql:291: ERROR:  23503: insert or update on table "edge_data" violates foreign key constraint "next_right_edge_exists"
--DETAIL:  Key (abs_next_right_edge)=(3) is not present in table "edge_data".
--SCHEMA NAME:  topo_rein_sysdata
--TABLE NAME:  edge_data
--CONSTRAINT NAME:  next_right_edge_exists


		
		
		-- clean up the temp table
		DELETE FROM new_border_data ud;

		-- insert new topo data with noe looes into temp table.
		INSERT INTO new_border_data(grense) 
		SELECT topology.toTopoGeom(edge_with_out_loose_ends, 'topo_rein_sysdata', border_layer_id, border_topo_info.snap_tolerance) as grense;
		
	END IF;

	
	-- set default values for felles_egenskaper so we don't get a not null value when insert into org table
	UPDATE new_border_data set felles_egenskaper = topo_rein.get_rein_felles_egenskaper_linje(0) ;
	
	-- TODO update other atributtes of exists

	
	-- copy data from tmp table into org table and keep track id's because they will needed further down here
	WITH border_layer_ids AS (
		INSERT INTO topo_rein.arstidsbeite_var_grense(grense, felles_egenskaper)
		SELECT grense, felles_egenskaper FROM new_border_data
		RETURNING id
	)
	INSERT INTO ids_added_border_layer(id) select id from border_layer_ids;

	-- update felles egenskaper and use table id as lokal id in felles egenskaper
	UPDATE topo_rein.arstidsbeite_var_grense AS u 
	SET felles_egenskaper=topo_rein.get_rein_felles_egenskaper_linje(i.id) 
	FROM ids_added_border_layer AS i WHERE i.id = u.id;

	
	

	-- create surface geometry if a surface exits for the left side
	INSERT INTO topo_rein.arstidsbeite_var_flate(omrade)
	SELECT omrade FROM (
	SELECT 	topology.CreateTopoGeom('topo_rein_sysdata',3,surface_layer_id,topoelementarray  ) AS omrade 
	FROM ( 
			SELECT topology.TopoElementArray_Agg(ARRAY[b.face_id,3]) AS topoelementarray 
			FROM 
			(	
				SELECT DISTINCT(fa.face_id) as face_id
				FROM 
				new_border_data ud, 
				topo_rein_sysdata.relation re,
				topo_rein_sysdata.edge_data ed,
				topo_rein_sysdata.face fa
				WHERE 
				(ud.grense).id = re.topogeo_id AND
			    re.layer_id =  border_layer_id AND 
			    re.element_type = 2 AND  -- TODO use variable element_type_edge=2
			    ed.edge_id = re.element_id AND
			    fa.face_id=ed.left_face AND -- How do I know if a should use left or right ?? 
			    fa.mbr IS NOT NULL
			    
			) AS b
		) AS c
	) AS f
	WHERE omrade IS NOT NULL;
	    	

	-- create surface geometry if a surface exits for the rght side
	INSERT INTO topo_rein.arstidsbeite_var_flate(omrade)
	SELECT omrade FROM (
	SELECT 	topology.CreateTopoGeom('topo_rein_sysdata',3,surface_layer_id,topoelementarray  ) AS omrade 
	FROM ( 
			SELECT topology.TopoElementArray_Agg(ARRAY[b.face_id,3]) AS topoelementarray 
			FROM 
			(	
				SELECT DISTINCT(fa.face_id) as face_id
				FROM 
				new_border_data ud, 
				topo_rein_sysdata.relation re,
				topo_rein_sysdata.edge_data ed,
				topo_rein_sysdata.face fa
				WHERE 
				(ud.grense).id = re.topogeo_id AND
			    re.layer_id =  border_layer_id AND 
			    re.element_type = 2 AND  -- TODO use variable element_type_edge=2
			    ed.edge_id = re.element_id AND
			    fa.face_id=ed.right_face AND -- How do I know if a should use left or right ?? 
			    fa.mbr IS NOT NULL
			    
			) AS b
		) AS c
	) AS f
	WHERE omrade IS NOT NULL;

	
	DROP TABLE ids_added_surface_layer;
	
	DROP TABLE new_border_data;

	DROP TABLE ids_added_border_layer;
	
	RAISE NOTICE 'Done job for for update geo  %',  clock_timestamp();

return num_rows;
END;
$$ LANGUAGE plpgsql;


-- test the function with goven structure
 DO $$
 DECLARE 
border_topo_info topo_update.input_meta_info;
-- this border layer id will picked up by input parameters
border_layer_id int;

edge_with_out_loose_ends geometry;

 BEGIN
	-- TODO to be moved is justed for testing now
	border_topo_info.topology_name := 'topo_rein_sysdata';
	border_topo_info.layer_schema_name := 'topo_rein';
	border_topo_info.layer_table_name := 'arstidsbeite_var_grense';
	border_topo_info.layer_feature_column := 'grense';
	border_topo_info.snap_tolerance := 0.0000000001;
 	border_topo_info.element_type := 2;

	-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);
 	
 
	CREATE TEMP TABLE new_border_data AS (SELECT * FROM topo_rein.arstidsbeite_var_grense LIMIT 0);
	
	-- insert new top data into temp table.
	INSERT INTO new_border_data(grense) 
	SELECT topology.toTopoGeom('SRID=4258;LINESTRING (5.701298 58.551259, 5.704312 58.553801)', 'topo_rein_sysdata', border_layer_id, border_topo_info.snap_tolerance) as grense;

	edge_with_out_loose_ends := topo_update.get_linestring_no_loose_ends(border_topo_info, 'new_border_data');

	-- find id's for loose edges

	CREATE TEMP TABLE old_relation  AS 
	(SELECT re.* FROM 
	topo_rein_sysdata.edge_data ed,
	new_border_data ud, 
	topo_rein_sysdata.relation re
	WHERE 
	(ud.grense).id = re.topogeo_id AND
	re.layer_id =  border_layer_id AND 
	re.element_type = 2 AND  -- TODO use variable element_type_edge=2
	ed.edge_id = re.element_id AND
	ed.left_face = 0 AND
	ed.right_face = 0
	);

	-- clear the topo geometry 
	PERFORM topology.clearTopoGeom(ud.grense) 
	FROM new_border_data ud;

	
	
	-- clear the loose ends 
--	DELETE FROM topo_rein_sysdata.edge_data ed
--	USING
--	new_border_data ud, 
--	old_relation re
--	WHERE 
--	(ud.grense).id = re.topogeo_id AND
--	re.layer_id =  border_layer_id AND 
--	re.element_type = 2 AND  -- TODO use variable element_type_edge=2
--	ed.edge_id = re.element_id AND
--	ed.left_face = 0 AND
--	ed.right_face = 0;
	
	
	DELETE FROM new_border_data ud;


	-- add the new line 
--	INSERT INTO new_border_data(grense) 
--	SELECT topology.toTopoGeom(edge_with_out_loose_ends, 'topo_rein_sysdata', border_layer_id, border_topo_info.snap_tolerance) as grense;

 END $$;

 	select * from topo_rein_sysdata.relation ;
	select edge_id,start_node,end_node,next_left_edge,abs_next_left_edge,next_right_edge,abs_next_right_edge,left_face,right_face from topo_rein_sysdata.edge_data;
	select face_id from topo_rein_sysdata.face;
	

	-- rempve loose edges 
	PERFORM ST_RemEdgeModFace(border_topo_info.topology_name, ed.edge_id)
		FROM 
		topo_rein_sysdata.relation re,
		new_border_data ud, 
		topo_rein_sysdata.edge_data ed
		WHERE 
		(ud.grense).id = re.topogeo_id AND
		re.layer_id =  border_layer_id AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		ed.left_face = 0 AND
		ed.right_face = 0;
	
	-- clear the topo geometry 
	PERFORM topology.clearTopoGeom(ud.grense) 
	FROM new_border_data ud;

	DELETE FROM new_border_data ud;

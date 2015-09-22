
-- This one is not used any more
--===============================

-- This code is a new way to think about how update topology
-- The basic idea is that you draw a line instring closed or non closed and that changes the underlying surface objects
-- Here is a example

--added a closed linestring
-- select topo_update.apply_line_on_topo_surface('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.55375, 5.70152 58.55373, 5.70182 58.55131)');

-- and I get this
--    ,---E3--.
--    |       |     
--    |       |
--    |       |
--    |       |
--    |       |
--    `-------'

-- added linstring that splits this polygon in two pices
-- select topo_update.apply_line_on_topo_surface('SRID=4258;LINESTRING (5.701298 58.551259, 5.702758 58.552522, 5.704312 58.553801)');

--
--    ,---E3--.
--    |       |     
--    |       |
--*------E---------------*
--    |       |
--    |       |
--    `-------'
--

-- And we end up with this where I have no loose ends

--
--    ,---E3--.
--    |       |     
--    |       |
--    *---E5--*
--    |       |
--    |       |
--    `---E4--'
--



-- Cut a line throuh one polygon.
-- The line has to go through the border of the polygon
-- Used to cut/split a polygon in 2 parts
-- The line can only go throug many pologons but only the polygon that contains the input point ise used


-- This code is experimental so we need to 
-- Change to use temp tables or varibales to hold temporay results
-- Fix all TODO in the code
-- TDDO Add attribute handling for lines and surfaces
-- TODO Add som return values that make sense and that can used in tests

-- DROP FUNCTION topo_update.apply_line_on_topo_surface(geo_in geometry);

CREATE OR REPLACE FUNCTION topo_update.apply_line_on_topo_surface(geo_in geometry,  srid_out int, maxdecimaldigits int) 
RETURNS geometry AS $$DECLARE

result geometry;

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

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- holds the num rows affected when needed
num_rows_affected int;

-- number of rows to delete from org table
num_rows_to_delete int;

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
	
	-- find surface layer id
	surface_layer_id := topo_update.get_topo_layer_id(surface_topo_info);

	-- Create a border temp to hold data while we build them up to the data should into the org table
	-- This table created with no constraints, which means that all attributs may null in this temp table
	CREATE TEMP TABLE new_border_data AS (SELECT * FROM topo_rein.arstidsbeite_var_grense LIMIT 0);
	
	-- Holds of the id of rows inserted, we need this to keep track rows added to the main table
	CREATE TEMP TABLE IF NOT EXISTS ids_added_border_layer ( id integer );

	-- insert new geo into topo border data.
	INSERT INTO new_border_data(grense) 
	SELECT topology.toTopoGeom(geo_in, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance) as grense;

	-- Test if there are any loose ends	
	-- TODO use topo object as input and not a object, since will bee one single topo object,
	-- TOTO add a test if this is a linestring or not
	-- but we may need line attributes then it's easier table as a parameter 
	IF topo_update.has_linestring_loose_ends(border_topo_info, 'new_border_data')  = 1 THEN
		-- Clean up loose ends	and ends that do not participate in surface
	
		-- get the new line string with no loose ends
		-- TODO we may here also use a topo object as a parameter, but that depends on if we need the the attributes 
		-- for to this line later 
		edge_with_out_loose_ends := topo_update.get_linestring_no_loose_ends(border_topo_info, 'new_border_data');
		
		
		
		-- get a copy of the relation data we added because we will need this for delete later
		command_string := FORMAT('
			CREATE TEMP TABLE old_relation AS ( 
			SELECT re.* 
			FROM 
			new_border_data ud, 
			%1$s re,
			%2$s ed
			WHERE 
			%3s  = re.topogeo_id AND
			re.layer_id =  %4$L AND 
			re.element_type = %5$L AND 
			ed.edge_id = re.element_id)',
			border_topo_info.topology_name || '.relation', -- the edge data name
			border_topo_info.topology_name || '.edge_data', -- the edge data name
			'(ud.' || border_topo_info.layer_feature_column || ').id', -- get feature colmun name
			border_layer_id,
			border_topo_info.element_type
		);
	    -- display the string
	    -- RAISE NOTICE '%', command_string;
		-- execute the string
	    EXECUTE command_string;

		-- clear out this new topo object, because we need to recreate it we the new linestring 
		PERFORM topology.clearTopoGeom(ud.grense) FROM new_border_data ud;
		DELETE FROM new_border_data;

		-- remove all edges and relations created with first topo object
		command_string := FORMAT('
			SELECT ST_RemEdgeModFace(%1$L, ed.edge_id)
			FROM 
			old_relation re,
			%2$s ed
			WHERE 
			re.layer_id =  %3$L AND 
			re.element_type = %4$L AND 
			ed.edge_id = re.element_id AND
			(
			(ed.left_face = 0 AND ed.right_face = 0) OR 
			(ed.left_face > 0 AND ed.right_face > 0 AND ed.left_face = ed.right_face)
			)
			',
			border_topo_info.topology_name,
			border_topo_info.topology_name || '.edge_data', -- the edge data name
			border_layer_id,
			border_topo_info.element_type
		);

	    -- RAISE NOTICE '%', command_string;

	    EXECUTE command_string;
		--We are done clean up loose ends from the first relations loose ends

	    -- TODO move this check outside this code block to handle input lines with now loose ends
	    -- TODO find out how to handle a line if crosses many surfaces with space beetween
	    -- We could here also run command that checks that containing face is not null, but hen we clean up that topo again also
	    -- So insetad we check this new line with no loose ends do cover a valid surface that can be done by checking
	    -- that both endpoint are toching a edges

	    
		RAISE NOTICE 'edge_with_out_loose_ends ::::   %',  ST_AsText(edge_with_out_loose_ends);
		
	    
	    DROP TABLE IF EXISTS edge_with_out_loose_ends ;
    	CREATE TEMP TABLE edge_with_out_loose_ends  AS (SELECT edge_with_out_loose_ends as geom);
		
	    
    	DROP TABLE IF EXISTS end_points ;
    	-- Create a temp table to hold new surface data
		CREATE TEMP TABLE end_points  AS (SELECT ST_StartPoint(edge_with_out_loose_ends) as geom);
		INSERT INTO end_points(geom) SELECT ST_EndPoint(edge_with_out_loose_ends) as geom;

		IF (EXISTS 
			(
			SELECT 1  
			FROM 
			topo_rein_sysdata.relation re1,
			topo_rein_sysdata.relation re2,
			topo_rein_sysdata.edge_data ed1,
			topo_rein_sysdata.edge_data ed2
			WHERE 
		    re1.layer_id =  border_layer_id AND 
		    re1.element_type = 2 AND  -- TODO use variable element_type_edge=2
		    ed1.edge_id = re1.element_id AND
		    ST_touches(ed1.geom,  ST_StartPoint(edge_with_out_loose_ends)) AND
		    --ST_DWithin(ed1.geom,  ST_StartPoint(edge_with_out_loose_ends), border_topo_info.snap_tolerance) AND 

		   	re2.layer_id =  border_layer_id AND 
		    re2.element_type = 2 AND  -- TODO use variable element_type_edge=2
		    ed2.edge_id = re2.element_id AND
		    ST_touches(ed2.geom,  ST_EndPoint(edge_with_out_loose_ends))
		    --ST_DWithin(ed2.geom,  ST_EndPoint(edge_with_out_loose_ends), border_topo_info.snap_tolerance)		    
		    )
		 ) THEN

		 	RAISE NOTICE 'Ok surface cutting line to add ----------------------';

			-- create new topo object with noe loose into temp table.
			INSERT INTO new_border_data(grense) 
			SELECT topology.toTopoGeom(edge_with_out_loose_ends, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance) as grense;
		
		ELSE 
			-- remove all because this is not valid line at all
			command_string := FORMAT('
				SELECT ST_RemEdgeModFace(%1$L, ed.edge_id)
				FROM 
				old_relation re,
				%2$s ed
				WHERE 
				re.layer_id =  %3$L AND 
				re.element_type = %4$L AND 
				ed.edge_id = re.element_id',
				border_topo_info.topology_name,
				border_topo_info.topology_name || '.edge_data', -- the edge data name
				border_layer_id,
				border_topo_info.element_type
			);
	
		    -- RAISE NOTICE '%', command_string;
	
		    EXECUTE command_string;
			--We are done clean up loose ends from the first relations loose ends

			RAISE NOTICE 'NOT Ok surface cutting line to add ----------------';

			END IF;
		
			-- drop old temp dara relation
			DROP TABLE old_relation;
	
	END IF;

	
	-- set default values for felles_egenskaper so we don't get a not null value when insert into org table
	UPDATE new_border_data set felles_egenskaper = topo_rein.get_rein_felles_egenskaper_linje(0) ;
	
	-- TODO update other atributtes of exists
	-- TODO handle egde overlap on topo level,
	
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

	
	
	-------------------- Surface ---------------------------------

	DROP TABLE IF EXISTS new_surface_data; 


	-- Create a temp table to hold new surface data
	CREATE TEMP TABLE new_surface_data AS (SELECT * FROM topo_rein.arstidsbeite_var_flate LIMIT 0);

	-- create surface geometry if a surface exits for the left side
	INSERT INTO new_surface_data(omrade,simple_geo)
	SELECT omrade, omrade:: geometry AS simple_geo FROM (
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
	INSERT INTO new_surface_data(omrade,simple_geo)
	SELECT omrade, omrade:: geometry AS simple_geo FROM (
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

	DROP TABLE IF EXISTS old_surface_data; 
	-- find out if any old topo objects overlaps with this new objects using the relation table
	-- by using the surface objects owned by the both the new objects and the exting one
	CREATE TEMP TABLE old_surface_data AS 
	(SELECT 
	re.* 
	FROM 
	topo_rein_sysdata.relation re,
	topo_rein_sysdata.relation re_tmp,
	new_surface_data new_sd
	WHERE 
	re.layer_id = surface_layer_id AND
	re.element_type = 3 AND
	re.element_id = re_tmp.element_id AND
	re_tmp.layer_id = surface_layer_id AND
	re_tmp.element_type = 3 AND
	(new_sd.omrade).id = re_tmp.topogeo_id AND
	(new_sd.omrade).id != re.topogeo_id);
	
	
	DROP TABLE IF EXISTS old_surface_data_not_in_new; 
	-- find any old objects that are not covered totaly by 
	-- this objets should not be deleted, but the geometry should only decrease in size.
	-- TODO add a test case for this
	CREATE TEMP TABLE old_surface_data_not_in_new AS 
	(SELECT 
	re.* 
	FROM 
	topo_rein_sysdata.relation re,
	old_surface_data re_tmp
	WHERE 
	re.layer_id = surface_layer_id AND
	re.element_type = 3 AND
	re.topogeo_id = re_tmp.topogeo_id AND
	re.element_id NOT IN (SELECT element_id FROM old_surface_data));
	
	
	DROP TABLE IF EXISTS old_rows_be_reused;
	-- IF old_surface_data_not_in_new is empty we know that all areas are coverbed by the new objects
	-- and we can delete/resuse this objects for the new rows
	CREATE TEMP TABLE old_rows_be_reused AS 
	-- we can have distinct here 
	(SELECT distinct(old_data_row.id) FROM 
	topo_rein.arstidsbeite_var_flate old_data_row,
	old_surface_data sf 
	WHERE (old_data_row.omrade).id = sf.topogeo_id);  
	
	-- We now know which rows we can reuse clear out old data rom the realation table
	UPDATE topo_rein.arstidsbeite_var_flate r
	SET omrade = clearTopoGeom(omrade)
	FROM old_rows_be_reused reuse
	WHERE reuse.id = r.id;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Number num_rows_affected  %',  num_rows_affected;

	SELECT (num_rows_affected - (SELECT count(*) FROM new_surface_data)) INTO num_rows_to_delete;

	RAISE NOTICE 'Number of new rows  %',  count(*) FROM new_surface_data;

	RAISE NOTICE 'Nnum rows to delete  %',  num_rows_to_delete;

	-- When overwrite we may have more rows in the org table so we may need do delete the rows not needed 
	-- from  topo_rein.arstidsbeite_var_flate, we the just delete the left overs 
	DELETE FROM topo_rein.arstidsbeite_var_flate
	WHERE ctid IN (
	SELECT r.ctid FROM
	topo_rein.arstidsbeite_var_flate r,
	old_rows_be_reused reuse
	WHERE reuse.id = r.id 
	LIMIT  greatest(num_rows_to_delete, 0));
	
	
	-- Resus old rows in topo_rein.arstidsbeite_var_flate and use as many values as possible
	-- We pick the new values from new_surface_data
	-- First we pick up values with the same topo object value id
	UPDATE topo_rein.arstidsbeite_var_flate old
	SET omrade = new.omrade
	FROM new_surface_data new,
	old_rows_be_reused reuse
	WHERE old.id = reuse.id ;
	
	
	-- insert missing rows
	INSERT INTO  topo_rein.arstidsbeite_var_flate(omrade)
	SELECT new.omrade 
	FROM new_surface_data new
	WHERE NOT EXISTS ( SELECT f.id FROM topo_rein.arstidsbeite_var_flate f WHERE (new.omrade).id = (f.omrade).id );

		
	-- a list of ar5_topo_linje polygons to be update
	CREATE TEMP TABLE IF NOT EXISTS ids_added_surface_layer (
		id integer
	);



		-- insert data and get copy of the new id's inserted
--	WITH surface_layer_ids AS (
--		INSERT INTO topo_rein.arstidsbeite_var_flate(omrade) 
--	SELECT  topology.toTopoGeom(geo_in, 'topo_rein_sysdata', border_layer_id+1, 0.0000000001) as omrade
--	RETURNING *
--	)
--	INSERT INTO ids_added_surface_layer(id) select id from surface_layer_ids;

	
	-- update identifikasjon
	-- bygd opp navnerom/lokalid/versjon
	-- navnerom: NO_LDIR_REINDRIFT_VAARBEITE
	-- versjon: 0
	-- lokalid:  rowid	
	-- eks identifikasjon = "NO_LDIR_REINDRIFT_VAARBEITE 0 199999999"

	
	
	DROP TABLE ids_added_surface_layer;
	
	DROP TABLE new_border_data;
	
	-- DROP TABLE new_surface_data;

	-- DROP TABLE old_border_data;
	
	-- DROP TABLE old_border_data_not_in_new ;
	
	-- DROP TABLE old_border_data_in_new;
	
	DROP TABLE ids_added_border_layer;
	
--	RAISE NOTICE 'Done job for for update geo  %',  clock_timestamp();

--	RAISE EXCEPTION 'Error in topo update, no new polygons created by line (%) and point (%) after update.',  geo_in, p_in  USING HINT = 'This is a bug in topo_update.apply_polygon_on_topo_flate';

--	result = topo_rein.get_var_flate_topojson(srid_out,maxdecimaldigits)::varchar;
-- this is hack to return wkt
	SELECT ST_Collect(ST_transform(simple_geo,srid_out)) FROM new_surface_data INTO result;
	
	RETURN result;

END;
$$ LANGUAGE plpgsql;




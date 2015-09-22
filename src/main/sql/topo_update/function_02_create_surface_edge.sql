
-- this creates a valid edge based on the surface that alreday exits
-- the geometry in must be in the same coord system as the exting edge layer
-- return a set valid edges that may used be used by topo object later
-- the egdes may be old ones or new ones

CREATE OR REPLACE FUNCTION topo_update.create_surface_edge(geo_in geometry) 
RETURNS topogeometry   AS $$DECLARE

-- result 
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

	-- Holds of the id of rows inserted, we need this to keep track rows added to the main table
	CREATE TEMP TABLE IF NOT EXISTS ids_added_border_layer ( id integer );

	-- get new topo border data.
	new_border_data := topology.toTopoGeom(geo_in, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance); 

	-- Test if there are any loose ends	
	-- TODO use topo object as input and not a object, since will bee one single topo object,
	-- TOTO add a test if this is a linestring or not
	-- but we may need line attributes then it's easier table as a parameter 
	IF topo_update.has_linestring_loose_ends(border_topo_info, new_border_data)  = 1 THEN
		-- Clean up loose ends	and ends that do not participate in surface
	
		-- get the new line string with no loose ends
		-- TODO we may here also use a topo object as a parameter, but that depends on if we need the the attributes 
		-- for to this line later 
		edge_with_out_loose_ends := topo_update.get_linestring_no_loose_ends(border_topo_info, new_border_data);
		
		
		
		-- get a copy of the relation data we added because we will need this for delete later
		command_string := FORMAT('
			CREATE TEMP TABLE old_relation AS ( 
			SELECT re.* 
			FROM 
			%1$s re,
			%2$s ed
			WHERE 
			%3s  = re.topogeo_id AND
			re.layer_id =  %4$L AND 
			re.element_type = %5$L AND 
			ed.edge_id = re.element_id)',
			border_topo_info.topology_name || '.relation', -- the edge data name
			border_topo_info.topology_name || '.edge_data', -- the edge data name
			new_border_data.id, -- get feature colmun name
			border_layer_id,
			border_topo_info.element_type
		);
	    -- display the string
	    -- RAISE NOTICE '%', command_string;
		-- execute the string
	    EXECUTE command_string;

		-- clear out this new topo object, because we need to recreate it we the new linestring 
		PERFORM topology.clearTopoGeom(new_border_data);

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
		new_border_data := topology.toTopoGeom(edge_with_out_loose_ends, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance);
		
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
	
			-- TODO add test if the lines are new or not
			-- drop old temp dara relation
			DROP TABLE old_relation;
	
	END IF;

	RETURN new_border_data;

END;
$$ LANGUAGE plpgsql;



-- select topo_update.create_surface_edge('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.55375, 5.70152 58.55373, 5.70182 58.55131)');



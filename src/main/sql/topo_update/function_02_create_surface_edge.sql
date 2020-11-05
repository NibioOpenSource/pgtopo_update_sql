
-- this creates a valid edge based on the surface that alreday exits
-- the geometry in must be in the same coord system as the exting edge layer
-- return a set valid edges that may used be used by topo object later
-- the egdes may be old ones or new ones

drop FUNCTION if exists topo_update.create_surface_edge(geo_in_org geometry, 
border_topo_info topo_update.input_meta_info);

CREATE OR REPLACE FUNCTION topo_update.create_surface_edge(geo_in_org geometry, 
border_topo_info topo_update.input_meta_info) 
RETURNS topology.topogeometry   AS $$DECLARE

-- result 
new_border_data topology.topogeometry;

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

command_result text;

geo_in geometry;

pre_cut boolean = false;

  v_state text;
  v_msg text;
  v_detail text;
  v_hint text;
  v_context text;

BEGIN
	
	
	-- Holds of the id of rows inserted, we need this to keep track rows added to the main table
	CREATE TEMP TABLE IF NOT EXISTS ids_added_border_layer ( id integer );
	
	-- Here the egde layer can only be used på layer
	IF st_isclosed(geo_in_org) = false THEN
		command_string := FORMAT('
		select r.split_line 
		from (
		select r.split_line, sum((start_p_dist+end_p_dist)) as total_dist from (
		select r.split_line,
		ST_Distance(e.geom,start_p) start_p_dist,
		ST_Distance(e.geom,end_p) end_p_dist
		from
		(
		select distinct r.split_line, ST_StartPoint(r.split_line) start_p, ST_EndPoint(r.split_line) end_p
		from
		(
		SELECT (ST_Dump(split_line)).geom as split_line
		from
		(
		SELECT ST_Split(%1$L,e.geom) as split_line
		from
		( select ST_collect(e.geom) as geom
		 from %2$s.edge e
		 where ST_intersects(e.geom,%1$L)
		) as e
		) as r
		) as r
		) as r,
		(select ST_Union(e.geom) as geom from %2$s.edge e where e.geom && %1$L and ST_Intersects(e.geom,%1$L)) as e
		) as r
		group by r.split_line
		order by total_dist
		limit 1
		) as r
		', 
		geo_in_org,
		border_topo_info.topology_name);
		
		BEGIN
			execute command_string into geo_in;
			pre_cut := true;
			RAISE NOTICE 'execute command_string %',  command_string;
			RAISE NOTICE 'geo_in_org % geo_in % ',  geo_in_org, geo_in;
		
		EXCEPTION WHEN OTHERS THEN
		    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT, v_detail = PG_EXCEPTION_DETAIL, v_hint = PG_EXCEPTION_HINT,
		                v_context = PG_EXCEPTION_CONTEXT;
		    RAISE NOTICE 'FAILED  to run split command, use the original input geo % , state:%  message:% detail:% hint: % context:%', 
		    command_string, v_state, v_msg, v_detail, v_hint, v_context;
		    geo_in := geo_in_org;
		END;
	
	ELSE 
		RAISE NOTICE 'st_isclosed(geo_in_org) % geo % do c',  st_isclosed(geo_in_org), geo_in_org;
		geo_in := geo_in_org;
	END IF;

--geo_in := geo_in_org;

	-- get new topo border data.
	new_border_data := topology.toTopoGeom(geo_in, border_topo_info.topology_name, border_topo_info.border_layer_id, border_topo_info.snap_tolerance); 
	

	-- Test if there are any loose ends	
	-- TODO use topo object as input and not a object, since will bee one single topo object,
	-- TOTO add a test if this is a linestring or not
	-- TODO add a tes if this has no loose ends
	-- but we may need line attributes then it's easier table as a parameter
 
	IF pre_cut = false and topo_update.has_linestring_loose_ends(border_topo_info, new_border_data)  = 1 THEN
	
		RAISE NOTICE 'Has loose ends for layer for new_border_data.id % , with line %', new_border_data.id, new_border_data;

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
			border_topo_info.border_layer_id,
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
			border_topo_info.border_layer_id,
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

		command_string := FORMAT('SELECT 1  
                        FROM 
                        %I.relation re1,
                        %I.relation re2,
                        %I.edge_data ed1,
                        %I.edge_data ed2
                        WHERE 
                    re1.layer_id =  %L AND 
                    re1.element_type = %L AND  
                    ed1.edge_id = re1.element_id AND
                    ST_touches(ed1.geom,  ST_StartPoint(%L)) AND
                    re2.layer_id =  %L AND 
                    re2.element_type = %L AND  -- TODO use variable element_type_edge=2
                    ed2.edge_id = re2.element_id AND
                    ST_touches(ed2.geom,  ST_EndPoint(%L))
					limit 1',
                        border_topo_info.topology_name,
                        border_topo_info.topology_name,
                        border_topo_info.topology_name,
                        border_topo_info.topology_name,
                        border_topo_info.border_layer_id,
                        border_topo_info.element_type,
                        edge_with_out_loose_ends,
                        border_topo_info.border_layer_id,
                        border_topo_info.element_type,
                        edge_with_out_loose_ends
                );

       	RAISE NOTICE 'command_string is %',  command_string;

        EXECUTE command_string into command_result;
		
        
		IF command_result IS NOT NULL THEN

	 	RAISE NOTICE 'Ok surface cutting line to add ----------------------';

		-- create new topo object with noe loose into temp table.
		new_border_data := topology.toTopoGeom(edge_with_out_loose_ends, border_topo_info.topology_name, border_topo_info.border_layer_id, border_topo_info.snap_tolerance);
		
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
				border_topo_info.border_layer_id,
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




-- SELECT topo_update.create_surface_edge_domain_obj('{"type":"Feature","geometry":{"type":"LineString","coordinates":[[604234.7038121773,7791627.722893095],[604238.9112709841,7791613.15861261],[604252.6664247754,7791623.515434288],[604232.4382574352,7791624.486386321]],"crs":{"type":"name","properties":{"name":"EPSG:25835"}}},"properties":{"fellesegenskaper.opphav":null,"fellesegenskaper.kvalitet.synbarhet":null,"fellesegenskaper.kvalitet.noyaktighet":null,"fellesegenskaper.kvalitet.maalemetode":82,"fellesegenskaper.oppdateringsdato":null,"fellesegenskaper.verifiseringsdato":"2020-11-03","avgrensing_type":null,"fellesegenskaper.forstedatafangstdato":"2020-11-03"}}', 
-- SELECT topo_update.create_surface_edge_domain_obj('{"type":"Feature","geometry":{"type":"LineString","coordinates":[[604232.9112709841,7791612.15861261],[604253.6664247754,7791624.515434288],[604235.4382574352,7791627.486386321]],"crs":{"type":"name","properties":{"name":"EPSG:25835"}}},"properties":{"fellesegenskaper.opphav":null,"fellesegenskaper.kvalitet.synbarhet":null,"fellesegenskaper.kvalitet.noyaktighet":null,"fellesegenskaper.kvalitet.maalemetode":82,"fellesegenskaper.oppdateringsdato":null,"fellesegenskaper.verifiseringsdato":"2020-11-03","avgrensing_type":null,"fellesegenskaper.forstedatafangstdato":"2020-11-03"}}', 
-- SELECT topo_update.create_surface_edge_domain_obj('{"type":"Feature","geometry":{"type":"LineString","coordinates":[[604365.620511203,7791663.486292952],[604348.4670252985,7791641.801697563]],"crs":{"type":"name","properties":{"name":"EPSG:25835"}}},"properties":{"fellesegenskaper.opphav":null,"fellesegenskaper.kvalitet.synbarhet":null,"fellesegenskaper.kvalitet.noyaktighet":null,"fellesegenskaper.kvalitet.maalemetode":82,"fellesegenskaper.oppdateringsdato":null,"fellesegenskaper.verifiseringsdato":"2020-11-03","avgrensing_type":null,"fellesegenskaper.forstedatafangstdato":"2020-11-03"}}',    
--        'topo_ar5_sysdata_webclient_t2',
--        'face_attributes',
--        'geo',
--        'edge_attributes',
--        'geo',
--        '1e-10',
--        '{"properties":{"status":"10","saksbehandler":"m","reinbeitebruker_id":"WF","fellesegenskaper.opphav":"NIBIO"}}'
--        );


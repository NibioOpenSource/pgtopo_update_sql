
-- this creates a valid edge based on the surface that alreday exits
-- the geometry in must be in the same coord system as the exting edge layer
-- return a set valid edges that may used be used by topo object later
-- the egdes may be old ones or new ones

CREATE OR REPLACE FUNCTION topo_update.create_surface_edge(geo_in_org geometry,
border_topo_info topo_update.input_meta_info)
RETURNS topology.topogeometry
AS $BODY$ --{
DECLARE

	-- result
	new_border_data topology.topogeometry;

	-- holds dynamic sql to be able to use the same code for different
	sql text;

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
		sql := FORMAT('
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
			execute sql into geo_in;
			pre_cut := true;
			RAISE NOTICE 'execute sql %',  sql;
			RAISE NOTICE 'geo_in_org % geo_in % ',  geo_in_org, geo_in;

		EXCEPTION WHEN OTHERS THEN
		    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT, v_detail = PG_EXCEPTION_DETAIL, v_hint = PG_EXCEPTION_HINT,
		                v_context = PG_EXCEPTION_CONTEXT;
		    RAISE NOTICE 'FAILED  to run split command, use the original input geo % , state:%  message:% detail:% hint: % context:%',
		    sql, v_state, v_msg, v_detail, v_hint, v_context;
		    geo_in := geo_in_org;
		END;

	ELSE
		RAISE NOTICE 'st_isclosed(geo_in_org) % geo % do c',  st_isclosed(geo_in_org), geo_in_org;
		geo_in := geo_in_org;
	END IF;

--geo_in := geo_in_org;

	-- get new topo border data.
	new_border_data := topology.toTopoGeom(geo_in, border_topo_info.topology_name, border_topo_info.border_layer_id, border_topo_info.snap_tolerance);


	-- Clean up loose ends and ends that do not participate in surface

	-- Test if there are any loose ends
	-- TODO use topo object as input and not a object, since will bee one single topo object,
	-- TOTO add a test if this is a linestring or not
	-- TODO add a tes if this has no loose ends
	-- but we may need line attributes then it's easier table as a parameter

	IF pre_cut = false
		-- and topo_update.has_linestring_loose_ends(border_topo_info, new_border_data)  = 1
	THEN
		sql := format(
			$$
DELETE FROM %1$I.relation r
WHERE r.layer_id = %2$L
AND r.topogeo_id = %3$L
AND r.element_id IN (
	SELECT e.edge_id
	FROM %1$I.edge_data e
	JOIN %1$I.relation r ON (e.edge_id = r.element_id)
	WHERE e.edge_id = r.element_id
	AND e.left_face = e.right_face
	AND r.layer_id = %2$L
	AND r.topogeo_id = %3$L
)
			$$,
			border_topo_info.topology_name, -- %1$
			id(new_border_data),            -- %2$
			layer_id(new_border_data)       -- %3$
		);
		RAISE DEBUG 'SQL: %', sql;
		EXECUTE sql;
	END IF;

	RETURN new_border_data;

END; --}
$BODY$ LANGUAGE plpgsql;

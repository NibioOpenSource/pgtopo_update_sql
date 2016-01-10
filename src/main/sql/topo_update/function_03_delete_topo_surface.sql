-- delete surface that intersects with given point

CREATE OR REPLACE FUNCTION topo_update.delete_topo_surface(id_in int,  layer_schema text, 
  surface_layer_table text, surface_layer_column text,
  border_layer_table text, border_layer_column text
) 
RETURNS int AS $$DECLARE

num_rows int;


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

-- Geometry
delete_surface geometry;


BEGIN
	
	-- get meta data
	border_topo_info := topo_update.make_input_meta_info(layer_schema, border_layer_table , border_layer_column );

	surface_topo_info := topo_update.make_input_meta_info(layer_schema, surface_layer_table , surface_layer_column );

	SELECT omrade::geometry FROM topo_rein.arstidsbeite_var_flate r WHERE id = id_in INTO delete_surface;
        

    PERFORM topology.clearTopoGeom(omrade) FROM topo_rein.arstidsbeite_var_flate r
    WHERE id = id_in;
    
    DELETE FROM topo_rein.arstidsbeite_var_flate r
    WHERE id = id_in;
    
    
    GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

    RAISE NOTICE 'Rows deleted  %',  num_rows_affected;

    -- Find unused edges 
    DROP TABLE IF EXISTS ttt_unused_edge_ids;
    CREATE TEMP TABLE ttt_unused_edge_ids AS 
    (
		SELECT topo_rein.get_edges_within_faces(array_agg(x),border_topo_info) AS id from  topo_rein.get_unused_faces(surface_topo_info.border_layer_id) x
    );
    
    -- Find linear objects related to his edges 
    DROP TABLE IF EXISTS ttt_affected_border_objects;
    command_string := FORMAT('CREATE TEMP TABLE ttt_affected_border_objects AS 
    (
		select distinct ud.id
	    FROM 
		%I.relation re,
		%I.%I ud, 
		%I.edge_data ed,
		ttt_unused_edge_ids ued
		WHERE 
		(ud.%I).id = re.topogeo_id AND
		re.layer_id =  %L AND 
		re.element_type = %L AND
		ed.edge_id = re.element_id AND
		ed.edge_id = ANY(ued.id)
    )',
    border_topo_info.topology_name,
    border_topo_info.layer_schema_name,
	border_topo_info.layer_table_name,
    border_topo_info.topology_name,
   	border_topo_info.layer_feature_column,
   	border_topo_info.border_layer_id,
    border_topo_info.element_type
	);
	-- RAISE NOTICE '%', command_string;
    EXECUTE command_string;
    
    -- Create geoms for for linal objects with out edges that will be deleted
    DROP TABLE IF EXISTS ttt_new_border_objects;
    command_string := FORMAT('CREATE TEMP TABLE ttt_new_border_objects AS 
    (
		SELECT ud.id, ST_Union(ed.geom) AS geom 
	    FROM 
		%I.relation re,
		%I.%I ud, 
		%I.edge_data ed,
		ttt_unused_edge_ids ued,
		ttt_affected_border_objects ab
		WHERE 
		ab.id = ud.id AND
		(ud.%I).id = re.topogeo_id AND
		re.layer_id =  %L AND 
		re.element_type = %L AND
		ed.edge_id = re.element_id AND
		NOT (ed.edge_id = ANY(ued.id))
		GROUP BY ud.id
    )',
    border_topo_info.topology_name,
    border_topo_info.layer_schema_name,
	border_topo_info.layer_table_name,
    border_topo_info.topology_name,
    border_topo_info.layer_feature_column,
    border_topo_info.border_layer_id,
    border_topo_info.element_type
    
	);
	-- RAISE NOTICE '%', command_string;
    EXECUTE command_string;

	
    -- Delete border topo objects
    command_string := FORMAT('SELECT topology.clearTopoGeom(a.%I) 
	FROM %I.%I  a,
    ttt_affected_border_objects b
	WHERE a.id = b.id', 
	border_topo_info.layer_feature_column,
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name
	);
	-- RAISE NOTICE '%', command_string;
    EXECUTE command_string;

	
	
 	-- Remove edges not used from the edge table
 	command_string := FORMAT('
		SELECT ST_RemEdgeModFace(%1$L, ed.edge_id)
		FROM 
		ttt_unused_edge_ids ued,
		%2$s ed
		WHERE 
		ed.edge_id = ANY(ued.id) 
		',
		border_topo_info.topology_name,
		border_topo_info.topology_name || '.edge_data'
	);
	-- RAISE NOTICE '%', command_string;
    EXECUTE command_string;
	
	-- Delete those rows don't have any geoms left
	command_string := FORMAT('DELETE FROM %I.%I  a
	USING ttt_new_border_objects b
	WHERE a.id = b.id AND b.geom IS NULL',
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name
	);
	-- RAISE NOTICE '%', command_string;
    EXECUTE command_string;

	

	
		command_string := format('UPDATE %I.%I AS a
	SET %I = topology.toTopoGeom(b.geom, %L, %L, %L)
	FROM ttt_new_border_objects b
	WHERE a.id = b.id AND b.geom IS NOT NULL',
  	border_topo_info.layer_schema_name,
  	border_topo_info.layer_table_name,
	border_topo_info.layer_feature_column,
	border_topo_info.topology_name, 
	border_topo_info.border_layer_id, 
	border_topo_info.snap_tolerance
  );

	-- RAISE NOTICE '%', command_string;
    EXECUTE command_string;

    
	
	
    RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;


--{ kept for backward compatility
CREATE OR REPLACE FUNCTION topo_update.delete_topo_surface(id_in int) 
RETURNS int AS $$
 SELECT topo_update.delete_topo_surface($1, 'topo_rein', 'arstidsbeite_var_flate', 'omrade', 'arstidsbeite_var_grense','grense');
$$ LANGUAGE 'sql';
--}

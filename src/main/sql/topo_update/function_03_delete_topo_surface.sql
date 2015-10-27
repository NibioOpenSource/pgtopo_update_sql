-- delete surface that intersects with given point

CREATE OR REPLACE FUNCTION topo_update.delete_topo_surface(id_in int) 
RETURNS int AS $$DECLARE

num_rows int;


-- this border layer id will picked up by input parameters
border_layer_id int;

-- this surface layer id will picked up by input parameters
surface_layer_id int;

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

	SELECT omrade::geometry FROM topo_rein.arstidsbeite_var_flate r WHERE id = id_in INTO delete_surface;
        

    PERFORM topology.clearTopoGeom(omrade) FROM topo_rein.arstidsbeite_var_flate r
    WHERE id = id_in;
    
    DELETE FROM topo_rein.arstidsbeite_var_flate r
    WHERE id = id_in;
    
    
    GET DIAGNOSTICS num_rows_to_delete = ROW_COUNT;

    RAISE NOTICE 'Rows deleted  %',  num_rows_to_delete;

    -- Find unused edges 
    DROP TABLE IF EXISTS tmp_unused_edge_ids;
    CREATE TEMP TABLE tmp_unused_edge_ids AS 
    (
		SELECT                                                                          
		topo_rein.get_edges_within_faces(array_agg(x)) AS id from                            
		topo_rein.get_unused_faces() x
    );
    
    -- Used for debug
    DROP TABLE IF EXISTS tmp_unused_edge_geos;
    CREATE TEMP TABLE tmp_unused_edge_geos AS 
    (
		SELECT ed.geom, ed.edge_id FROM
		topo_rein_sysdata.edge_data ed,
		tmp_unused_edge_ids ued
		WHERE ed.edge_id = ANY(ued.id)
    );


    -- Find linear objects related to his edges 
    DROP TABLE IF EXISTS tmp_affected_border_objects;
    CREATE TEMP TABLE tmp_affected_border_objects AS 
    (
		select distinct ud.id
	    FROM 
		topo_rein_sysdata.relation re,
		topo_rein.arstidsbeite_var_grense ud, 
		topo_rein_sysdata.edge_data ed,
		tmp_unused_edge_ids ued
		WHERE 
		(ud.grense).id = re.topogeo_id AND
		re.layer_id =  border_layer_id AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		ed.edge_id = ANY(ued.id)
    );
    
    -- Create geoms for for linal objects with out edges that will be deleted
    DROP TABLE IF EXISTS tmp_new_border_objects;
    CREATE TEMP TABLE tmp_new_border_objects AS 
    (
		SELECT ud.id, ST_Union(ed.geom) AS geom 
	    FROM 
		topo_rein_sysdata.relation re,
		topo_rein.arstidsbeite_var_grense ud, 
		topo_rein_sysdata.edge_data ed,
		tmp_unused_edge_ids ued,
		tmp_affected_border_objects ab
		WHERE 
		ab.id = ud.id AND
		(ud.grense).id = re.topogeo_id AND
		re.layer_id =  border_layer_id AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		NOT (ed.edge_id = ANY(ued.id))
		GROUP BY ud.id
    );
	
    -- Delete border topo objects
    PERFORM topology.clearTopoGeom(a.grense) 
    FROM topo_rein.arstidsbeite_var_grense a,
    tmp_affected_border_objects b
	WHERE a.id = b.id;
	
 	-- Remove edges not used from the edge table
	command_string := FORMAT('
	SELECT ST_RemEdgeModFace(%1$L, ed.edge_id)
	FROM 
	tmp_unused_edge_ids ued,
	%2$s ed
	WHERE 
	ed.edge_id = ANY(ued.id) 
	',
	border_topo_info.topology_name,
	border_topo_info.topology_name || '.edge_data'
	);
	
	RAISE NOTICE '%', command_string;

    EXECUTE command_string;
	
	-- Delete those rows don't have any geoms left
	DELETE FROM topo_rein.arstidsbeite_var_grense a
	USING tmp_new_border_objects b
	WHERE a.id = b.id AND b.geom IS NULL;
	

    -- update new topo objects topo values
	UPDATE topo_rein.arstidsbeite_var_grense AS a
	SET grense =  topology.toTopoGeom(b.geom, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance)
	FROM tmp_new_border_objects b
	WHERE a.id = b.id AND b.geom IS NOT NULL;
	
	
    		    
    DROP TABLE IF EXISTS topo_rein.delete_surface;
    CREATE TABLE topo_rein.delete_surface AS 
    (
    SELECT delete_surface as geom
    );	

    RETURN num_rows_to_delete;

END;
$$ LANGUAGE plpgsql;


--UPDATE topo_rein.arstidsbeite_var_flate r
--SET reindrift_sesongomrade_kode = null;

-- select * from topo_update.delete_topo_surface('{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[-39993,6527853],[-39980,6527867],[-39955,6527864],[-39973,6527837],[-40005,6527840],[-39993,6527853]]],"crs":{"type":"name","properties":{"name":"EPSG:32632"}}},"properties":{"reinbeitebruker_id":null,"reindrift_sesongomrade_kode":2}}');

--select * from topo_update.delete_topo_surface('{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[-40034,6527765],[-39904,6527747],[-39938,6527591],[-40046,6527603],[-40034,6527765]]]},"properties":{"reinbeitebruker_id":null,"reindrift_sesongomrade_kode":null}}');


-- SELECT * FROM topo_rein.arstidsbeite_var_flate;


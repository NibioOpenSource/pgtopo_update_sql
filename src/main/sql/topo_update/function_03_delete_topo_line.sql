-- delete line that intersects with given point

CREATE OR REPLACE FUNCTION topo_update.delete_topo_line(id_in int) 
RETURNS int AS $$DECLARE


-- holds the num rows affected when needed
num_rows_affected int;
-- TODO use as parameter put for testing we just have here for now
border_topo_info topo_update.input_meta_info ;

-- holds dynamic sql to be able to use the same code for different
command_string text;

border_layer_id int;

BEGIN
	
		-- TODO to be moved is justed for testing now
	border_topo_info.topology_name := 'topo_rein_sysdata';
	border_topo_info.layer_schema_name := 'topo_rein';
	border_topo_info.layer_table_name := 'reindrift_anlegg_linje';
	border_topo_info.layer_feature_column := 'linje';
	border_topo_info.snap_tolerance := 0.0000000001;
	border_topo_info.element_type = 2;
		-- find border layer id
		
	
	-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);
	

	    -- Find linear objects related to his edges 
    DROP TABLE IF EXISTS ttt_edge_list;
    CREATE TEMP TABLE ttt_edge_list AS 
    (
		select distinct ed.edge_id
	    FROM 
		topo_rein_sysdata.relation re,
		topo_rein.reindrift_anlegg_linje al, 
		topo_rein_sysdata.edge_data ed
		WHERE 
		al.id = id_in AND
		(al.linje).id = re.topogeo_id AND
		re.layer_id =  border_layer_id AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		NOT EXISTS ( SELECT 1 FROM topo_rein_sysdata.relation re2 WHERE  ed.edge_id = re2.element_id AND re2.topogeo_id != re.topogeo_id) 

    );

    
	PERFORM topology.clearTopoGeom(linje) FROM topo_rein.reindrift_anlegg_linje r
	WHERE id = id_in;

	
	DELETE FROM topo_rein.reindrift_anlegg_linje r
	WHERE id = id_in;

	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Rows deleted  %',  num_rows_affected;
	
	

			-- Remove edges not used from the edge table
 	command_string := FORMAT('
			SELECT ST_RemEdgeModFace(%1$L, ed.edge_id)
			FROM 
			ttt_edge_list ued,
			%2$s ed
			WHERE 
			ed.edge_id = ued.edge_id 
			',
			border_topo_info.topology_name,
			border_topo_info.topology_name || '.edge_data'
		);

	RAISE NOTICE 'command_string %', command_string;

	EXECUTE command_string;

	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;


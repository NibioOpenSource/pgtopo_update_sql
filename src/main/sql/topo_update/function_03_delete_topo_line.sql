-- delete line that intersects with given point

CREATE OR REPLACE FUNCTION topo_update.delete_topo_line(id_in int) 
RETURNS int AS $$DECLARE


-- holds the num rows affected when needed
num_rows_affected int;


BEGIN
	
	PERFORM topology.clearTopoGeom(linje) FROM topo_rein.reindrift_anlegg_linje r
	WHERE id = id_in;

	
	DELETE FROM topo_rein.reindrift_anlegg_linje r
	WHERE id = id_in;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Rows deleted  %',  num_rows_affected;
	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;


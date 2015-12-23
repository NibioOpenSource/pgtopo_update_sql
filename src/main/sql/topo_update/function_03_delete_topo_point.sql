-- delete line that intersects with given point

CREATE OR REPLACE FUNCTION topo_update.delete_topo_point(id_in int,layer_schema text, layer_table text, layer_column text)  
RETURNS int AS $$DECLARE


-- holds the num rows affected when needed
num_rows_affected int;


BEGIN

	PERFORM topology.clearTopoGeom(punkt) FROM topo_rein.reindrift_anlegg_punkt r
	WHERE id = id_in;


	DELETE FROM topo_rein.reindrift_anlegg_punkt r
	WHERE id = id_in;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Rows deleted  %',  num_rows_affected;
	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;

--{ kept for backward compatility
CREATE OR REPLACE FUNCTION topo_update.delete_topo_point(id_in int) 
RETURNS TABLE(id integer) AS $$
  SELECT topo_update.delete_topo_point($1, 'topo_rein', 'reindrift_anlegg_punkt', 'punkt');
$$ LANGUAGE 'sql';
--}

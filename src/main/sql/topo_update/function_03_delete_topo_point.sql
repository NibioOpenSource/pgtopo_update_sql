-- delete line that intersects with given point

CREATE OR REPLACE FUNCTION topo_update.delete_topo_point(id_in int,layer_schema text, layer_table text, layer_column text)  
RETURNS int AS $$DECLARE


-- holds the num rows affected when needed
num_rows_affected int;

-- holds dynamic sql to be able to use the same code for different
command_string text;

BEGIN

	command_string := format('SELECT topology.clearTopoGeom(%s) FROM  %I.%I r WHERE id = %s',
	layer_column,
    layer_schema,
    layer_table,
    id_in);

	RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string;

    command_string := format('DELETE FROM %I.%I r
	WHERE id = %s',
    layer_schema,
    layer_table,
    id_in);

    RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string;
	
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

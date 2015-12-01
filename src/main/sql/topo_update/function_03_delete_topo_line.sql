-- delete line with given id from given layer

CREATE OR REPLACE FUNCTION topo_update.delete_topo_line(id_in int,layer_schema text, layer_table text, layer_column text) 
RETURNS int AS $$DECLARE

-- holds the num rows affected when needed
num_rows_affected int;

-- hold common needed in this proc
border_topo_info topo_update.input_meta_info ;

-- holds dynamic sql to be able to use the same code for different
command_string text;

BEGIN

	-- get meta data
	border_topo_info := topo_update.make_input_meta_info(layer_schema, layer_table , layer_column );

	-- %s interpolates the corresponding argument as a string; %I escapes its argument as an SQL identifier; %L escapes its argument as an SQL literal; %% outputs a literal %.
	
	-- Find linear objects related to his edges 
    command_string := FORMAT('
    DROP TABLE IF EXISTS ttt_edge_list;
    CREATE TEMP TABLE ttt_edge_list AS 
    (
		select distinct ed.edge_id
	    FROM 
		%1$I.relation re,
		%2$I.%3$I al, 
		%1$I.edge_data ed
		WHERE 
		al.id = %4$L AND
		(al.linje).id = re.topogeo_id AND
		re.layer_id =  %5$L AND 
		re.element_type = %6$L AND  
		ed.edge_id = re.element_id AND
		NOT EXISTS ( SELECT 1 FROM %1$I.relation re2 WHERE  ed.edge_id = re2.element_id AND re2.topogeo_id != re.topogeo_id) 
    )',
    border_topo_info.topology_name,
    border_topo_info.layer_schema_name,
	border_topo_info.layer_table_name,
	id_in,
	border_topo_info.border_layer_id,
	border_topo_info.element_type
	);
	RAISE NOTICE 'command_string %', command_string;
  	EXECUTE command_string;

   
  	-- Clear the topogeom before delete
	command_string := FORMAT('SELECT topology.clearTopoGeom(a.%I) FROM %I.%I  a WHERE a.id = %L',
	border_topo_info.layer_feature_column,
 	border_topo_info.layer_schema_name,
  	border_topo_info.layer_table_name,
  	id_in
  	);
	RAISE NOTICE 'command_string %', command_string;
  	EXECUTE command_string;


	-- Delete the line from the org table
	command_string := FORMAT('DELETE FROM %I.%I a WHERE a.id = %L',
	border_topo_info.layer_schema_name,
  	border_topo_info.layer_table_name,
  	id_in
  	);
	RAISE NOTICE 'command_string %', command_string;
  	EXECUTE command_string;

	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Rows deleted  %',  num_rows_affected;
	
	

			-- Remove edges not used from the edge table
 	command_string := FORMAT('
			SELECT ST_RemEdgeModFace(%1$L, ed.edge_id)
			FROM 
			ttt_edge_list ued,
			%1$I.edge_data ed
			WHERE 
			ed.edge_id = ued.edge_id 
			',
			border_topo_info.topology_name
		);

	RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string;
	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;



--{ kept for backward compatility
CREATE OR REPLACE FUNCTION topo_update.delete_topo_line(id_in int) 
RETURNS TABLE(id integer) AS $$
  SELECT topo_update.delete_topo_line($1, 'topo_rein', 'reindrift_anlegg_linje', 'linje');
$$ LANGUAGE 'sql';
--}




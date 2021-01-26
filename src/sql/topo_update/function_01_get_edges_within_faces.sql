-- Return a set of identifiers for edges within
-- the union of given faces
CREATE OR REPLACE FUNCTION topo_rein.get_edges_within_faces(faces int[], border_topo_info topo_update.input_meta_info  )
RETURNS int[]
AS $$DECLARE

-- holds dynamic sql to be able to use the same code for different
command_string text;

result int[];

BEGIN

command_string := FORMAT('SELECT array_agg(e.edge_id)
  FROM %I.edge_data e,
  %I.relation re
  WHERE e.left_face = ANY ( %L )
    AND e.right_face = ANY ( %L )
    AND e.edge_id = re.element_id 
    AND re.layer_id =  %L',
   border_topo_info.topology_name,
   border_topo_info.topology_name,
    faces,
    faces,
  	border_topo_info.border_layer_id
	);
	-- RAISE NOTICE '%', command_string;
EXECUTE command_string INTO result;
    
RETURN result;
		
END;
$$ LANGUAGE plpgsql;

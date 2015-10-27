-- Return a set of identifiers for edges within
-- the union of given faces
CREATE OR REPLACE FUNCTION topo_rein.get_edges_within_faces(faces int[], layer_id_in int )
RETURNS int[] AS
$$
  SELECT array_agg(e.edge_id)
  FROM topo_rein_sysdata.edge_data e,
  topo_rein_sysdata.relation re
  WHERE e.left_face = ANY ( faces )
    AND e.right_face = ANY ( faces )
    AND e.edge_id = re.element_id 
    AND re.layer_id =  layer_id_in;
		
$$ LANGUAGE 'sql' VOLATILE;

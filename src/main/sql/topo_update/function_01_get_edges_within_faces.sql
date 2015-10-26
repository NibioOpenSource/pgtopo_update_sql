-- Return a set of identifiers for edges within
-- the union of given faces
CREATE OR REPLACE FUNCTION topo_rein.get_edges_within_faces(faces int[])
RETURNS int[] AS
$$
  SELECT array_agg(e.edge_id)
  FROM topo_rein_sysdata.edge_data e
  WHERE e.left_face = ANY ( faces )
    AND e.right_face = ANY ( faces )
$$ LANGUAGE 'sql' VOLATILE;

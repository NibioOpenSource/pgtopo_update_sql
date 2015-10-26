-- Return a set of identifiers for edges within a surface TopoGeometry
--
--{
CREATE OR REPLACE FUNCTION topo_rein.get_edges_within_toposurface(tg TopoGeometry)
RETURNS int[] AS
$$
  WITH tgdata as (
    select array_agg(r.element_id) as faces
    from topo_rein_sysdata.relation r
    where topogeo_id = id($1)
      and layer_id = layer_id($1)
      and element_type = 3 -- a face
  )
  SELECT array_agg(e.edge_id)
  FROM topo_rein_sysdata.edge_data e, tgdata t
  WHERE e.left_face = ANY ( t.faces )
    AND e.right_face = ANY ( t.faces );
$$ LANGUAGE 'sql' VOLATILE;


-- Return the faces that are not used by any TopoGeometry
CREATE OR REPLACE FUNCTION topo_rein.get_unused_faces()
RETURNS setof int AS
$$
    SELECT f.face_id as faces
    FROM
      topo_rein_sysdata.face f
    EXCEPT
    SELECT r.element_id
    FROM
      topo_rein_sysdata.relation r,
      topology.layer l
    WHERE r.layer_id = l.layer_id 
      and l.level = 0 -- non hierarchical
      and r.element_type = 3 -- a face
$$ LANGUAGE 'sql' VOLATILE;

-- Return a set of identifiers for edges that are not covered
-- by any surface TopoGeometry

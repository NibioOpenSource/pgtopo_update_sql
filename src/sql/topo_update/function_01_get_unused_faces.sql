-- Return the faces that are not used by any TopoGeometry
CREATE OR REPLACE FUNCTION topo_rein.get_unused_faces(surface_topo_info topo_update.input_meta_info)
RETURNS setof int
AS $$DECLARE

-- holds dynamic sql to be able to use the same code for different
command_string text;

BEGIN

command_string := FORMAT('
    SELECT f.face_id as faces
    FROM
      %I.face f
    EXCEPT
    SELECT r.element_id
    FROM
      %I.relation r,
      topology.layer l
    WHERE r.layer_id = l.layer_id 
      and l.layer_id = %L
      and l.level = 0 -- non hierarchical
      and r.element_type = 3 -- a face',
   surface_topo_info.topology_name,
   surface_topo_info.topology_name,
   surface_topo_info.border_layer_id);

	-- RAISE NOTICE '%', command_string;
    RETURN QUERY EXECUTE  command_string;

END;
$$ LANGUAGE plpgsql;

-- Return a set of identifiers for edges that are not covered
-- by any surface TopoGeometry

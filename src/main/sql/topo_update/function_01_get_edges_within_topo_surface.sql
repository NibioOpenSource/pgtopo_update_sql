-- Return a set of identifiers for edges within a surface TopoGeometry
--
--{
CREATE OR REPLACE FUNCTION topo_rein.get_edges_within_toposurface(tg TopoGeometry,border_topo_info topo_update.input_meta_info)
RETURNS int[]
AS $$DECLARE

-- holds dynamic sql to be able to use the same code for different
command_string text;

result int[];

BEGIN

command_string := FORMAT('WITH tgdata as (
    select array_agg(r.element_id) as faces
    from %I.relation r
    where topogeo_id = id($1)
      and layer_id = layer_id($1)
      and element_type = 3 -- a face
  )
  SELECT array_agg(e.edge_id)
  FROM %I.edge_data e, tgdata t
  WHERE e.left_face = ANY ( t.faces )
    AND e.right_face = ANY ( t.faces )',
   border_topo_info.topology_name,
   border_topo_info.topology_name
   
	);
	-- RAISE NOTICE '%', command_string;
EXECUTE command_string INTO result;
    
RETURN result;

		
END;
$$ LANGUAGE plpgsql;

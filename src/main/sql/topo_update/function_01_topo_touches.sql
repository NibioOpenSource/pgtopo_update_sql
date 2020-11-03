
-- find one row that intersecst with the row is sent using the 
-- The id_to_check check reffers to row with that comtains a face object (a topo object), get faceid form this object 
-- TODO find teh one with loongts egde

-- DROP FUNCTION IF EXISTS topo_update.touches(_new_topo_objects regclass,id_to_check int) ;

CREATE OR REPLACE FUNCTION topo_update.touches(_new_topo_objects regclass, id_to_check int,surface_topo_info topo_update.input_meta_info) 
RETURNS int AS $$DECLARE
DECLARE 
command_string text;
res int;
BEGIN

command_string := format('select a.id from
(  
  select distinct unnest(array_agg(array[e1.right_face , e1.left_face])) as face_id
  from 
    ( select 
       distinct e.edge_id
       from
       (select (GetTopoGeomElements(%1$s))[1] as face_id ,id from  %2$s where id = %4$s) f,
       %3$I.edge e
       where (e.right_face = f.face_id or e.left_face = f.face_id)
    ) as edge_list_first,
    %3$I.edge e1
  where e1.edge_id  = edge_list_first.edge_id
) as fa,
%3$I.relation r,
%2$s a
where fa.face_id > 0 and r.element_type = 3 and r.layer_id = %5$s
and fa.face_id = r.element_id
and r.topogeo_id = topo_update.get_relation_id(a.%1$s)
and a.id != %4$s',
surface_topo_info.layer_feature_column,
_new_topo_objects,
surface_topo_info.topology_name,
id_to_check,
surface_topo_info.border_layer_id);

RAISE NOTICE 'command_string touches %',  command_string;

EXECUTE command_string INTO res;

RETURN res;

END;
$$ LANGUAGE plpgsql;


--SELECT * FROM topo_update.touches('topo_rein.arstidsbeite_var_flate',10);

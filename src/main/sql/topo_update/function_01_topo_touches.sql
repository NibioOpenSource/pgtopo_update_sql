
-- find one row that intersecst
-- TODO find teh one with loongts egde

-- DROP FUNCTION IF EXISTS topo_update.touches(_new_topo_objects regclass,id_to_check int) ;

CREATE OR REPLACE FUNCTION topo_update.touches(_new_topo_objects regclass, id_to_check int,surface_topo_info topo_update.input_meta_info) 
RETURNS int AS $$DECLARE
DECLARE 
command_string text;
res int;
BEGIN


-- TODO rewrite code

CREATE TEMP TABLE IF NOT EXISTS idlist_temp(id_t int[]);

--IF EXISTS (SELECT * FROM pg_tables WHERE tablename='idlist_temp') THEN	
	TRUNCATE TABLE idlist_temp;
--ELSE 
--	CREATE TEMP TABLE  idlist_temp(id_t int[]);
--END IF;

--DROP TABLE IF EXISTS idlist_temp;
--CREATE TEMP TABLE  idlist_temp(id_t int[]);

command_string := format('INSERT INTO idlist_temp(id_t) 
SELECT object_id_list as id_t 
FROM ( SELECT array_agg( object_id) object_id_list, count(*) as antall
  FROM (
	WITH faces AS (
	  SELECT (GetTopoGeomElements(%1$s))[1] face_id, id AS object_id FROM (
	    SELECT %1$s, id from  %2$s 
	  ) foo
	),
	faces_group_by_face_id_object_id AS ( 
	  SELECT array_agg(face_id) face_id_ids, face_id, object_id 
      FROM faces
      GROUP BY face_id, object_id
	) 
	SELECT object_id, face_id, e.edge_id 
	FROM 
    %3$I.edge e, 
    faces_group_by_face_id_object_id f
	WHERE  
    (  
      (e.left_face = any (f.face_id_ids) and not e.right_face = any (f.face_id_ids))
	  OR (e.right_face = any (f.face_id_ids) and not e.left_face = any (f.face_id_ids)) 
    )
  ) AS t
  GROUP BY t.edge_id
) AS r
WHERE antall > 1
AND object_id_list[1] != object_id_list[2]
AND (object_id_list[1] = %4$L OR object_id_list[2] =%4$L)
ORDER BY id_t',
surface_topo_info.layer_feature_column,
_new_topo_objects,
surface_topo_info.topology_name,
id_to_check);

--RAISE NOTICE 'command_string touches %',  command_string;

EXECUTE command_string;

DROP TABLE IF EXISTS idlist;

CREATE TEMP TABLE  idlist(id int);

INSERT INTO idlist(id) SELECT id_t[1] AS id FROM idlist_temp WHERE id_to_check != id_t[1];
INSERT INTO idlist(id) SELECT id_t[2] AS id FROM idlist_temp WHERE id_to_check != id_t[2];

SELECT id FROM idlist limit 1 into res;

RAISE NOTICE 'command_string touches result is % with (%) ', res, command_string;

RETURN res;

END;
$$ LANGUAGE plpgsql;


--SELECT * FROM topo_update.touches('topo_rein.arstidsbeite_var_flate',10);

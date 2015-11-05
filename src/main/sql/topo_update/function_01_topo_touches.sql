
-- find one row that intersecst
-- TODO find teh one with loongts egde

-- DROP FUNCTION IF EXISTS topo_update.touches(_new_topo_objects regclass,id_to_check int) ;

CREATE OR REPLACE FUNCTION topo_update.touches(_new_topo_objects regclass, id_to_check int) 
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
SELECT id_list as id_t FROM 
	( SELECT array_agg( object_id) id_list, count(*) as antall
	  FROM (
	  WITH
	  faces AS (
	    SELECT (GetTopoGeomElements(omrade))[1] face_id, id AS object_id FROM (
	      SELECT omrade, id from  %1$s 
	    ) foo
	  ),
	  ary AS ( 
	    SELECT array_agg(face_id) ids, face_id, object_id FROM faces
	    GROUP BY face_id, object_id
	  )
	  SELECT object_id, face_id, e.edge_id 
	  FROM topo_rein_sysdata.edge e, ary f
	  WHERE ( left_face = any (f.ids) and not right_face = any (f.ids) )
	     OR ( right_face = any (f.ids) and not left_face = any (f.ids) )
	  ) AS t
	  GROUP BY edge_id
  	) AS r
WHERE antall > 1
AND id_list[1] != id_list[2]
AND (id_list[1] = %2$L OR id_list[2] = %2$L)
ORDER BY id_t', _new_topo_objects, id_to_check);

RAISE NOTICE 'command_string %',  command_string;

EXECUTE command_string;

DROP TABLE IF EXISTS idlist;

CREATE TEMP TABLE  idlist(id int);

INSERT INTO idlist(id) SELECT id_t[1] AS id FROM idlist_temp WHERE id_to_check != id_t[1];
INSERT INTO idlist(id) SELECT id_t[2] AS id FROM idlist_temp WHERE id_to_check != id_t[2];

SELECT id FROM idlist limit 1 into res;

RETURN res;

END;
$$ LANGUAGE plpgsql;


--SELECT * FROM topo_update.touches('topo_rein.arstidsbeite_var_flate',10);

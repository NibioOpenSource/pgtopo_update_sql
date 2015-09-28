-- Return a topojson document with the contents of the query results
-- topojson specs:
-- https://github.com/mbostock/topojson-specification/blob/master/README.md
--
-- NOTE: will use TopoGeometry identifier as the feature identifier
--
--{
CREATE OR REPLACE FUNCTION topo_rein.query_to_topojson(query text, srid_out int, maxdecimaldigits int)
RETURNS text AS
$$
DECLARE
  tmptext text;
  outary text[];
  objary text[];
  rec RECORD;
  rec2 RECORD;
  json_result text;
  fname_topogeom text;
  fname_attributes text[];
  typname text;
  toponame text;
  topology_id int;
  sql text;
BEGIN


  outary := ARRAY['{"type":"Topology","objects":{'];

  CREATE TEMP TABLE topo_rein_topojson_edgemap
      (arc_id serial primary key, edge_id int);

  -- Find TopoGeometry and attributes names
  sql := 'SELECT * FROM ( ' || query || ') foo LIMIT 1';
  FOR rec IN EXECUTE sql
  LOOP
    FOR rec2 IN SELECT json_object_keys(row_to_json(rec)) fn
    LOOP
      sql := 'SELECT pg_typeof(' || quote_ident(rec2.fn) ||
              ') FROM ( ' || query ||
              ') foo LIMIT 1';
      --RAISE DEBUG '%', sql;
      EXECUTE sql INTO STRICT typname;
      RAISE NOTICE 'Field: % of type %', rec2.fn, typname;
      IF typname = 'topogeometry' THEN
        IF fname_topogeom IS NULL THEN
          fname_topogeom := rec2.fn;
        ELSE
          RAISE WARNING 'TopoGeometry field "%" ignored as we found "%" already', rec2.fn, fname_topogeom;
        END IF;
      ELSIF typname = 'geometry' OR typname = 'geography' THEN
          RAISE WARNING '"%" field "%" ignored', typname, rec2.fn;
      ELSE
        fname_attributes := fname_attributes || quote_ident(rec2.fn);
      END IF;
    END LOOP;
  END LOOP;

  IF fname_topogeom IS NULL THEN
    RAISE EXCEPTION 'No TopoGeometry field in query result';
  END IF;

  -- Add features (objects) array

  sql := 'SELECT id(' || quote_ident(fname_topogeom) ||
      '), AsTopoJSON(' || quote_ident(fname_topogeom) ||
      ', ''topo_rein_topojson_edgemap'') as obj, ' || 
      'topology_id(' || quote_ident(fname_topogeom) || 
      '), row_to_json( (SELECT t1 FROM ( SELECT ' ||
      -- attributes to include in output
      array_to_string(fname_attributes, ',') ||
      ') as t1)) as prop ' || 
      ' FROM ( ' || query || ' ) foo';
  FOR rec IN EXECUTE sql
  LOOP
    IF topology_id IS NULL THEN
      topology_id := rec.topology_id;
    ELSIF topology_id != rec.topology_id THEN
      RAISE EXCEPTION 'TopoGeometry from different topologies mixed in query results';
    END IF;
    objary := objary || array_to_string(ARRAY[
          '"', rec.id::text, '":',
          substring(rec.obj from 0 for length(rec.obj)),
          ',"properties":',
          rec.prop::text,
          '}'
          ], '');
  END LOOP;

  sql := 'SELECT name FROM topology.topology WHERE id = ' || topology_id;
  EXECUTE sql INTO STRICT toponame;

  outary := outary || array_to_string(objary, ',');

  outary := outary || '},"arcs": ['::text;

  -- Add arcs

  sql := 'SELECT array_agg(ST_AsGeoJSON(' ||
      'ST_transform(e.geom,$1),$2' ||
      ')::json->>''coordinates'' ' ||
      'ORDER BY m.arc_id) FROM topo_rein_topojson_edgemap m ' ||
      'INNER JOIN ' || quote_ident(toponame) || '.edge e ' ||
      'ON (e.edge_id = m.edge_id)';
  RAISE DEBUG '%', sql;
  EXECUTE sql USING srid_out,maxdecimaldigits INTO objary;

  outary = outary || array_to_string(objary, ',');

  outary = outary || ']}'::text;

  RAISE DEBUG '%', array_to_string(outary, '');
  
  DROP TABLE topo_rein_topojson_edgemap;
  
  json_result = array_to_string(outary, '')::varchar;
  RETURN json_result;

END;
$$ LANGUAGE 'plpgsql' VOLATILE;
--}

-- Return a topojson document with the contents of
-- topo_rein.arstidsbeite_var_flate table
-- topojson specs:
-- https://github.com/mbostock/topojson-specification/blob/master/README.md

-- env used to select bounding box area
-- srid_out is the srid data put are transformed to
-- maxdecimaldigits the number og digets used for update
--
-- TODO: re-write as a wrapper to query_to_topojson ?
--{
CREATE OR REPLACE FUNCTION topo_rein.get_var_flate_topojson(env box2d, srid_out int, maxdecimaldigits int)
RETURNS text AS
$$
DECLARE
  tmptext text;
  outary text[];
  objary text[];
  rec RECORD;
  json_result text;
BEGIN

  outary := ARRAY['{"type":"Topology","objects":{'];

  CREATE TEMP TABLE topo_rein_topojson_edgemap
      (arc_id serial primary key, edge_id int);

  FOR rec IN SELECT
      id,
      AsTopoJSON(tg.omrade, 'topo_rein_topojson_edgemap') as obj,
      row_to_json( (SELECT t1 FROM ( SELECT
          -- attributes to include in output
          id, reinbeitebruker_id, reindrift_sesongomrade_kode
      ) as t1)) as prop
    FROM topo_rein.arstidsbeite_var_flate tg
    WHERE
      -- NOTE: could be optimized to use edge index instead
      st_envelope(tg.omrade) && env
  LOOP
    objary := objary || array_to_string(ARRAY[
          '"', rec.id::text, '":',
          substring(rec.obj from 0 for length(rec.obj)),
          ',"properties":',
          rec.prop::text,
          '}'
          ], '');
  END LOOP;

  outary := outary || array_to_string(objary, ',');

  outary := outary || '},"arcs": ['::text;

  -- Add arcs

  -- Added hardcoded st_transform TODO add paramerter 
  SELECT array_agg(ST_AsGeoJSON(ST_transform(e.geom,srid_out),maxdecimaldigits)::json->>'coordinates'
  -- SELECT array_agg(ST_AsGeoJSON(e.geom, 6)::json->>'coordinates'
                   ORDER BY m.arc_id)
    FROM topo_rein_topojson_edgemap m
    INNER JOIN topo_rein_sysdata.edge e
    ON (e.edge_id = m.edge_id)
    --ORDER BY m.arc_id
  INTO objary;

  outary = outary || array_to_string(objary, ',');

  outary = outary || ']}'::text;

  RAISE DEBUG '%', array_to_string(outary, '');
  
  DROP TABLE topo_rein_topojson_edgemap;
  
  json_result = array_to_string(outary, '')::varchar;
  RETURN json_result;

END;
$$ LANGUAGE 'plpgsql' VOLATILE;
--}

CREATE OR REPLACE FUNCTION topo_rein.get_var_flate_topojson(srid_out int, maxdecimaldigits int)
RETURNS TEXT
AS $$
  SELECT topo_rein.get_var_flate_topojson(ST_MakeEnvelope(
            '-Infinity', '-Infinity', 'Infinity', 'Infinity'), srid_out, maxdecimaldigits)
$$ LANGUAGE 'sql' VOLATILE;



-- This function sould be replaced by the function avouve

--{
-- env used to select bounding box area
-- srid_out is the srid data put are transformed to
-- maxdecimaldigits the number og digets used for update
--
-- TODO: deprecate in favour of query_to_topojson ?
--
CREATE OR REPLACE FUNCTION topo_rein.get_var_flate_topojson(_new_topo_objects regclass, srid_out int, maxdecimaldigits int)
RETURNS text AS
$$
DECLARE
  tmptext text;
  outary text[];
  objary text[];
  rec RECORD;
  json_result text;
BEGIN


-- get the rows from the regclass
-- this is hack for testing

		-- get the data into a new tmp table
DROP TABLE IF EXISTS new_surface_data; 


EXECUTE format('CREATE TEMP TABLE new_surface_data AS (SELECT * FROM %s)', _new_topo_objects);
	
	
  outary := ARRAY['{"type":"Topology","objects":{'];

  CREATE TEMP TABLE topo_rein_topojson_edgemap
      (arc_id serial primary key, edge_id int);

  FOR rec IN SELECT
      id,
      AsTopoJSON(tg.omrade, 'topo_rein_topojson_edgemap') as obj,
      row_to_json( (SELECT t1 FROM ( SELECT
          -- attributes to include in output
          id, reinbeitebruker_id, reindrift_sesongomrade_kode
      ) as t1)) as prop
    FROM topo_rein.arstidsbeite_var_flate tg,
		new_surface_data new
   	WHERE (new.surface_topo).id = (tg.omrade).id
  LOOP
    objary := objary || array_to_string(ARRAY[
          '"', rec.id::text, '":',
          substring(rec.obj from 0 for length(rec.obj)),
          ',"properties":',
          rec.prop::text,
          '}'
          ], '');
  END LOOP;

  outary := outary || array_to_string(objary, ',');

  outary := outary || '},"arcs": ['::text;

  -- Add arcs

  -- Added hardcoded st_transform TODO add paramerter 
  SELECT array_agg(ST_AsGeoJSON(ST_transform(e.geom,srid_out),maxdecimaldigits)::json->>'coordinates'
  -- SELECT array_agg(ST_AsGeoJSON(e.geom, 6)::json->>'coordinates'
                   ORDER BY m.arc_id)
    FROM topo_rein_topojson_edgemap m
    INNER JOIN topo_rein_sysdata.edge e
    ON (e.edge_id = m.edge_id)
    --ORDER BY m.arc_id
  INTO objary;

  outary = outary || array_to_string(objary, ',');

  outary = outary || ']}'::text;

  RAISE DEBUG '%', array_to_string(outary, '');
  
  DROP TABLE topo_rein_topojson_edgemap;
  
  json_result = array_to_string(outary, '')::varchar;
  RETURN json_result;

END;
$$ LANGUAGE 'plpgsql' VOLATILE;
--}

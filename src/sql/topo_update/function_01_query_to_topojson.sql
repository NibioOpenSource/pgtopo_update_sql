-- Return a topojson document with the contents of the query results
-- topojson specs:
-- https://github.com/mbostock/topojson-specification/blob/master/README.md
--
-- NOTE: will use TopoGeometry identifier as the feature identifier
--
--{
CREATE OR REPLACE FUNCTION topo_update.query_to_topojson(query text, srid_out int, maxdecimaldigits int, simplify_patteren int,bb geometry)
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
  crs text;
  sql text;
  obj_json text;
BEGIN


  -- Find CRS corresponding to output srid
  SELECT auth_name || ':' || auth_srid
    FROM spatial_ref_sys
    WHERE srid = srid_out
    INTO crs;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'SRID % is not found in spatial_ref_sys', srid_out;
  END IF;

--  Use relative coordinates 
--  outary := ARRAY[
--    '{"type":"Topology",
--      "transform":    {    "scale":    [1,1],    "translate":    [0,0]    }, 
--      "crs":{"type":"name","properties":{"name":"',
--    crs,
--  '"}}'];

  outary := ARRAY[
    '{"type":"Topology", "crs":{"type":"name","properties":{"name":"',
    crs,
  '"}}'];

  CREATE TEMP TABLE topology_topojson_edgemap
      (arc_id serial primary key, edge_id int, arc text, signed_edge_id_fa int, geom geometry);
  -- TODO could be unique, if performance problem
  CREATE INDEX ON topology_topojson_edgemap(edge_id);

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

  IF NOT FOUND THEN
    DROP TABLE topology_topojson_edgemap;
    RETURN NULL;
  END IF;

  IF fname_topogeom IS NULL THEN
    RAISE EXCEPTION 'No TopoGeometry field in query result';
  END IF;

  -- Add features (objects) array

  sql := 'SELECT ' || quote_ident(fname_topogeom) || ' as obj';

  --RAISE DEBUG 'fname_attributes is: %', fname_attributes;

  IF fname_attributes IS NOT NULL THEN
    sql := sql || ', row_to_json( (SELECT t1 FROM ( SELECT ' ||
        -- attributes to include in output
        array_to_string(fname_attributes, ',') ||
        ') as t1))::text as prop ';
  ELSE
    sql := sql || ', ''{}''::text as prop';
  END IF;

  sql := sql || ' FROM ( ' || query || ' ) foo';

  --RAISE DEBUG 'Looping over sql: %', sql;

  FOR rec IN EXECUTE sql
  LOOP
    IF topology_id IS NULL THEN
      topology_id := topology_id(rec.obj);
    ELSIF topology_id != topology_id(rec.obj) THEN
      RAISE EXCEPTION 'TopoGeometry from different topologies mixed in query results';
    END IF;
    IF type(rec.obj) = 1 THEN
      -- Puntal type TopoJson not supported as of PostGIS-2.2, see
      -- https://trac.osgeo.org/postgis/ticket/3343
      sql := 'SELECT ST_AsGeoJSON(' || 'ST_transform($1::geometry,$2),$3' || ')';
      EXECUTE sql USING rec.obj,srid_out,maxdecimaldigits INTO  tmptext;
      -- Trim closing paren
      tmptext := substring(tmptext from 0 for length(tmptext));
      obj_json := tmptext;
    ELSE
      tmptext := topo_update.as_topo_json(rec.obj, 'topology_topojson_edgemap',bb);
      -- We may null back if no edges interscst only mb
      continue WHEN tmptext is NULL;
      -- Trim closing paren
      tmptext := substring(tmptext from 0 for length(tmptext));
      obj_json := tmptext;
    END IF;
    -- RAISE DEBUG 'Appending to objary: %', objary;
    objary := objary || array_to_string(ARRAY[
          obj_json::text,
          ',"properties":'::text,
          rec.prop::text,
          '}'
          ]::text[], '');
    --RAISE DEBUG 'New objary: %', objary;
  END LOOP;

  sql := 'SELECT name FROM topology.topology WHERE id = ' || topology_id;
  EXECUTE sql INTO STRICT toponame;

  outary := outary || ',"objects":{'::text
  				   || '"collection": { "type": "GeometryCollection", "geometries":['::text
                   || array_to_string(objary, ',');
--                   || '}'::text;

  -- Add arcs

  --RAISE DEBUG 'Adding arcs';
  
  -- relative coordinates
  sql := 'SELECT array_agg(full_arc ORDER BY arc_id)
  FROM (
    SELECT ''[''||array_to_string(array_agg(arc_node), '','') ||'']'' as full_arc,
    arc_id
    FROM (
      SELECT 
        CASE 
          WHEN org_index=1 THEN ''[''||ST_X(this_point)||'',''||ST_Y(this_point)||'']'' 
          ELSE ''[''||ST_X(this_point)-ST_X(lag_point)||'',''||ST_Y(this_point)-ST_Y(lag_point)||'']''
        END AS arc_node,
        arc_id
      FROM ( 
        SELECT 
          (dp).path[1] AS org_index,
          (dp).geom AS this_point,
          arc_id,
          lag((dp).geom) OVER () AS lag_point
        FROM ( 
          SELECT 
            st_dumppoints(geom) AS dp, 
            arc_id 
          FROM topology_topojson_edgemap
        ) AS r 
      ) AS r 
    ) AS r
    GROUP BY arc_id
  ) AS r';

  --EXECUTE sql USING simplify_patteren,srid_out,maxdecimaldigits INTO objary;
  --outary = outary || ']'::text || '}'::text || '}'::text;
  --outary = outary || ',"arcs": ['::text
  --                || array_to_string(objary, ',')
  --                || ']'::text;
  --outary = outary || '}'::text;

  -- Use absolute corrdinates
  sql := 'SELECT array_agg(ST_AsGeoJSON(' ||
      'ST_transform(topo_update.get_adjusted_edge(m.geom,$1),$2),$3' ||
      ')::json->>''coordinates'' ' ||
      'ORDER BY m.arc_id) FROM topology_topojson_edgemap m ';
  EXECUTE sql USING simplify_patteren,srid_out,maxdecimaldigits INTO objary;

 
  outary = outary || ']'::text || '}'::text || '}'::text;
  outary = outary || ',"arcs": ['::text
                  || array_to_string(objary, ',')
                  || ']'::text;
  outary = outary || '}'::text;

    

  --RAISE DEBUG '%', array_to_string(outary, '');
  
  DROP TABLE IF EXISTS topology_topojson_edgemap;
  
  json_result = array_to_string(outary, '')::varchar;
  RETURN json_result;

END;
$$ LANGUAGE 'plpgsql' VOLATILE;

--\timing
--select length(topo_update.query_to_topojson('select distinct a.* from topology.arstidsbeite_var_topojson_flate_v a',32633,0,0));


CREATE OR REPLACE FUNCTION topo_update.query_to_topojson(query text, srid_out int, maxdecimaldigits int, simplify_patteren int)
RETURNS text AS
$$
BEGIN
return topo_update.query_to_topojson(query, srid_out, maxdecimaldigits, simplify_patteren,null);
END;
$$ LANGUAGE 'plpgsql' VOLATILE;

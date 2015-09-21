
-- Return a topojson document with the contents of
-- topo_rein.arstidsbeite_var_flate table
-- topojson specs:
-- https://github.com/mbostock/topojson-specification/blob/master/README.md

-- env used to select bounding box area
-- srid_out is the srid data put are transformed to
-- maxdecimaldigits the number og digets used for update
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

CREATE OR REPLACE FUNCTION topo_rein.get_var_flate_topojson(srid_out int, maxdecimaldigits int)
RETURNS TEXT
AS $$
  SELECT topo_rein.get_var_flate_topojson(ST_MakeEnvelope(
            '-Infinity', '-Infinity', 'Infinity', 'Infinity'), srid_out, maxdecimaldigits)
$$ LANGUAGE 'sql' VOLATILE;

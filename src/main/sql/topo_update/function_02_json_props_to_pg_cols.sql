CREATE OR REPLACE FUNCTION topo_update.json_props_to_pg_cols(
  props JSON,
  col_map JSON,
  OUT colnames TEXT[],
	OUT colvals TEXT[]
)
AS $BODY$
DECLARE
	geom GEOMETRY;
	rec RECORD;
	val TEXT;
  json_prop_array TEXT[];
BEGIN

  colnames := array_agg(k) FROM (
      SELECT format('%I', json_object_keys( col_map )) k
    ) f;

  -- TODO: improve performance of this
  FOR rec IN SELECT json_object_keys( col_map ) k
  LOOP
    json_prop_array := array_agg(x) from json_array_elements_text( col_map -> rec.k ) x;
    --RAISE NOTICE 'prop_array: %', json_prop_array;
    val := props #>> json_prop_array;
    --RAISE NOTICE 'val: %', val;
    colvals := array_append(colvals, format('%L', val));
  END LOOP;

	--RETURN ( colnames, colvals );
END;
$BODY$ LANGUAGE 'plpgsql';



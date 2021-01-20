--
-- Take a JSON object (prop - properties) and a JSON mapping file
-- (col_map) and return 2 arrays:
--
--   - colnames will contain the name of PostgreSQL columns
--   - colvals will contain canonical text values for those columns
--
-- The mapping file is a JSON object having PostgreSQL column names
-- as keys (either in "simple" or "compo.site" form) and paths into
-- the payload properties object as JSON arrays
-- ( [ "path", "to", "value" ] )
--
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
  nam TEXT;
  val TEXT;
  json_val JSON;
  json_prop_array TEXT[];
BEGIN

  FOR rec IN SELECT json_object_keys( col_map ) k
  LOOP
  END LOOP;

  FOR rec IN SELECT json_object_keys( col_map ) k
  LOOP
    json_val := col_map -> rec.k;
    RAISE DEBUG 'json_val: %', json_val;

    -- Compute column name
    nam = rec.k;
    IF nam LIKE '%.%' THEN
      -- Protect from SQL injection
      -- TODO: improve the checking !
      nam := regexp_replace(regexp_replace(nam, '(["\\])', '\\\1', 'g'), '([^.]+)', '"\1"', 'g');
    ELSE
      nam := format('%I', nam);
    END IF;
    colnames := array_append(colnames, nam);

    -- Compute column value
    IF NOT json_typeof(json_val) = 'array' THEN
      RAISE EXCEPTION 'Invalid mapping: values should be arrays';
    END IF;
    -- TODO: improve performance of this
    json_prop_array := array_agg(x) from json_array_elements_text( json_val ) x;
    RAISE DEBUG 'prop_array: %', json_prop_array;
    val := format('%L', props #>> json_prop_array);
    colvals := array_append(colvals, val);
  END LOOP;

	--RETURN ( colnames, colvals );
END;
$BODY$ LANGUAGE 'plpgsql';



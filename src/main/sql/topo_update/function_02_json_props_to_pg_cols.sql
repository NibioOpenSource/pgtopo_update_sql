--
-- Take a JSON object (prop - properties) and a JSON mapping file
-- (col_map) and return 2 arrays:
--
--   - colnames will contain the name of PostgreSQL columns
--   - colvals will contain canonical values for those columns
--
-- The mapping file contains instruction about how to populate
-- each PostgreSQL column. Supported population strategies are:
-- 
--   - Simple type
--        value is extracted from JSON path
--        expressed as an array. Example:
--        [ "path", "to", "value" ]
--
--   - Composite type
--        value is extracted from an array of JSON paths
--        expressed as an array. Example:
--        [ [ "path", "to", "value1" ], [ "path", "to", "value2" ] ]
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
  rec2 RECORD;
  val TEXT;
  json_prop_array TEXT[];
  json_val JSON;
  comp_vals TEXT[];
BEGIN

  colnames := array_agg(k) FROM (
      SELECT format('%I', json_object_keys( col_map )) k
    ) f;

  -- TODO: improve performance of this
  FOR rec IN SELECT json_object_keys( col_map ) k
  LOOP
    json_val := col_map -> rec.k;
    RAISE DEBUG 'json_val: %', json_val;
    -- JSON val is expected to be an array
    IF NOT json_typeof(json_val) = 'array' THEN
      RAISE EXCEPTION 'Invalid mapping: values should be arrays';
    END IF;
    IF json_typeof(json_val -> 0) = 'array' THEN
      RAISE DEBUG '--- Mapping is for composite type';
      comp_vals := NULL;
      -- If first element of the JSON array is another array this
      -- is a sign that the target PostgreSQL column is of composite
      -- type and all other JSON elements will be paths of each field
      -- of the PostgreSQL column type
      FOR rec2 IN SELECT json_array_elements( json_val ) x
      LOOP
        RAISE DEBUG 'Composite type map element: %', rec2.x;
        -- TODO: improve performance of this
        json_prop_array := array_agg(x) from json_array_elements_text( rec2.x ) x;
        RAISE DEBUG 'prop_array: %', json_prop_array;
        val := props #>> json_prop_array;
        RAISE DEBUG 'Composite type value: %', val;
        comp_vals := array_append(comp_vals, format('%L', val));
      END LOOP;
      RAISE DEBUG 'Composite values: %', comp_vals;
      val := format('ROW(%s)', array_to_string(comp_vals, ','));
    ELSE
      -- TODO: improve performance of this
      json_prop_array := array_agg(x) from json_array_elements_text( json_val ) x;
      RAISE DEBUG 'prop_array: %', json_prop_array;
      val := format('%L', props #>> json_prop_array);
    END IF;
    colvals := array_append(colvals, val);
  END LOOP;

	--RETURN ( colnames, colvals );
END;
$BODY$ LANGUAGE 'plpgsql';



CREATE OR REPLACE FUNCTION topo_update.insert_feature(

  -- A GeoJSON Feature object
  -- See https://geojson.org/
  feature JSON,

  -- SRID of geometry, or NULL for leaving it as unknown
  srid INT,

  -- Target layer table (where to insert the new feature in)
  layerTable REGCLASS,

  -- Name of the TopoGeometry column in the target layer table
  layerGeomColumn NAME,

  -- JSON mapping of PG columns and values
  -- from JSON attributes and values
  -- See topo_update.json_props_to_pg_cols() function
  layerColMap JSON,

  -- Tolerance to use for insertion of topology primitives
  -- used to represent the feature geometry.
  -- May be NULL to use topology-default tolerance.
  tolerance FLOAT8
)
RETURNS VOID AS
$BODY$ -- {
DECLARE
  toponame TEXT;
  topo_srid INT;
  layer_id INT;
  sql TEXT;
  rec RECORD;
  geom GEOMETRY;
  colnames TEXT[];
  colvals TEXT[];
  val TEXT;
  json_prop_array TEXT[];
  props JSON;
BEGIN

  -- TODO: do this one in the calling function and receive this
  --       information pre-computed
  SELECT t.name, l.layer_id, t.srid
    FROM topology.layer l, topology.topology t
    WHERE format('%I.%I', l.schema_name, l.table_name)::regclass = layerTable
    AND l.feature_column = layerGeomColumn
    AND l.topology_id = t.id
    INTO toponame, layer_id, topo_srid;

  RAISE DEBUG 'toponame: %', toponame;
  RAISE DEBUG 'layer_id: %', layer_id;

  props := feature -> 'properties';


	SELECT c.colnames, c.colvals
	FROM topo_update.json_props_to_pg_cols(props, layerColMap) c
	INTO colnames, colvals;

  RAISE DEBUG 'COMPUTED: colnames: %', colnames;
  RAISE DEBUG 'COMPUTED: colvals: %', colvals;

  colnames := array_append(colnames, format('%I', layerGeomColumn));

  geom := ST_GeomFromGeoJSON(feature -> 'geometry');
  RAISE DEBUG 'GEOM: %', ST_AsEWKT(geom);

  -- TODO: use the deprecated "crs" member in GeoJSON, if found ?
  RAISE DEBUG 'SRID: %', srid;
  RAISE DEBUG 'TOPO_SRID: %', topo_srid;
  IF srid IS NOT NULL THEN
    geom := ST_SetSRID(geom, srid);
    IF topo_srid IS NOT NULL THEN
      geom := ST_Transform(geom, topo_srid);
    END IF;
    RAISE DEBUG 'REPROJECTED GEOM: %', ST_AsEWKT(geom);
  END IF;
  colvals := array_append(colvals, format('topology.toTopoGeom($1, %L, %L, %L)',
        toponame, layer_id, tolerance));
	

  sql := format('INSERT INTO %s (%s) VALUES(%s)',
    layerTable,
    array_to_string(colnames, ','),
    array_to_string(colvals, ','));

  RAISE DEBUG 'SQL: %', sql;

  EXECUTE sql USING geom;

END;
$BODY$ --}
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION topo_update.update_feature(

  -- A GeoJSON Feature object
  -- See https://geojson.org/
  feature JSON,

  -- SRID of geometry, or NULL for leaving it as unknown
  srid INT,

  -- Target layer table (where to insert the new feature in)
  layerTable REGCLASS,

  -- Name of the TopoGeometry column in the target layer table
  layerGeomColumn NAME,

  -- Name of the primary key column in the target layer table
  layerIdColumn NAME,

  -- Identifier value for the feature to be inserted
  id TEXT,

  -- JSON mapping of PG columns and values
  -- from JSON attributes and values
  -- See topo_update.json_props_to_pg_cols() function
  layerColMap JSON,

  -- Tolerance to use for insertion of topology primitives
  -- used to represent the feature geometry.
  -- May be NULL to use topology-default tolerance.
  tolerance FLOAT8
)
RETURNS VOID AS
$BODY$ -- {
DECLARE
  toponame TEXT;
  topo_srid INT;
  layer_id INT;

  geom GEOMETRY;

  colnames TEXT[];
  colvals TEXT[];

  col_updates TEXT[];
  col_upd TEXT;

  rec RECORD;
  sql TEXT;

  i INT;
BEGIN

  -- TODO: do this one in the calling function and receive this
  --       information pre-computed
  SELECT t.name, l.layer_id, t.srid
    FROM topology.layer l, topology.topology t
    WHERE format('%I.%I', l.schema_name, l.table_name)::regclass = layerTable
    AND l.feature_column = layerGeomColumn
    AND l.topology_id = t.id
    INTO toponame, layer_id, topo_srid;

  RAISE DEBUG 'toponame: %', toponame;
  RAISE DEBUG 'layer_id: %', layer_id;

	SELECT c.colnames, c.colvals
	FROM topo_update.json_props_to_pg_cols(feature -> 'properties', layerColMap) c
	INTO colnames, colvals;

  colnames := array_append(colnames, format('%I', layerGeomColumn));

  geom := ST_GeomFromGeoJSON(feature -> 'geometry');
  RAISE DEBUG 'GEOM: %', ST_AsEWKT(geom);

  -- TODO: use the deprecated "crs" member in GeoJSON, if found ?
  RAISE DEBUG 'SRID: %', srid;
  RAISE DEBUG 'TOPO_SRID: %', topo_srid;
  IF srid IS NOT NULL THEN
    geom := ST_SetSRID(geom, srid);
    IF topo_srid IS NOT NULL THEN
      geom := ST_Transform(geom, topo_srid);
    END IF;
    RAISE DEBUG 'REPROJECTED GEOM: %', ST_AsEWKT(geom);
  END IF;
  colvals := array_append(colvals, format('topology.toTopoGeom($1, topology.clearTopoGeom(%I), %L)',
        layerGeomColumn, tolerance));

  RAISE DEBUG 'COMPUTED: colnames: %', colnames;
  RAISE DEBUG 'COMPUTED: colvals: %', colvals;

	-- Naive approach: always UPDATE, no matter what

  FOR i IN 1 .. array_upper(colnames, 1)
  LOOP
    col_upd := format('%s = %s', colnames[i], colvals[i]);
    RAISE DEBUG 'col_upd: %', col_upd;
    col_updates := array_append(col_updates, col_upd);
  END LOOP;

  RAISE DEBUG 'col_updates: %', col_updates;

  sql := format('UPDATE %s t SET %s WHERE %I = %L',
    layerTable,
    array_to_string(col_updates, ', '),
    layerIdColumn,
    id
  );

  -- TODO: ADD more WHERE clauses to skip setting values which did not
  --       change ?
  RAISE DEBUG 'SQL: %', sql;

  EXECUTE sql USING geom;
END;
$BODY$ --}
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION topo_update.upsert_feature(

  -- A GeoJSON Feature object
  -- See https://geojson.org/
  feature JSON,

  -- SRID of geometry, or NULL for leaving it as unknown
  srid INT,

  -- Target layer table (where to insert the new feature in)
  layerTable REGCLASS,

  -- Name of the TopoGeometry column in the target layer table
  layerGeomColumn NAME,

  -- Name of the primary key column in the target layer table
  layerIdColumn NAME,

  -- JSON mapping of PG columns and values
  -- from JSON attributes and values
  -- See topo_update.json_props_to_pg_cols() function
  layerColMap JSON,

  -- Tolerance to use for insertion of topology primitives
  -- used to represent the feature geometry.
  -- May be NULL to use topology-default tolerance.
  tolerance FLOAT8
)
RETURNS VOID AS
$BODY$ -- {
DECLARE
  props JSON;
  id UUID;
  geom GEOMETRY;
  json_prop_array TEXT[];
  sql TEXT;
  rec RECORD;
  known bool;
BEGIN
  props := feature -> 'properties';

  json_prop_array := array_agg(x) from json_array_elements_text( layerColMap -> layerIdColumn ) x;

  id := props #>> json_prop_array;

  geom := ST_GeomFromGeoJSON(feature -> 'geometry');

  RAISE DEBUG 'Feature % is %', id, ST_Summary(geom);
  RAISE DEBUG 'Target table is %', layerTable;
  RAISE DEBUG 'Target table spatial column is %', layerGeomColumn;
  RAISE DEBUG 'Target table id column is %', layerIdColumn;
  RAISE DEBUG 'Tolerance is %', tolerance;

  sql := format('SELECT %1$I FROM %2$s WHERE %1$I = %3$L LIMIT 2',
                layerIdColumn, layerTable, id);
  RAISE DEBUG 'SQL: %', sql;
  known := false;
  FOR rec IN EXECUTE sql
  LOOP
    IF known THEN
      RAISE EXCEPTION 'Multiple features in table % have ID %', layerTable, id;
    ELSE
      known := true;
    END IF;
  END LOOP;

  IF known THEN
    RAISE NOTICE 'Feature exists, will UPDATE if needed';
    PERFORM topo_update.update_feature(
      feature,
      srid,
      layerTable,
      layerGeomColumn,
      layerIdColumn,
      id::text,
      layerColMap,
      tolerance
    );
  ELSE
    RAISE NOTICE 'Feature does not exist, will INSERT';
    PERFORM topo_update.insert_feature(
      feature,
      srid,
      layerTable,
      layerGeomColumn,
      layerColMap,
      tolerance
    );
  END IF;

END;
$BODY$ --}
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION topo_update.update_features(

  -- JSON is format specified by
  -- http://skjema.geonorge.no/SOSI/produktspesifikasjon/FKB-Ar5/4.6/FKB-Ar546.xsd
  featureset json,

  toponame text,
  arealLayerTable regclass,
  arealLayerColumn name,
  arealLayerIDColumn name,
  arealLayerColMap json, -- TODO: link to specification

  linealLayerTable regclass,
  linealLayerColumn name,
  linealLayerIDColumn name,
  linealLayerColMap json, -- TODO: link to specification

  tolerance float8

)
RETURNS VOID AS
$BODY$ -- {
DECLARE
  rec RECORD;
  feat JSON;
  feat_prop JSON;
  feat_type TEXT;
  toponame TEXT;
  crs TEXT;
  srid INT;

BEGIN

  crs := featureset -> 'crs' -> 'properties' ->> 'name';

  RAISE DEBUG 'crs: %', crs;

  SELECT s.srid
  FROM spatial_ref_sys s
  WHERE format('%s:%s', s.auth_name, s.auth_srid) = crs
  INTO srid;

  FOR rec IN SELECT json_array_elements(featureset -> 'features') feat
  LOOP

    feat := rec.feat;
    feat_prop := rec.feat -> 'properties';
    feat_type := feat_prop ->> 'featuretype';

    RAISE NOTICE 'Feature type: %', feat_type;

    IF feat_type = 'ArealressursGrense' THEN
      PERFORM topo_update.upsert_feature(
          feat,
          srid,
          linealLayerTable,
          linealLayerColumn,
          linealLayerIDColumn,
          linealLayerColMap,
          tolerance
      );
    ELSIF feat_type = 'ArealressursFlate' THEN
      PERFORM topo_update.upsert_feature(
          feat,
          srid,
          arealLayerTable,
          arealLayerColumn,
          arealLayerIDColumn,
          arealLayerColMap,
          tolerance
      );
    ELSE
      RAISE EXCEPTION 'Ignored feature with unexpected feature type %', feat_type;
    END IF;

  END LOOP;

  -- TODO: delete any features in the given area which were not
  --       returned
  -- See https://github.com/NibioOpenSource/pgtopo_update_sql/issues/16#issuecomment-760976913
  RAISE NOTICE 'No attempt is made to _delete_ features not found in the JSON';

END;
$BODY$ --}
LANGUAGE plpgsql;


COMMENT ON FUNCTION topo_update.update_features IS $$
feature - JSON payload with format specified by http://skjema.geonorge.no/SOSI/produktspesifikasjon/FKB-Ar5/4.6/FKB-Ar546.xsd
$$;

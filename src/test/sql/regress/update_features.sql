BEGIN;

set client_min_messages to WARNING;

CREATE SCHEMA IF NOT EXISTS topo_update;
\i :regdir/../../../main/sql/topo_update/function_02_json_props_to_pg_cols.sql
\i :regdir/../../../main/sql/topo_update/function_02_update_features.sql

-- TARGET TABLES:
-- topo_ar5.webclient_flate
-- topo_ar5.webclient_grense


--CREATE EXTENSION IF NOT EXISTS postgis_topology CASCADE;
--\i function_02_update_features_test.sql

-- (Test) schema setup

-- TOPOLOGY NAME: update_features_test_topo
-- AREAL LAYER:   topo_ar5.webclient_flate
-- LINEAL LAYER:  topo_ar5.webclient_grense

CREATE SCHEMA update_features_test;


SELECT NULL FROM CreateTopology('update_features_test_topo', 4326);

-- Check changes since last saving, save more
-- {
CREATE OR REPLACE FUNCTION update_features_test.check_changes(toponame text)
RETURNS TABLE (o text)
AS $BODY$
DECLARE
  rec RECORD;
  sql text;
BEGIN

  sql := format($$
      CREATE TABLE IF NOT EXISTS %1$I.limits AS 
      SELECT 'node'::text as what, COALESCE(max(node_id),0) max FROM %1$I.node
      UNION ALL
      SELECT 'edge'::text as what, COALESCE(max(edge_id),0) max FROM %1$I.edge
  $$, toponame);
  RAISE DEBUG '%', sql;
  EXECUTE sql;

  -- Check effect on nodes
  sql :=  format($$
    SELECT 'N|' ||
      COALESCE(n.containing_face::text,'') || '|' ||
      ST_AsText(n.geom, 2)::text as xx
    FROM %1$I.node n
    WHERE n.node_id > (
      SELECT max FROM %1$I.limits WHERE what = 'node'::text
    )
    ORDER BY n.geom
  $$, toponame);

  FOR rec IN EXECUTE sql
  LOOP
    o := rec.xx;
    --RAISE WARNING 'o: %', o;
    RETURN NEXT;
  END LOOP;

  -- Check effect on edges
  sql := format($$
    WITH node_limits AS (
      SELECT max
      FROM %1$I.limits
      WHERE what = 'node'::text
    ),
    edge_limits AS (
      SELECT max
      FROM %1$I.limits
      WHERE what = 'edge'::text
    )
    SELECT 'E|' || ST_AsText(e.geom, 2)::text AS xx
    FROM %1$I.edge e, node_limits nl, edge_limits el
    WHERE e.start_node > nl.max
      OR e.end_node > nl.max
      OR e.edge_id > el.max
    ORDER BY e.geom
  $$, toponame);

  FOR rec IN EXECUTE sql
  LOOP
    o := rec.xx;
    RETURN NEXT;
  END LOOP;

  sql := format($$
    UPDATE %1$I.limits SET max = COALESCE((
      SELECT max(n.node_id)
      FROM %1$I.node n
    ), 0)
    WHERE what = 'node';
  $$, toponame);
  RAISE DEBUG 'SQL: %', sql;
  EXECUTE sql;

  sql := format($$
    UPDATE %I.limits SET max = COALESCE((
      SELECT max(e.edge_id)
      FROM %1$I.edge e
    ), 0)
    WHERE what = 'edge';
  $$, toponame);
  RAISE DEBUG 'SQL: %', sql;
  EXECUTE sql;

END;
$BODY$ LANGUAGE 'plpgsql';
-- }

-- {
CREATE OR REPLACE FUNCTION update_features_test.check_layer_features(layer regclass, geomcol name)
RETURNS TABLE(o TEXT)
AS $BODY$
DECLARE
  rec RECORD;
  sql TEXT;
  attrs TEXT[];
BEGIN

  SELECT array_agg(quote_ident(attname) ORDER BY attnum)
  FROM pg_attribute
  WHERE attrelid = layer
  AND attnum > 0
  AND NOT attisdropped
  AND attname != geomcol
  INTO attrs;

  sql := format($$
    SELECT %s, ST_AsText(%I) FROM %s
  $$, array_to_string(attrs, ', '), geomcol, layer);
  RAISE DEBUG 'SQL: %', sql;
  FOR rec IN EXECUTE sql
  LOOP
    o := (rec)::text;
    RETURN NEXT;
  END LOOP;
END;
$BODY$ LANGUAGE 'plpgsql';

CREATE TABLE update_features_test.composite (
  a int,
  b text
);

-- This is like topo_ar5.webclient_flate but has an UUID field
CREATE TABLE update_features_test.areal (
    "id" UUID PRIMARY KEY,
    "arealtype" smallint,
    "treslag" smallint,
    "skogbonitet" smallint,
    "grunnforhold" smallint,
    "status" integer not null default 0,
    "composite" update_features_test.composite,
    "informasjon" text not null default '',
    "saksbehandler" varchar,
    "slette_status_kode" smallint not null default 0,
    "reinbeitebruker_id" varchar
);
SELECT NULL FROM AddTopoGeometryColumn('update_features_test_topo', 'update_features_test', 'areal', 'omrade', 'AREAL');

CREATE TABLE update_features_test.lineal (
    "id" uuid PRIMARY KEY,
    "avgrensingType" int,
    "datafangstdato" date,
    "oppdateringsdato" timestamp,
    "opphav" text,
    "verifiseringsdato" date
);
SELECT NULL FROM AddTopoGeometryColumn('update_features_test_topo', 'update_features_test', 'lineal', 'omrade', 'LINEAL');


-- Create mapping table
CREATE TABLE update_features_test.json_mapping(
	target_table regclass PRIMARY KEY,
	mapping_from_ngis json,
	mapping_from_webclient json
);
INSERT INTO update_features_test.json_mapping (target_table, mapping_from_ngis)
VALUES (
	'update_features_test.areal',
	'{
      "id": [ "identifikasjon", "lokalId" ],
      "arealtype": [ "arealtype" ],
      "treslag": [ "treslag" ],
      "skogbonitet": [ "skogbonitet" ],
      "grunnforhold": [ "grunnforhold" ],
      "composite.a": [ "kvalitet", "synbarhet" ],
      "composite.b": [ "identifikasjon", "navnerom" ]
		}'
),(
	'update_features_test.lineal',
	'{
      "id": [ "identifikasjon", "lokalId" ],
      "avgrensingType": [ "avgrensingType" ],
      "datafangstdato": [ "datafangstdato" ],
      "oppdateringsdato": [ "oppdateringsdato" ],
      "verifiseringsdato": [ "verifiseringsdato" ]
	}'
);

-- Create input json table
CREATE TABLE update_features_test.json_input(
	id serial PRIMARY KEY,
	label text UNIQUE,
	source text,
	payload json
);

INSERT INTO update_features_test.json_input(label, source, payload) VALUES (
	'test1',
	'ngis',
	'{
    "crs": {
        "properties": {
            "name": "EPSG:4326"
        },
        "type": "name"
    },
    "features": [
        {
            "geometry": {
                "coordinates": [
                    [ 0,0 ],
                    [ 10,0 ],
                    [ 10,10 ],
                    [ 0,0 ]
                ],
                "type": "LineString"
            },
            "properties": {
                "avgrensingType": "3000",
                "datafangstdato": "1965-07-22",
                "featuretype": "ArealressursGrense",
                "identifikasjon": {
                    "lokalId": "092688bb-c6ef-43c9-b6f7-41b2f065537c",
                    "navnerom": "AR5_test23",
                    "versjonId": "2019-11-11 11:57:47.371000"
                },
                "kvalitet": {
                    "m\u00e5lemetode": "53",
                    "n\u00f8yaktighet": 200,
                    "synbarhet": "0"
                },
                "oppdateringsdato": "2019-11-12T14:02:26",
                "opphav": "FKB-Vann",
                "registreringsversjon": {
                    "produkt": "FKB-AR5",
                    "versjon": "4.5 20140301"
                },
                "verifiseringsdato": "1965-07-22"
            },
            "type": "Feature"
        },
        {
            "geometry": {
                "coordinates": [
                  [
                    [ 0,0 ],
                    [ 10,0 ],
                    [ 10,10 ],
                    [ 0,0 ]
                  ]
                ],
                "type": "Polygon"
            },
            "geometry_properties": {
                "exterior": [
                    "-092688bb-c6ef-43c9-b6f7-41b2f065537c"
                ],
                "position": [ 0, 0 ]
            },
            "properties": {
                "arealtype": "81",
                "datafangstdato": "1965-07-22",
                "featuretype": "ArealressursFlate",
                "grunnforhold": "98",
                "identifikasjon": {
                    "lokalId": "0008e6eb-1332-4145-9943-591020916480",
                    "navnerom": "AR5_test23",
                    "versjonId": "2019-11-11 11:57:47.371000"
                },
                "kartstandard": "AR5",
                "kvalitet": {
                    "m\u00e5lemetode": "82",
                    "n\u00f8yaktighet": 1,
                    "synbarhet": "0"
                },
                "oppdateringsdato": "2019-11-12T14:02:26",
                "opphav": "FKB-Vann",
                "registreringsversjon": {
                    "produkt": "FKB-AR5",
                    "versjon": "4.5 20140301"
                },
                "skogbonitet": "98",
                "treslag": "98",
                "verifiseringsdato": "1965-07-22"
            },
            "type": "Feature"
        }
    ],
    "type": "FeatureCollection"
	}'
);


-- Start of operations
SELECT 'start', 'topo', * FROM update_features_test.check_changes('update_features_test_topo');
	
-- Call the first time, should INSERT
SELECT topo_update.update_features(
	(SELECT payload FROM update_features_test.json_input WHERE label = 'test1'),

	'update_features_test_topo',

	'update_features_test.areal',
	'omrade',
	'id',
	(SELECT mapping_from_ngis FROM update_features_test.json_mapping WHERE target_table = 'update_features_test.areal'::regclass),

	'update_features_test.lineal',
	'omrade',
	'id',
	(SELECT mapping_from_ngis FROM update_features_test.json_mapping WHERE target_table = 'update_features_test.lineal'::regclass),

  1e-10
);

SELECT 'update_features_1', 'topo', * FROM update_features_test.check_changes('update_features_test_topo');
SELECT 'update_features_1', 'areal', * FROM update_features_test.check_layer_features('update_features_test.areal'::regclass, 'omrade'::name);
SELECT 'update_features_1', 'lineal', * FROM update_features_test.check_layer_features('update_features_test.lineal'::regclass, 'omrade'::name);

-- Call the first time, should UPDATE
SELECT topo_update.update_features(
	(SELECT payload FROM update_features_test.json_input WHERE label = 'test1'),

	'update_features_test_topo',

	'update_features_test.areal',
	'omrade',
	'id',
	(SELECT mapping_from_ngis FROM update_features_test.json_mapping WHERE target_table = 'update_features_test.areal'::regclass),

	'update_features_test.lineal',
	'omrade',
	'id',
	(SELECT mapping_from_ngis FROM update_features_test.json_mapping WHERE target_table = 'update_features_test.lineal'::regclass),

  1e-10
);

SELECT 'update_features_2', 'topo', * FROM update_features_test.check_changes('update_features_test_topo');
SELECT 'update_features_2', 'areal', * FROM update_features_test.check_layer_features('update_features_test.areal'::regclass, 'omrade'::name);
SELECT 'update_features_2', 'lineal', * FROM update_features_test.check_layer_features('update_features_test.lineal'::regclass, 'omrade'::name);

ROLLBACK;

-- create schema for topo_ar5 data, tables, ....

-- NOTE: currently depends on topo_rein.sql

CREATE SCHEMA IF NOT EXISTS topo_ar5;
-- give puclic access
GRANT USAGE ON SCHEMA topo_ar5 TO public;

-- This function is used to create indexes
CREATE OR REPLACE FUNCTION topo_ar5.get_relation_id( geo TopoGeometry)
RETURNS integer AS $$DECLARE
    relation_id integer;
BEGIN
	relation_id := (geo).id;
  RETURN relation_id;
END;
$$ LANGUAGE plpgsql
IMMUTABLE;

COMMENT ON FUNCTION topo_ar5.get_relation_id(TopoGeometry) IS
  'Return the id used to find the row in the relation for polygons). Needed to create function based indexs.';
-- layuer id AR5_WEBCLIENT_F

-- select DropTopology('topo_ar5_sysdata_webclient');

SELECT CreateTopology('topo_ar5_sysdata_webclient', 4258, 0.0000000001);

DO
$do$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles  -- SELECT list can be empty for this
      WHERE  rolname = 'topo_ar5') THEN

      CREATE ROLE topo_ar5 LOGIN PASSWORD 'topo_ar5_tull';
   END IF;
END
$do$;


ALTER SCHEMA topo_ar5_sysdata_webclient OWNER TO topo_ar5;
-- give puclic access
GRANT USAGE ON SCHEMA topo_ar5_sysdata_webclient TO public;

-- If yes then we need the table webclient_grense
CREATE TABLE topo_ar5.webclient_grense(
  -- a internal id will that can be changed when ver needed
  id SERIAL PRIMARY KEY NOT NULL,

  -- ArealressursAvgrensingType
  -- ===========================
  -- ArealressursGrense = 4206
  -- IkkeKartlagtgrense = 9300
  -- Isbregrense = 3310
  -- Lagringsenhetgrense = 9111
  -- Samferdselsgrense = 7200
  -- Vanngrense = 3000
  avgrensing_type SMALLINT
    CHECK (avgrensing_type IN (4206, 9300, 3310, 9111, 7200, 3000)),

  -- contains felles egenskaper for sosi
  felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,

  -- The user logged in not used in kartverket
  saksbehandler VARCHAR
);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn(
  'topo_ar5_sysdata_webclient', 'topo_ar5', 'webclient_grense', 'grense', 'LINESTRING'
);


CREATE TABLE topo_ar5.webclient_flate(
  -- a internal id will that can be changed when ver needed
  id serial PRIMARY KEY not null,

  -- ArealressursArealtype :
  -- =======================
  -- Bebygd = 11
  -- Ferskvann = 81
  -- Fulldyrka jord = 21
  -- Hav = 82
  -- Ikke kartlagt = 99
  -- Innmarksbeite = 23
  -- Myr = 60
  -- Overflatedyrka jord = 22
  -- Samferdsel = 12
  -- Skog = 30
  -- Snøisbre = 70
  -- Åpen fastmark = 50
  arealtype SMALLINT CHECK (arealtype IN (11, 81, 21, 82, 99, 23, 60, 22, 12, 30, 70, 50)),

  -- ArealressursTreslag
  -- ===================
  -- Barskog = 31
  -- Lauvskog = 32
  -- Blandingsskog = 33
  -- Lauvblandingsskog = 35
  -- Ikke tresatt = 39
  -- Ikke relevant = 98
  -- Ikke registrert = 99
  treslag SMALLINT CHECK (treslag IN (31, 32, 33, 35, 39, 98, 99)),

  -- ArealressursSkogbonitet
  -- ========================
  -- Impediment = 11
  -- Lav=12
  -- Middels=13
  -- Høy=14
  -- Særshøy=15
  -- Produktiv = 17
  -- Høyogsærshøy=18
  -- Ikke relevant = 98
  -- Ikke registrert = 99
  skogbonitet SMALLINT CHECK (skogbonitet IN (11, 12, 13, 14, 15, 17, 18, 98, 99)),

  -- ArealressursGrunnforhold
  -- ========================
  -- Blokkmark=41
  -- Fjell i dagen = 42
  -- Grunnlendt = 43
  -- Jorddekt = 44
  -- Organiske jordlag = 45
  -- Ikke relevant = 98
  -- Ikke registrert = 99
  grunnforhold SMALLINT CHECK (grunnforhold IN (41, 42, 43, 44, 45, 46, 98, 99)),

  -- This is flag used indicate the status of this record.
  -- The rules for how to use this flag is not decided yet. May not be used in AR5
  -- Here is a list of the current states.
  -- 0: Ukjent (uknown)
  -- 1: Godkjent
  -- 10: Endret
  status INT NOT NULL DEFAULT 0,

  -- contains felles egenskaper for ar5
  felles_egenskaper topo_rein.sosi_felles_egenskaper,

  informasjon TEXT NOT NULL DEFAULT '',

  -- Reffers to the user that is logged in.
  saksbehandler VARCHAR,

  -- This is used by the user to indicate that he wants to delete object or not use it
  -- 0 menas that the object exits in normal way
  -- 1 menas that the users has selcted delete object
  slette_status_kode SMALLINT NOT NULL DEFAULT 0 CHECK (slette_status_kode IN (0, 1)),

  -- This is used to indicate the area
  -- TODO rename columns to common name
  reinbeitebruker_id VARCHAR
);

-- add a topogeometry column that is a ref to polygpn surface-- should this be called område/flate or geo ?
-- TODO rename to flate
SELECT topology.AddTopoGeometryColumn(
  'topo_ar5_sysdata_webclient', 'topo_ar5', 'webclient_flate', 'omrade', 'POLYGON'
);

COMMENT ON TABLE topo_ar5.webclient_flate IS
  'Contains attributtes for rein and ref. to topo surface data.
   For more info see http://www.statkart.no/Documents/Standard/SOSI kap3
   Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_ar5.webclient_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_ar5.webclient_flate.felles_egenskaper IS
  'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_ar5.webclient_flate.geo IS 'This holds the ref to topo_ar5_sysdata_webclient.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_ar5_webclient_flate_geo_relation_id_idx
  ON topo_ar5.webclient_flate(topo_ar5.get_relation_id(omrade));

-- COMMENT ON INDEX topo_ar5.topo_ar5_webclient_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';

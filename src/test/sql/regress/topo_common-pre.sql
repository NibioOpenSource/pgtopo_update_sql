select CreateTopology('topo_rein_sysdata_ran',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_ran.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_ran.face_face_id_seq', 3, false);

-- give puclic access

GRANT USAGE ON SCHEMA topo_rein_sysdata_ran TO public;

-- create schema for topo_rein data, tables, .... 
CREATE SCHEMA topo_rein;
-- give puclic access
GRANT USAGE ON SCHEMA topo_rein TO public;

select CreateTopology('topo_rein_sysdata',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata.face_face_id_seq', 3, false);

-- give puclic access

GRANT USAGE ON SCHEMA topo_rein_sysdata TO public;


-- This function is used to create indexes
CREATE OR REPLACE FUNCTION topo_rein.get_relation_id( geo TopoGeometry) RETURNS integer AS $$DECLARE
    relation_id integer;
BEGIN
	relation_id := (geo).id;
   	RETURN relation_id;
END;
$$ LANGUAGE plpgsql
IMMUTABLE;

COMMENT ON FUNCTION topo_rein.get_relation_id(TopoGeometry) IS 'Return the id used to find the row in the relation for polygons). Needed to create function based indexs.';



-- A composite type to hold sosi kopi_data
CREATE TYPE topo_rein.sosi_kopidata 
AS (
	omradeid smallint,
	originaldatavert  VARCHAR(50),
	kopidato DATE
);

-- A composite type to hold sosi registreringsversjon
CREATE TYPE topo_rein.sosi_registreringsversjon 
AS (
	produkt varchar,
	versjon varchar
);


-- A composite type to hold sosi kvalitet
-- beskrivelse av kvaliteten på stedfestingen
CREATE TYPE topo_rein.sosi_kvalitet 
AS (
	-- metode for måling i grunnriss (x,y), og høyde (z) når metoden er den samme som ved måling i grunnriss
	-- TODO Hentes fra kode tabell eller bruke en constraint ???
	maalemetode smallint,
	
	-- punktstandardavviket i grunnriss for punkter samt tverravvik for linjer
	-- Merknad: Oppgitt i cm
	noyaktighet integer,

	-- hvor godt den kartlagte detalj var synbar ved kartleggingen
	-- TODO Hentes fra kode tabell eller bruke en constraint ???
	synbarhet smallint
);

-- A composite type to hold sosi sosi felles egenskaper
CREATE TYPE topo_rein.sosi_felles_egenskaper
AS (
	-- identifikasjondato når data ble registrert/observert/målt første gang, som utgangspunkt for første digitalisering
	-- Merknad:førsteDatafangstdato brukes hvis det er av interesse å forvalte informasjon om når en ble klar over objektet. Dette kan for eksempel gjelde datoen for første flybilde som var utgangspunkt for registrering i en database.
	-- lage regler for hvordan den skal brukes, kan i mange tilfeller arves
	-- henger sammen med UUID, ny UUID ny datofangst dato
	forstedatafangstdato DATE,

	-- Unik identifikasjon av et objekt, ivaretatt av den ansvarlige produsent/forvalter, som kan benyttes av eksterne applikasjoner som referanse til objektet. 
	-- NOTE1 Denne eksterne objektidentifikasjonen må ikke forveksles med en tematisk objektidentifikasjon, slik som f.eks bygningsnummer. 
	-- NOTE 2 Denne unike identifikatoren vil ikke endres i løpet av objektets levetid. 
	-- TODO Test if we can use this as a unique id.
	identifikasjon varchar,
	-- bygd opp navnerom/lokalid/versjon
	-- navnerom: NO_LDIR_REINDRIFT_VAARBEITE
	-- versjon: 0
	-- lokalid:  rowid	
	-- eks identifikasjon = "NO_LDIR_REINDRIFT_VAARBEITE 0 199999999"


	-- beskrivelse av kvaliteten på stedfestingen
	-- Merknad: Denne er identisk med ..KVALITET i tidligere versjoner av SOSI.
	kvalitet topo_rein.sosi_kvalitet,

	
	-- dato for siste endring på objektetdataene 
	-- Merknad: Oppdateringsdato kan være forskjellig fra Datafangsdato ved at data som er registrert kan bufres en kortere eller lengre periode før disse legges inn i datasystemet (databasen).
	-- Definition: Date and time at which this version of the spatial object was inserted or changed in the spatial data set. 
	oppdateringsdato DATE, 

	-- referanse til opphavsmaterialet, kildematerialet, organisasjons/publiseringskilde
	-- Merknad: Kan også beskrive navn på person og årsak til oppdatering
	opphav VARCHAR(255),

	-- dato når dataene er fastslått å være i samsvar med virkeligheten 
	-- Merknad: Verifiseringsdato er identisk med ..DATO i tidligere versjoner av SOSI	verifiseringsdato DATE
	-- lage regler for hvordan den skal brukes
	-- flybilde fra 2008 vil gi data 2008, må være input fra brukeren
	verifiseringsdato DATE,

	-- Hva gjør vi med disse verdiene som vi har brukt tidligere brukte  i AR5 ?
	-- Er vi sikre på at vi ikke trenger de

	-- datafangstdato DATE, 
	-- Vet ikke om vi skal ha med den, må tenke litt
	-- Skal ikke være med hvis Knut og Ingvild ikke sier noe annet
	
	-- vil bli et produktspek til ???
	-- taes med ikke til slutt brukere
	informasjon  VARCHAR(255) ARRAY, 
	
	-- trengs ikke i følge Knut og Ingvild
	-- kopidata topo_rein.sosi_kopidata, 
	
	-- trengs ikke i følge Knut og Ingvild
	-- prosess_historie VARCHAR(255) ARRAY,
	
	-- kan være forskjellige verdier ut fra når data ble lagt f.eks null verdier for nye attributter eldre enn 4.0
	-- bør være med
	registreringsversjon topo_rein.sosi_registreringsversjon

	
);


-- this is type used extrac data from json
CREATE TYPE topo_rein.simple_sosi_felles_egenskaper AS (
	"fellesegenskaper.forstedatafangstdato" date , 
	"fellesegenskaper.verifiseringsdato" date ,
	"fellesegenskaper.oppdateringsdato" date ,
	"fellesegenskaper.opphav" varchar, 
	"fellesegenskaper.kvalitet.maalemetode" int ,
	"fellesegenskaper.kvalitet.noyaktighet" int ,
	"fellesegenskaper.kvalitet.synbarhet" smallint
	
);



-- A composite type to hold key value that will recoreded before a update
-- and compared after the update, used be sure no changes hapends out side 
-- the area that should be updated 
-- DROP TYPE topo_rein.closeto_values_type cascade;

CREATE TYPE topo_rein.closeto_values_type
AS (
	-- line length that intersects reinflate
	closeto_length_reinflate_inter numeric,
	
	-- line count that intersects the edge
	closeto_count_edge_inter int,
	
	-- line count that intersetcs reinlinje 
	closeto_count_reinlinje_inter int,
	
	-- used to check that attribute value close has not changed a close to
	artype_and_length_as_text text,
	
	-- used to check that the area is ok after update 
	-- as we use today we do not remove any data we just add new polygins or change exiting 
	-- the layer should always be covered
	envelope_area_inter  numeric

);


-- TODO add more comments
COMMENT ON COLUMN topo_rein.sosi_felles_egenskaper.verifiseringsdato IS 'Sosi common meta attribute';
COMMENT ON COLUMN topo_rein.sosi_felles_egenskaper.opphav IS 'Sosi common meta attribute';
COMMENT ON COLUMN topo_rein.sosi_felles_egenskaper.informasjon IS 'Sosi common meta attribute';

-- ReinbeitebrukerID
-- angir hvilket reinbeitedistrikt som bruker beiteområdet,....
-- Definition indicates which reindeer pasture district uses the pasture area,...

create table if not exists topo_rein.rein_kode_reinbeitedist(
  id integer unique not null,
  distkode varchar(3) unique not null, -- added unique
  definisjon varchar(10),
  distriktnavn varchar);

   
  
-- ReindriftSesongområde  
-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc
-- Definition identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
create table if not exists topo_rein.rein_kode_sesomr(
  kode integer unique not null,
  kodenavn varchar,
  definisjon varchar
 );
 



  
 
create table if not exists topo_rein.rein_kode_reinbeiteomr(
  omrkode varchar(1) unique not null,
  beskrivelse varchar
);




create table if not exists topo_rein.rein_kode_gjerderanlegg(
  kode integer not null,
  kodenavn varchar,
  definisjon varchar
  );




-- this is a table that is used to keep track of who logged in and what roles they have.
-- The table is used by row level policy rules

CREATE TABLE topo_rein.rls_role_mapping(

-- a internal id will that can be changed when ver needed
id serial PRIMARY KEY NOT NULL,

-- when it was updated
logged_in_time date default now(),

-- the logged in user id from the client
user_logged_in varchar  NOT NULL,

-- the session id from the client
session_id varchar NOT NULL,

-- the user can edit any row i any table
-- this overides all other settings indepentely of all other rows 
-- found this session
edit_all boolean NOT NULL DEFAULT false,

-- * for all tables, means that if it will check against all table with this column name 
table_name varchar NOT NULL,

-- which columns we shoul chechk against
column_name varchar NOT NULL,

-- columns values that should be editable for this user / session
column_value varchar NOT NULL

-- did not get this to work the list of valid reinbeitebruker_id for this user
-- reinbeitebruker_list text[] 
-- reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')), 

);


--CREATE INDEX rls_role_mapping_session_id_idx ON topo_rein.rls_role_mapping(session_id);	

--CREATE INDEX rls_role_mapping_table_name_idx ON topo_rein.rls_role_mapping(table_name);	

--CREATE INDEX rls_role_mapping_column_name_idx ON topo_rein.rls_role_mapping(column_name);	

--CREATE INDEX rls_role_mapping_column_value_name_idx ON topo_rein.rls_role_mapping(column_value);	

CREATE UNIQUE INDEX rls_role_mapping_un_idx1 ON topo_rein.rls_role_mapping(session_id,table_name,column_name,column_value);	


--GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON topo_rein.rls_role_mapping TO topo_rein_update_role;

--GRANT SELECT, USAGE, UPDATE ON topo_rein.rls_role_mapping_id_seq TO topo_rein_update_role;

select CreateTopology('topo_rein_sysdata_rvr',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rvr.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rvr.face_face_id_seq', 3, false);

-- give puclic access

GRANT USAGE ON SCHEMA topo_rein_sysdata_rvr TO public;

-- Should we have one table for all årstidsbeite thems or 5 different tables as today ?
-- We go for the solution with 5 tables now because then it's probably more easy to handle non overlap rules
-- and logically two and two thems form one single map. The only differemse between the 5 tables will be the table name.
-- But if Sandro Santoli says this is easy to use a view to handle toplogy we may need to discuss this again
-- We could also use inheritance but then we aslo get mix rows from different maps.


-- clear out old data added to make testing more easy
-- drop table topo_rein.arstidsbeite_var_flate;
-- drop table topo_rein.arstidsbeite_var_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'arstidsbeite_var_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'arstidsbeite_var_grense', 'grense');


-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ? 
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data, 
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table arstidsbeite_var_grense
CREATE TABLE topo_rein.arstidsbeite_var_grense(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,

-- Reffers to the user that is logged in.
saksbehandler varchar


);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rvr', 'topo_rein', 'arstidsbeite_var_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.arstidsbeite_var_flate ?


CREATE TABLE topo_rein.arstidsbeite_var_flate(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
id serial PRIMARY KEY not null,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi
-- removed because this is equal for all rows the value are 'Årstidsbeite'.

-- column område 
-- is added later and may renamed to geo
-- Should we call this geo, omrade or område ?
-- use omrade 

-- column posisjon point from sosi
-- removed because we don't need it, we can generate it if we need id.
-- all rows here should be of type surface and no rows with point only

-- angir hvilket reinbeitedistrikt som bruker beiteområdet 
-- Definition -- indicates which reindeer pasture district uses the pasture area
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')), 


-- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
-- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
-- we use a simple comma separated text for now
alle_reinbeitebr_id varchar not null default '',

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent 
-- 10: Endret
status int not null default 0,


-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc 
-- Definition -- identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
-- Reduces this to only vårbeite I og vårbeite II, because this types form one single map
-- reindrift_sesongomrade_id int CHECK ( reindrift_sesongomrade_id > 0 AND reindrift_sesongomrade_id < 3) 
-- CONSTRAINT fk_arstidsbeite_var_flate_reindrift_sesongomrade_id REFERENCES topo_rein.rein_kode_sesomr(kode) ,

-- it's better to use a code here, because that is what is descrbeied in the spec
reindrift_sesongomrade_kode int CHECK ( reindrift_sesongomrade_kode > 0 AND reindrift_sesongomrade_kode < 3), 

-- contains felles egenskaper for rein
-- should this be moved to the border, because the is just a result drawing border lines ??
-- what about the value the for indentfikajons ?
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- Reffers to the user that is logged in.
saksbehandler varchar,


-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)), 

-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258) 



);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rvr', 'topo_rein', 'arstidsbeite_var_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t 
	--WHERE t.name = 'topo_rein_sysdata_rvr' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'arstidsbeite_var_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;




COMMENT ON TABLE topo_rein.arstidsbeite_var_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.arstidsbeite_var_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.arstidsbeite_var_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.arstidsbeite_var_flate.geo IS 'This holds the ref to topo_rein_sysdata_rvr.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_arstidsbeite_var_flate_geo_relation_id_idx ON topo_rein.arstidsbeite_var_flate(topo_rein.get_relation_id(omrade));	

COMMENT ON INDEX topo_rein.topo_rein_arstidsbeite_var_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';


-- create index on topo_rein_sysdata_rvr.edge
CREATE INDEX topo_rein_sysdata_rvr_edge_simple_geo_idx ON topo_rein.arstidsbeite_var_flate USING GIST (simple_geo); 

--COMMENT ON INDEX topo_rein.topo_rein_sysdata_rvr_edge_simple_geo_idx IS 'A index created to avoid building topo when the data is used for wms like mapserver which do no use the topo geometry';

select CreateTopology('topo_rein_sysdata_rso',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rso.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rso.face_face_id_seq', 3, false);

-- give puclic access

GRANT USAGE ON SCHEMA topo_rein_sysdata_rso TO public;

-- Should we have one table for all årstidsbeite thems or 5 different tables as today ?
-- We go for the solution with 5 tables now because then it's probably more easy to handle non overlap rules
-- and logically two and two thems form one single map. The only differemse between the 5 tables will be the table name.
-- But if Sandro Santoli says this is easy to use a view to handle toplogy we may need to discuss this again
-- We could also use inheritance but then we aslo get mix rows from different maps.


-- clear out old data added to make testing more easy
-- drop table topo_rein.arstidsbeite_sommer_flate;
-- drop table topo_rein.arstidsbeite_sommer_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'arstidsbeite_sommer_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'arstidsbeite_sommer_grense', 'grense');


-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ? 
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data, 
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table arstidsbeite_sommer_grense
CREATE TABLE topo_rein.arstidsbeite_sommer_grense(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,


-- Reffers to the user that is logged in.
saksbehandler varchar



);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rso', 'topo_rein', 'arstidsbeite_sommer_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.arstidsbeite_sommer_flate ?


CREATE TABLE topo_rein.arstidsbeite_sommer_flate(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
id serial PRIMARY KEY not null,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi
-- removed because this is equal for all rows the value are 'Årstidsbeite'.

-- column område 
-- is added later and may renamed to geo
-- Should we call this geo, omrade or område ?
-- use omrade 

-- column posisjon point from sosi
-- removed because we don't need it, we can generate it if we need id.
-- all rows here should be of type surface and no rows with point only

-- angir hvilket reinbeitedistrikt som bruker beiteområdet 
-- Definition -- indicates which reindeer pasture district uses the pasture area
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')), 


-- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
-- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
-- we use a simple comma separated text for now
alle_reinbeitebr_id varchar not null default '',

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent 
-- 10: Endret
status int not null default 0,

-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc 
-- Definition -- identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
-- Reduces this to only vårbeite I og vårbeite II, because this types form one single map
-- reindrift_sesongomrade_id int CHECK ( reindrift_sesongomrade_id > 0 AND reindrift_sesongomrade_id < 3) 
-- CONSTRAINT fk_arstidsbeite_sommer_flate_reindrift_sesongomrade_id REFERENCES topo_rein.rein_kode_sesomr(kode) ,

-- it's better to use a code here, because that is what is descrbeied in the spec
reindrift_sesongomrade_kode int CHECK ( reindrift_sesongomrade_kode > 2 AND reindrift_sesongomrade_kode < 5), 

-- contains felles egenskaper for rein
-- should this be moved to the border, because the is just a result drawing border lines ??
-- what about the value the for indentfikajons ?
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- Reffers to the user that is logged in.
saksbehandler varchar,

-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)), 

-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258) 



);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rso', 'topo_rein', 'arstidsbeite_sommer_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t 
	--WHERE t.name = 'topo_rein_sysdata_rso' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'arstidsbeite_sommer_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;




COMMENT ON TABLE topo_rein.arstidsbeite_sommer_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.arstidsbeite_sommer_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.arstidsbeite_sommer_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.arstidsbeite_sommer_flate.geo IS 'This holds the ref to topo_rein_sysdata_rso.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_arstidsbeite_sommer_flate_geo_relation_id_idx ON topo_rein.arstidsbeite_sommer_flate(topo_rein.get_relation_id(omrade));	

COMMENT ON INDEX topo_rein.topo_rein_arstidsbeite_sommer_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';

select CreateTopology('topo_rein_sysdata_rhs',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rhs.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rhs.face_face_id_seq', 3, false);

-- give puclic access

GRANT USAGE ON SCHEMA topo_rein_sysdata_rhs TO public;

-- Should we have one table for all årstidsbeite thems or 5 different tables as today ?
-- We go for the solution with 5 tables now because then it's probably more easy to handle non overlap rules
-- and logically two and two thems form one single map. The only differemse between the 5 tables will be the table name.
-- But if Sandro Santoli says this is easy to use a view to handle toplogy we may need to discuss this again
-- We could also use inheritance but then we aslo get mix rows from different maps.


-- clear out old data added to make testing more easy
-- drop table topo_rein.arstidsbeite_host_flate;
-- drop table topo_rein.arstidsbeite_host_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'arstidsbeite_host_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'arstidsbeite_host_grense', 'grense');


-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ? 
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data, 
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table arstidsbeite_host_grense
CREATE TABLE topo_rein.arstidsbeite_host_grense(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,


-- Reffers to the user that is logged in.
saksbehandler varchar
);


-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rhs', 'topo_rein', 'arstidsbeite_host_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.arstidsbeite_host_flate ?


CREATE TABLE topo_rein.arstidsbeite_host_flate(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
id serial PRIMARY KEY not null,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi
-- removed because this is equal for all rows the value are 'Årstidsbeite'.

-- column område 
-- is added later and may renamed to geo
-- Should we call this geo, omrade or område ?
-- use omrade 

-- column posisjon point from sosi
-- removed because we don't need it, we can generate it if we need id.
-- all rows here should be of type surface and no rows with point only

-- angir hvilket reinbeitedistrikt som bruker beiteområdet 
-- Definition -- indicates which reindeer pasture district uses the pasture area
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')), 


-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc 
-- Definition -- identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
-- Reduces this to only vårbeite I og vårbeite II, because this types form one single map
-- reindrift_sesongomrade_id int CHECK ( reindrift_sesongomrade_id > 0 AND reindrift_sesongomrade_id < 3) 
-- CONSTRAINT fk_arstidsbeite_host_flate_reindrift_sesongomrade_id REFERENCES topo_rein.rein_kode_sesomr(kode) ,

-- it's better to use a code here, because that is what is descrbeied in the spec
reindrift_sesongomrade_kode int CHECK ( reindrift_sesongomrade_kode > 4 AND reindrift_sesongomrade_kode < 7), 

-- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
-- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
-- we use a simple comma separated text for now
alle_reinbeitebr_id varchar not null default '',

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent 
-- 10: Endret
status int not null default 0,

-- contains felles egenskaper for rein
-- should this be moved to the border, because the is just a result drawing border lines ??
-- what about the value the for indentfikajons ?
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- Reffers to the user that is logged in.
saksbehandler varchar,

-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)), 


-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258) 



);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rhs', 'topo_rein', 'arstidsbeite_host_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t 
	--WHERE t.name = 'topo_rein_sysdata_rhs' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'arstidsbeite_host_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;




COMMENT ON TABLE topo_rein.arstidsbeite_host_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.arstidsbeite_host_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.arstidsbeite_host_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.arstidsbeite_host_flate.geo IS 'This holds the ref to topo_rein_sysdata_rhs.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_arstidsbeite_host_flate_geo_relation_id_idx ON topo_rein.arstidsbeite_host_flate(topo_rein.get_relation_id(omrade));	

COMMENT ON INDEX topo_rein.topo_rein_arstidsbeite_host_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';


select CreateTopology('topo_rein_sysdata_rhv',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rhv.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rhv.face_face_id_seq', 3, false);

-- give puclic access

GRANT USAGE ON SCHEMA topo_rein_sysdata_rhv TO public;

-- Should we have one table for all årstidsbeite thems or 5 different tables as today ?
-- We go for the solution with 5 tables now because then it's probably more easy to handle non overlap rules
-- and logically two and two thems form one single map. The only differemse between the 5 tables will be the table name.
-- But if Sandro Santoli says this is easy to use a view to handle toplogy we may need to discuss this again
-- We could also use inheritance but then we aslo get mix rows from different maps.


-- clear out old data added to make testing more easy
-- drop table topo_rein.arstidsbeite_hostvinter_flate;
-- drop table topo_rein.arstidsbeite_hostvinter_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'arstidsbeite_hostvinter_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'arstidsbeite_hostvinter_grense', 'grense');


-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ? 
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data, 
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table arstidsbeite_hostvinter_grense
CREATE TABLE topo_rein.arstidsbeite_hostvinter_grense(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,


-- Reffers to the user that is logged in.
saksbehandler varchar



);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rhv', 'topo_rein', 'arstidsbeite_hostvinter_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.arstidsbeite_hostvinter_flate ?


CREATE TABLE topo_rein.arstidsbeite_hostvinter_flate(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
id serial PRIMARY KEY not null,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi
-- removed because this is equal for all rows the value are 'Årstidsbeite'.

-- column område 
-- is added later and may renamed to geo
-- Should we call this geo, omrade or område ?
-- use omrade 

-- column posisjon point from sosi
-- removed because we don't need it, we can generate it if we need id.
-- all rows here should be of type surface and no rows with point only

-- angir hvilket reinbeitedistrikt som bruker beiteområdet 
-- Definition -- indicates which reindeer pasture district uses the pasture area
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')), 


-- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
-- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
-- we use a simple comma separated text for now
alle_reinbeitebr_id varchar not null default '',

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent 
-- 10: Endret
status int not null default 0,

-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc 
-- Definition -- identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
-- Reduces this to only vårbeite I og vårbeite II, because this types form one single map
-- reindrift_sesongomrade_id int CHECK ( reindrift_sesongomrade_id > 0 AND reindrift_sesongomrade_id < 3) 
-- CONSTRAINT fk_arstidsbeite_hostvinter_flate_reindrift_sesongomrade_id REFERENCES topo_rein.rein_kode_sesomr(kode) ,

-- it's better to use a code here, because that is what is descrbeied in the spec
reindrift_sesongomrade_kode int CHECK ( reindrift_sesongomrade_kode > 6 AND reindrift_sesongomrade_kode < 9), 

-- contains felles egenskaper for rein
-- should this be moved to the border, because the is just a result drawing border lines ??
-- what about the value the for indentfikajons ?
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,


-- Reffers to the user that is logged in.
saksbehandler varchar,

-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)), 

-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258) 



);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rhv', 'topo_rein', 'arstidsbeite_hostvinter_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t 
	--WHERE t.name = 'topo_rein_sysdata_rhv' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'arstidsbeite_hostvinter_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;




COMMENT ON TABLE topo_rein.arstidsbeite_hostvinter_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.arstidsbeite_hostvinter_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.arstidsbeite_hostvinter_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.arstidsbeite_hostvinter_flate.geo IS 'This holds the ref to topo_rein_sysdata_rhv.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_arstidsbeite_hostvinter_flate_geo_relation_id_idx ON topo_rein.arstidsbeite_hostvinter_flate(topo_rein.get_relation_id(omrade));	

COMMENT ON INDEX topo_rein.topo_rein_arstidsbeite_hostvinter_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';

select CreateTopology('topo_rein_sysdata_rvi',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rvi.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rvi.face_face_id_seq', 3, false);

-- give puclic access

GRANT USAGE ON SCHEMA topo_rein_sysdata_rvi TO public;

-- Should we have one table for all årstidsbeite thems or 5 different tables as today ?
-- We go for the solution with 5 tables now because then it's probably more easy to handle non overlap rules
-- and logically two and two thems form one single map. The only differemse between the 5 tables will be the table name.
-- But if Sandro Santoli says this is easy to use a view to handle toplogy we may need to discuss this again
-- We could also use inheritance but then we aslo get mix rows from different maps.


-- clear out old data added to make testing more easy
-- drop table topo_rein.arstidsbeite_vinter_flate;
-- drop table topo_rein.arstidsbeite_vinter_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'arstidsbeite_vinter_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'arstidsbeite_vinter_grense', 'grense');


-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ? 
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data, 
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table arstidsbeite_vinter_grense
CREATE TABLE topo_rein.arstidsbeite_vinter_grense(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,

-- Reffers to the user that is logged in.
saksbehandler varchar

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rvi', 'topo_rein', 'arstidsbeite_vinter_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.arstidsbeite_vinter_flate ?


CREATE TABLE topo_rein.arstidsbeite_vinter_flate(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
id serial PRIMARY KEY not null,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi
-- removed because this is equal for all rows the value are 'Årstidsbeite'.

-- column område 
-- is added later and may renamed to geo
-- Should we call this geo, omrade or område ?
-- use omrade 

-- column posisjon point from sosi
-- removed because we don't need it, we can generate it if we need id.
-- all rows here should be of type surface and no rows with point only

-- angir hvilket reinbeitedistrikt som bruker beiteområdet 
-- Definition -- indicates which reindeer pasture district uses the pasture area
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')), 


-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc 
-- Definition -- identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
-- Reduces this to only vårbeite I og vårbeite II, because this types form one single map
-- reindrift_sesongomrade_id int CHECK ( reindrift_sesongomrade_id > 0 AND reindrift_sesongomrade_id < 3) 
-- CONSTRAINT fk_arstidsbeite_vinter_flate_reindrift_sesongomrade_id REFERENCES topo_rein.rein_kode_sesomr(kode) ,

-- it's better to use a code here, because that is what is descrbeied in the spec
reindrift_sesongomrade_kode int CHECK ( reindrift_sesongomrade_kode > 8 AND reindrift_sesongomrade_kode < 11), 

-- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
-- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
-- we use a simple comma separated text for now
alle_reinbeitebr_id varchar not null default '',

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent 
-- 10: Endret
status int not null default 0,

-- contains felles egenskaper for rein
-- should this be moved to the border, because the is just a result drawing border lines ??
-- what about the value the for indentfikajons ?
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- Reffers to the user that is logged in.
saksbehandler varchar,


-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)), 

-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258) 



);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rvi', 'topo_rein', 'arstidsbeite_vinter_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t 
	--WHERE t.name = 'topo_rein_sysdata_rvi' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'arstidsbeite_vinter_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;




COMMENT ON TABLE topo_rein.arstidsbeite_vinter_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.arstidsbeite_vinter_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.arstidsbeite_vinter_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.arstidsbeite_vinter_flate.geo IS 'This holds the ref to topo_rein_sysdata_rvi.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_arstidsbeite_vinter_flate_geo_relation_id_idx ON topo_rein.arstidsbeite_vinter_flate(topo_rein.get_relation_id(omrade));	

COMMENT ON INDEX topo_rein.topo_rein_arstidsbeite_vinter_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';


-- Should we have one table for all årstidsbeite thems or 5 different tables as today ?
-- We go for the solution with 5 tables now because then it's probably more easy to handle non overlap rules
-- and logically two and two thems form one single map. The only differemse between the 5 tables will be the table name.
-- But if Sandro Santoli says this is easy to use a view to handle toplogy we may need to discuss this again
-- We could also use inheritance but then we aslo get mix rows from different maps.


-- clear out old data added to make testing more easy
-- drop table topo_rein.arstidsbeite_var_flate;
-- drop table topo_rein.reindrift_anlegg_linje;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'arstidsbeite_var_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'reindrift_anlegg_linje', 'grense');


-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ?
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data,
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table reindrift_anlegg_linje
CREATE TABLE topo_rein.reindrift_anlegg_linje(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- Reffers to the user that is logged in.
saksbehandler varchar,

-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)),

-- angir hvilket reinbeitedistrikt som bruker beiteområdet
-- Definition -- indicates which reindeer pasture district uses the pasture area
-- TODO add not null
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN
    ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC',
    'ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG',
    'XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT',
    'YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS',
    'XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK',
    'WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA',
    'YQB','YQC','ZZ','RR','ZQA')),
reinbeitebruker_id2 varchar(3) CHECK (reinbeitebruker_id2 IN
    ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC',
    'ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG',
    'XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT',
    'YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS',
    'XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK',
    'WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA',
    'YQB','YQC','ZZ','RR','ZQA', '')),
reinbeitebruker_id3 varchar(3) CHECK (reinbeitebruker_id3 IN
    ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC',
    'ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG',
    'XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT',
    'YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS',
    'XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK',
    'WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA',
    'YQB','YQC','ZZ','RR','ZQA', '')),
-- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
-- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
-- we use a simple comma separated text for now
alle_reinbeitebr_id varchar not null default '',

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent
-- 10: Endret
status int not null default 0,

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmarksbeite
-- TODO add not null after it has been filled
anleggstype int CHECK ( (anleggstype > 0 AND anleggstype < 8) or (anleggstype = 12))

--failed to use
--anleggstype int[3] CHECK (
--  (anleggstype[0] > 0 AND anleggstype[0] < 8) or (anleggstype[0] = 12) AND
--  (anleggstype[1] > 0 AND anleggstype[1] < 8) or (anleggstype[1] = 12) AND
--  (anleggstype[2] > 0 AND anleggstype[2] < 8) or (anleggstype[2] = 12)
--)

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_ran', 'topo_rein', 'reindrift_anlegg_linje', 'linje', 'LINESTRING') As new_layer_id;


-- create function basded index to get performance
CREATE INDEX topo_rein_reindrift_anlegg_linje_geo_relation_id_idx ON topo_rein.reindrift_anlegg_linje(topo_rein.get_relation_id(linje));



-- Should we have one table for all årstidsbeite thems or 5 different tables as today ?
-- We go for the solution with 5 tables now because then it's probably more easy to handle non overlap rules
-- and logically two and two thems form one single map. The only differemse between the 5 tables will be the table name.
-- But if Sandro Santoli says this is easy to use a view to handle toplogy we may need to discuss this again
-- We could also use inheritance but then we aslo get mix rows from different maps.


-- clear out old data added to make testing more easy
-- drop table topo_rein.arstidsbeite_var_flate;
-- drop table topo_rein.reindrift_anlegg_punkt;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'arstidsbeite_var_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'reindrift_anlegg_punkt', 'grense');


-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ?
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data,
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table reindrift_anlegg_punkt
CREATE TABLE topo_rein.reindrift_anlegg_punkt(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- Reffers to the user that is logged in.

saksbehandler varchar,
-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)),

-- angir hvilket reinbeitedistrikt som bruker beiteområdet
-- Definition -- indicates which reindeer pasture district uses the pasture area
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN
    ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC',
    'ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG',
    'XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT',
    'YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS',
    'XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK',
    'WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA',
    'YQB','YQC','ZZ','RR','ZQA')),
reinbeitebruker_id2 varchar(3) CHECK (reinbeitebruker_id2 IN
    ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC',
    'ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG',
    'XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT',
    'YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS',
    'XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK',
    'WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA',
    'YQB','YQC','ZZ','RR','ZQA', '')),
reinbeitebruker_id3 varchar(3) CHECK (reinbeitebruker_id3 IN
    ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC',
    'ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG',
    'XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT',
    'YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS',
    'XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK',
    'WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA',
    'YQB','YQC','ZZ','RR','ZQA', '')),
-- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
-- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
-- we use a simple comma separated text for now
alle_reinbeitebr_id varchar not null default '',

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent
-- 10: Endret
status int not null default 0,

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmarksbeite
anleggstype int CHECK (anleggstype > 9 AND anleggstype < 21)

--failed to use
--anleggstype int[3] CHECK (
--  (anleggstype[0] > 9 AND anleggstype[0] < 21) AND
--  (anleggstype[1] > 9 AND anleggstype[1] < 21) AND
--  (anleggstype[2] > 9 AND anleggstype[2] < 21)
--)

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_ran', 'topo_rein', 'reindrift_anlegg_punkt', 'punkt', 'POINT') As new_layer_id;


-- create function basded index to get performance
CREATE INDEX topo_rein_reindrift_anlegg_punkt_geo_relation_id_idx ON topo_rein.reindrift_anlegg_punkt(topo_rein.get_relation_id(punkt));

select CreateTopology('topo_rein_sysdata_rtr',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rtr.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rtr.face_face_id_seq', 3, false);

-- give puclic access

GRANT USAGE ON SCHEMA topo_rein_sysdata_rtr TO public;

-- Should we have one table for all årstidsbeite thems or 5 different tables as today ?
-- We go for the solution with 5 tables now because then it's probably more easy to handle non overlap rules
-- and logically two and two thems form one single map. The only differemse between the 5 tables will be the table name.
-- But if Sandro Santoli says this is easy to use a view to handle toplogy we may need to discuss this again
-- We could also use inheritance but then we aslo get mix rows from different maps.


-- clear out old data added to make testing more easy
-- drop table topo_rein.arstidsbeite_var_flate;
-- drop table topo_rein.rein_trekklei_linje;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'arstidsbeite_var_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'rein_trekklei_linje', 'grense');


-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ? 
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data, 
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table rein_trekklei_linje
CREATE TABLE topo_rein.rein_trekklei_linje(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- Reffers to the user that is logged in.
saksbehandler varchar,

-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)), 

-- angir hvilket reinbeitedistrikt som bruker beiteområdet 
-- Definition -- indicates which reindeer pasture district uses the pasture area
-- TODO add not null
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')),


-- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
-- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
-- we use a simple comma separated text for now
alle_reinbeitebr_id varchar not null default '',

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent 
-- 10: Endret
status int not null default 0

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rtr', 'topo_rein', 'rein_trekklei_linje', 'linje', 'LINESTRING') As new_layer_id;


-- create function basded index to get performance
CREATE INDEX topo_rein_rein_trekklei_linje_geo_relation_id_idx ON topo_rein.rein_trekklei_linje(topo_rein.get_relation_id(linje));	



-- add row level security
ALTER TABLE topo_rein.rein_trekklei_linje ENABLE ROW LEVEL SECURITY;

-- Give all users select rights  
-- Is another way to do this
CREATE POLICY topo_rein_rein_trekklei_linje_select_policy ON topo_rein.rein_trekklei_linje FOR SELECT  USING(true);

DROP POLICY if EXISTS topo_rein_rein_trekklei_linje_update_policy ON topo_rein.rein_trekklei_linje;

-- Handle update 
CREATE POLICY topo_rein_rein_trekklei_linje_update_policy ON topo_rein.rein_trekklei_linje 
FOR ALL                                                                                                                  
USING
(
-- a user that edit anything
EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.edit_all = true)
OR
reinbeitebruker_id is null
OR
-- a user that has access to certain areas
reinbeitebruker_id = ANY((SELECT  column_value FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.table_name = '*'
AND rl.column_name = 'reinbeitebruker_id'))

-- a user have explicit access to selected table
OR
reinbeitebruker_id = ANY((SELECT  column_value FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.table_name = 'topo_rein.rein_trekklei_linje'
AND rl.column_name = 'reinbeitebruker_id'))

OR
current_setting('pgtopo_update.draw_line_opr') = '1'

)
WITH CHECK
(
-- a user that edit anything
EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.edit_all = true)
OR
reinbeitebruker_id is null
OR
-- a user that has access to certain areas
reinbeitebruker_id = ANY((SELECT  column_value FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.table_name = '*'
AND rl.column_name = 'reinbeitebruker_id'))
-- a user have explicit access to selected table

OR
reinbeitebruker_id = ANY((SELECT  column_value FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.table_name = 'topo_rein.rein_trekklei_linje'
AND rl.column_name = 'reinbeitebruker_id'))

OR
current_setting('pgtopo_update.draw_line_opr') = '1'

)
;
select CreateTopology('topo_rein_sysdata_rbh',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rbh.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rbh.face_face_id_seq', 3, false);

-- give puclic access

GRANT USAGE ON SCHEMA topo_rein_sysdata_rbh TO public;

-- Should we have one table for all årstidsbeite thems or 5 different tables as today ?
-- We go for the solution with 5 tables now because then it's probably more easy to handle non overlap rules
-- and logically two and two thems form one single map. The only differemse between the 5 tables will be the table name.
-- But if Sandro Santoli says this is easy to use a view to handle toplogy we may need to discuss this again
-- We could also use inheritance but then we aslo get mix rows from different maps.

-- clear out old data added to make testing more easy
-- drop table topo_rein.beitehage_flate;
-- drop table topo_rein.beitehage_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'beitehage_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'beitehage_grense', 'grense');

-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ?
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data,
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table beitehage_grense
CREATE TABLE topo_rein.beitehage_grense(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,

-- Reffers to the user that is logged in.
saksbehandler varchar

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rbh', 'topo_rein', 'beitehage_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.beitehage_flate ?

CREATE TABLE topo_rein.beitehage_flate(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
id serial PRIMARY KEY not null,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi
-- removed because this is equal for all rows the value are 'Årstidsbeite'.

-- column område
-- is added later and may renamed to geo
-- Should we call this geo, omrade or område ?
-- use omrade

-- column posisjon point from sosi
-- removed because we don't need it, we can generate it if we need id.
-- all rows here should be of type surface and no rows with point only

-- angir hvilket reinbeitedistrikt som bruker beiteområdet
-- Definition -- indicates which reindeer pasture district uses the pasture area
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')),

-- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
-- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
-- we use a simple comma separated text for now
alle_reinbeitebr_id varchar not null default '',

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent
-- 10: Endret
status int not null default 0,


-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc
-- Definition -- identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
-- Reduces this to only vårbeite I og vårbeite II, because this types form one single map
-- reindrift_sesongomrade_id int CHECK ( reindrift_sesongomrade_id > 0 AND reindrift_sesongomrade_id < 3)
-- CONSTRAINT fk_beitehage_flate_reindrift_sesongomrade_id REFERENCES topo_rein.rein_kode_sesomr(kode) ,

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmarksbeite
-- TODO add not null
reindriftsanleggstype int default 3 NOT NULL CHECK ( reindriftsanleggstype = 3) ,

-- contains felles egenskaper for rein
-- should this be moved to the border, because the is just a result drawing border lines ??
-- what about the value the for indentfikajons ?
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- Reffers to the user that is logged in.
saksbehandler varchar,

-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)),

-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258)

);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rbh', 'topo_rein', 'beitehage_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t
	--WHERE t.name = 'topo_rein_sysdata_rbh' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'beitehage_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;


COMMENT ON TABLE topo_rein.beitehage_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.beitehage_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.beitehage_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.beitehage_flate.geo IS 'This holds the ref to topo_rein_sysdata_rbh.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_beitehage_flate_geo_relation_id_idx ON topo_rein.beitehage_flate(topo_rein.get_relation_id(omrade));

COMMENT ON INDEX topo_rein.topo_rein_beitehage_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';

SELECT CreateTopology('topo_rein_sysdata_rop', 4258, 0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rop.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rop.face_face_id_seq', 3, false);

-- give puclic access
GRANT USAGE ON SCHEMA topo_rein_sysdata_rop TO public;

-- Should we have one table for all årstidsbeite thems or 5 different tables as today ?
-- We go for the solution with 5 tables now because then it's probably more easy to handle non overlap rules
-- and logically two and two thems form one single map. The only differemse between the 5 tables will be the table name.
-- But if Sandro Santoli says this is easy to use a view to handle toplogy we may need to discuss this again
-- We could also use inheritance but then we aslo get mix rows from different maps.

-- clear out old data added to make testing more easy
-- drop table topo_rein.oppsamlingsomrade_flate;
-- drop table topo_rein.oppsamlingsomrade_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'oppsamlingsomrade_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'oppsamlingsomrade_grense', 'grense');

-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ?
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data,
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table oppsamlingsomrade_grense
CREATE TABLE topo_rein.oppsamlingsomrade_grense(
  -- a internal id will that can be changed when ver needed
  -- may be used by the update client when reffering to a certain row when we do a update
  -- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
  -- We could also define this as UUID and use a copy from felles_egenskaper
  id serial PRIMARY KEY NOT NULL,
  -- gjøres om til lokalid

  -- objtype VARCHAR(40) from sosi and what should the value be ????

  -- contains felles egenskaper for rein
  -- may be null because it is updated after id is set because it this id is used a localid
  felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,

  -- Reffers to the user that is logged in.
  saksbehandler varchar
);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn(
  'topo_rein_sysdata_rop', 'topo_rein', 'oppsamlingsomrade_grense', 'grense', 'LINESTRING'
) AS new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.oppsamlingsomrade_flate ?

CREATE TABLE topo_rein.oppsamlingsomrade_flate(
  -- a internal id will that can be changed when ver needed
  -- may be used by the update client when reffering to a certain row when we do a update
  -- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
  -- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
  id SERIAL PRIMARY KEY NOT NULL,
  -- gjøres om til lokalid

  -- objtype VARCHAR(40) from sosi
  -- removed because this is equal for all rows the value are 'Årstidsbeite'.

  -- column område
  -- is added later and may renamed to geo
  -- Should we call this geo, omrade or område ?
  -- use omrade

  -- column posisjon point from sosi
  -- removed because we don't need it, we can generate it if we need id.
  -- all rows here should be of type surface and no rows with point only

  -- angir hvilket reinbeitedistrikt som bruker beiteområdet
  -- Definition -- indicates which reindeer pasture district uses the pasture area
  reinbeitebruker_id VARCHAR(3) CHECK (reinbeitebruker_id IN (
    'XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC',
    'ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG',
    'XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT',
    'YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS',
    'XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK',
    'WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA',
    'YQB','YQC','ZZ','RR','ZQA'
  )),
  reinbeitebruker_id2 VARCHAR(3) CHECK (reinbeitebruker_id2 IN (
    'XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC',
    'ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG',
    'XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT',
    'YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS',
    'XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK',
    'WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA',
    'YQB','YQC','ZZ','RR','ZQA'
  )),
  reinbeitebruker_id3 VARCHAR(3) CHECK (reinbeitebruker_id3 IN (
    'XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC',
    'ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG',
    'XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT',
    'YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS',
    'XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK',
    'WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA',
    'YQB','YQC','ZZ','RR','ZQA'
  )),

  -- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
  -- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
  -- we use a simple comma separated text for now
  -- alle_reinbeitebr_id varchar not null default '',

  -- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
  -- Here is a list of the current states.
  -- 0: Ukjent (uknown)
  -- 1: Godkjent
  -- 10: Endret
  status INT NOT NULL DEFAULT 0,

  -- contains felles egenskaper for rein
  -- should this be moved to the border, because the is just a result drawing border lines ??
  -- what about the value the for indentfikajons ?
  -- may be null because it is updated after id is set because it this id is used a localid
  felles_egenskaper topo_rein.sosi_felles_egenskaper,

  -- Reffers to the user that is logged in.
  saksbehandler VARCHAR,

  -- This is used by the user to indicate that he wants to delete object or not use it
  -- 0 menas that the object exits in normal way
  -- 1 menas that the users has selcted delete object
  slette_status_kode SMALLINT NOT NULL DEFAULT 0  CHECK (slette_status_kode IN (0, 1)),

  -- added because of performance, used by wms and sp on
  -- update in the same transaction as the topo objekt
  simple_geo geometry(MultiPolygon, 4258)
);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn(
  'topo_rein_sysdata_rop', 'topo_rein', 'oppsamlingsomrade_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t
	--WHERE t.name = 'topo_rein_sysdata_rop' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'oppsamlingsomrade_grense' AND l.feature_column = 'grense')::int
) AS new_layer_id;

COMMENT ON TABLE topo_rein.oppsamlingsomrade_flate IS
  'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';
COMMENT ON COLUMN topo_rein.oppsamlingsomrade_flate.id IS
  'Unique identifier of a surface';
COMMENT ON COLUMN topo_rein.oppsamlingsomrade_flate.felles_egenskaper IS
  'Sosi common meta attribute part of kvaliet TODO create user defined type ?';
-- COMMENT ON COLUMN topo_rein.oppsamlingsomrade_flate.geo IS 'This holds the ref to topo_rein_sysdata_rop.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_oppsamlingsomrade_flate_geo_relation_id_idx ON topo_rein.oppsamlingsomrade_flate(topo_rein.get_relation_id(omrade));

COMMENT ON INDEX topo_rein.topo_rein_oppsamlingsomrade_flate_geo_relation_id_idx IS
  'A function based index to faster find the topo rows for in the relation table';
select CreateTopology('topo_rein_sysdata_rav',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rav.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rav.face_face_id_seq', 3, false);

-- give puclic access
GRANT USAGE ON SCHEMA topo_rein_sysdata_rav TO public;

-- clear out old data added to make testing more easy
-- drop table topo_rein.avtaleomrade_flate;
-- drop table topo_rein.avtaleomrade_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'avtaleomrade_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'avtaleomrade_grense', 'grense');

-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ?
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data,
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table avtaleomrade_grense
DROP TABLE IF EXISTS topo_rein.avtaleomrade_grense cascade;
CREATE TABLE topo_rein.avtaleomrade_grense(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,

-- Reffers to the user that is logged in.
saksbehandler varchar

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rav', 'topo_rein', 'avtaleomrade_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.avtaleomrade_flate ?


DROP TABLE IF EXISTS topo_rein.avtaleomrade_flate cascade;
CREATE TABLE topo_rein.avtaleomrade_flate(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
id serial PRIMARY KEY not null,
-- gjøres om til lokalid

-- column område
-- is added later and may renamed to geo
-- Should we call this geo, omrade or område ?
-- use omrade

-- column posisjon point from sosi
-- removed because we don't need it, we can generate it if we need id.
-- all rows here should be of type surface and no rows with point only

-- angir hvilket avtaleomrade som bruker beiteområdet
-- Definition -- indicates which reindeer pasture district uses the pasture area
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')),

-- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
-- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
-- we use a simple comma separated text for now
-- alle_reinbeitebr_id varchar not null default '',

avtaletype varchar(2),

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent
-- 10: Endret
status int not null default 0,

-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc
-- Definition -- identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
-- Reduces this to only vårbeite I og vårbeite II, because this types form one single map
-- reindrift_sesongomrade_id int CHECK ( reindrift_sesongomrade_id > 0 AND reindrift_sesongomrade_id < 3)
-- CONSTRAINT fk_avtaleomrade_flate_reindrift_sesongomrade_id REFERENCES topo_rein.rein_kode_sesomr(kode) ,

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmaravbeite
-- TODO add not null
-- reindriftsanleggstype int default 3 NOT NULL CHECK ( reindriftsanleggstype = 3) ,

-- contains felles egenskaper for rein
-- should this be moved to the border, because the is just a result drawing border lines ??
-- what about the value the for indentfikajons ?
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- Reffers to the user that is logged in.
saksbehandler varchar,

-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)),

-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258)

);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rav', 'topo_rein', 'avtaleomrade_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t
	--WHERE t.name = 'topo_rein_sysdata_rav' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'avtaleomrade_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;


COMMENT ON TABLE topo_rein.avtaleomrade_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.avtaleomrade_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.avtaleomrade_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.avtaleomrade_flate.geo IS 'This holds the ref to topo_rein_sysdata_rav.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_avtaleomrade_flate_geo_relation_id_idx ON topo_rein.avtaleomrade_flate(topo_rein.get_relation_id(omrade));

COMMENT ON INDEX topo_rein.topo_rein_avtaleomrade_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';

select CreateTopology('topo_rein_sysdata_reo',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_reo.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_reo.face_face_id_seq', 3, false);

-- give puclic access
GRANT USAGE ON SCHEMA topo_rein_sysdata_reo TO public;

-- clear out old data added to make testing more easy
-- drop table topo_rein.ekspropriasjonsomrade_flate;
-- drop table topo_rein.ekspropriasjonsomrade_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'ekspropriasjonsomrade_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'ekspropriasjonsomrade_grense', 'grense');

-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ?
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data,
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table ekspropriasjonsomrade_grense
DROP TABLE IF EXISTS topo_rein.ekspropriasjonsomrade_grense cascade;
CREATE TABLE topo_rein.ekspropriasjonsomrade_grense(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,


-- Reffers to the user that is logged in.
saksbehandler varchar

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_reo', 'topo_rein', 'ekspropriasjonsomrade_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.ekspropriasjonsomrade_flate ?


DROP TABLE IF EXISTS topo_rein.ekspropriasjonsomrade_flate cascade;
CREATE TABLE topo_rein.ekspropriasjonsomrade_flate(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
id serial PRIMARY KEY not null,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi
-- removed because this is equal for all rows the value are 'Årstidsbeite'.

-- column område
-- is added later and may renamed to geo
-- Should we call this geo, omrade or område ?
-- use omrade

-- column posisjon point from sosi
-- removed because we don't need it, we can generate it if we need id.
-- all rows here should be of type surface and no rows with point only

-- angir hvilket ekspropriasjonsomrade som bruker beiteområdet
-- Definition -- indicates which reindeer pasture district uses the pasture area
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')),

kongeligresolusjon date,

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent
-- 10: Endret
status int not null default 0,

-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc
-- Definition -- identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
-- Reduces this to only vårbeite I og vårbeite II, because this types form one single map
-- reindrift_sesongomrade_id int CHECK ( reindrift_sesongomrade_id > 0 AND reindrift_sesongomrade_id < 3)
-- CONSTRAINT fk_ekspropriasjonsomrade_flate_reindrift_sesongomrade_id REFERENCES topo_rein.rein_kode_sesomr(kode) ,

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmarksbeite
-- TODO add not null
-- reindriftsanleggstype int default 3 NOT NULL CHECK ( reindriftsanleggstype = 3) ,

-- contains felles egenskaper for rein
-- should this be moved to the border, because the is just a result drawing border lines ??
-- what about the value the for indentfikajons ?
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- Reffers to the user that is logged in.
saksbehandler varchar,

-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)),

-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258)

);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_reo', 'topo_rein', 'ekspropriasjonsomrade_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t
	--WHERE t.name = 'topo_rein_sysdata_reo' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'ekspropriasjonsomrade_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;


COMMENT ON TABLE topo_rein.ekspropriasjonsomrade_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.ekspropriasjonsomrade_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.ekspropriasjonsomrade_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.ekspropriasjonsomrade_flate.geo IS 'This holds the ref to topo_rein_sysdata_reo.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_ekspropriasjonsomrade_flate_geo_relation_id_idx ON topo_rein.ekspropriasjonsomrade_flate(topo_rein.get_relation_id(omrade));

COMMENT ON INDEX topo_rein.topo_rein_ekspropriasjonsomrade_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';

select CreateTopology('topo_rein_sysdata_rks',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rks.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rks.face_face_id_seq', 3, false);

-- give puclic access
GRANT USAGE ON SCHEMA topo_rein_sysdata_rks TO public;

-- clear out old data added to make testing more easy
-- drop table topo_rein.konsesjonsomrade_flate;
-- drop table topo_rein.konsesjonsomrade_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'konsesjonsomrade_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'konsesjonsomrade_grense', 'grense');

-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ?
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data,
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table konsesjonsomrade_grense
DROP TABLE IF EXISTS topo_rein.konsesjonsomrade_grense cascade;
CREATE TABLE topo_rein.konsesjonsomrade_grense(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,

-- Reffers to the user that is logged in.
saksbehandler varchar

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rks', 'topo_rein', 'konsesjonsomrade_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.konsesjonsomrade_flate ?


DROP TABLE IF EXISTS topo_rein.konsesjonsomrade_flate cascade;
CREATE TABLE topo_rein.konsesjonsomrade_flate(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
id serial PRIMARY KEY not null,
-- gjøres om til lokalid

-- column område
-- is added later and may renamed to geo
-- Should we call this geo, omrade or område ?
-- use omrade

-- column posisjon point from sosi
-- removed because we don't need it, we can generate it if we need id.
-- all rows here should be of type surface and no rows with point only

-- angir hvilket konsesjonsomrade som bruker beiteområdet
-- Definition -- indicates which reindeer pasture district uses the pasture area
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')),

-- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
-- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
-- we use a simple comma separated text for now
-- alle_reinbeitebr_id varchar not null default '',

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent
-- 10: Endret
status int not null default 0,

-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc
-- Definition -- identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
-- Reduces this to only vårbeite I og vårbeite II, because this types form one single map
-- reindrift_sesongomrade_id int CHECK ( reindrift_sesongomrade_id > 0 AND reindrift_sesongomrade_id < 3)
-- CONSTRAINT fk_konsesjonsomrade_flate_reindrift_sesongomrade_id REFERENCES topo_rein.rein_kode_sesomr(kode) ,

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmarksbeite
-- TODO add not null
-- reindriftsanleggstype int default 3 NOT NULL CHECK ( reindriftsanleggstype = 3) ,

-- contains felles egenskaper for rein
-- should this be moved to the border, because the is just a result drawing border lines ??
-- what about the value the for indentfikajons ?
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- Reffers to the user that is logged in.
saksbehandler varchar,

-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)),

-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258)

);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rks', 'topo_rein', 'konsesjonsomrade_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t
	--WHERE t.name = 'topo_rein_sysdata_rks' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'konsesjonsomrade_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;


COMMENT ON TABLE topo_rein.konsesjonsomrade_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.konsesjonsomrade_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.konsesjonsomrade_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.konsesjonsomrade_flate.geo IS 'This holds the ref to topo_rein_sysdata_rks.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_konsesjonsomrade_flate_geo_relation_id_idx ON topo_rein.konsesjonsomrade_flate(topo_rein.get_relation_id(omrade));

COMMENT ON INDEX topo_rein.topo_rein_konsesjonsomrade_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';

select CreateTopology('topo_rein_sysdata_rko',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rko.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rko.face_face_id_seq', 3, false);

-- give puclic access

GRANT USAGE ON SCHEMA topo_rein_sysdata_rko TO public;

-- clear out old data added to make testing more easy
-- drop table topo_rein.konvensjonsomrade_flate;
-- drop table topo_rein.konvensjonsomrade_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'konvensjonsomrade_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'konvensjonsomrade_grense', 'grense');

-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ?
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data,
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table konvensjonsomrade_grense
DROP TABLE IF EXISTS topo_rein.konvensjonsomrade_grense cascade;
CREATE TABLE topo_rein.konvensjonsomrade_grense(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,

-- Reffers to the user that is logged in.
saksbehandler varchar

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rko', 'topo_rein', 'konvensjonsomrade_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.konvensjonsomrade_flate ?

DROP TABLE IF EXISTS topo_rein.konvensjonsomrade_flate cascade;
CREATE TABLE topo_rein.konvensjonsomrade_flate(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
id serial PRIMARY KEY not null,
-- gjøres om til lokalid

-- column område
-- is added later and may renamed to geo
-- Should we call this geo, omrade or område ?
-- use omrade

-- column posisjon point from sosi
-- removed because we don't need it, we can generate it if we need id.
-- all rows here should be of type surface and no rows with point only

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent
-- 10: Endret
status int not null default 0,

-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc
-- Definition -- identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
-- Reduces this to only vårbeite I og vårbeite II, because this types form one single map
-- reindrift_sesongomrade_id int CHECK ( reindrift_sesongomrade_id > 0 AND reindrift_sesongomrade_id < 3)
-- CONSTRAINT fk_konvensjonsomrade_flate_reindrift_sesongomrade_id REFERENCES topo_rein.rein_kode_sesomr(kode) ,

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmarksbeite
-- TODO add not null
-- reindriftsanleggstype int default 3 NOT NULL CHECK ( reindriftsanleggstype = 3) ,

-- contains felles egenskaper for rein
-- should this be moved to the border, because the is just a result drawing border lines ??
-- what about the value the for indentfikajons ?
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

reinbeitebruker_id VARCHAR(3) CHECK (reinbeitebruker_id IN (
  'XI', 'ZA', 'ZB', 'ZC', 'ZD', 'ZE', 'ZF', 'ØG', 'UW', 'UX', 'UY', 'UZ', 'ØA',
  'ØB', 'ØC', 'ØE', 'ØF', 'ZG', 'ZH', 'ZJ', 'ZS', 'ZL', 'ZÅ', 'YA', 'YB', 'YC',
  'YD', 'YE', 'YF', 'YG', 'XM', 'XR', 'XT', 'YH', 'YI', 'YJ', 'YK', 'YL', 'YM',
  'YN', 'YP', 'YX', 'YR', 'YS', 'YT', 'YU', 'YV', 'YW', 'YY', 'XA', 'XD', 'XE',
  'XG', 'XH', 'XJ', 'XK', 'XL', 'XM', 'XR', 'XS', 'XT', 'XN', 'XØ', 'XP', 'XU',
  'XV', 'XW', 'XZ', 'XX', 'XY', 'WA', 'WB', 'WD', 'WF', 'WK', 'WL', 'WN', 'WP',
  'WR', 'WS', 'WX', 'WZ', 'VA', 'VF', 'VG', 'VJ', 'VM', 'VR', 'YQA', 'YQB',
  'YQC', 'ZZ', 'RR', 'ZQA'
)),

-- Reffers to the user that is logged in.
saksbehandler varchar,

-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)),

-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258)

);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rko', 'topo_rein', 'konvensjonsomrade_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t
	--WHERE t.name = 'topo_rein_sysdata_rko' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'konvensjonsomrade_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;


COMMENT ON TABLE topo_rein.konvensjonsomrade_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.konvensjonsomrade_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.konvensjonsomrade_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.konvensjonsomrade_flate.geo IS 'This holds the ref to topo_rein_sysdata_rko.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_konvensjonsomrade_flate_geo_relation_id_idx ON topo_rein.konvensjonsomrade_flate(topo_rein.get_relation_id(omrade));

COMMENT ON INDEX topo_rein.topo_rein_konvensjonsomrade_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';
select CreateTopology('topo_rein_sysdata_rdg',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rdg.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rdg.face_face_id_seq', 3, false);

-- give puclic access

GRANT USAGE ON SCHEMA topo_rein_sysdata_rdg TO public;

-- clear out old data added to make testing more easy
-- drop table topo_rein.reinbeitedistrikt_flate;
-- drop table topo_rein.reinbeitedistrikt_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'reinbeitedistrikt_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'reinbeitedistrikt_grense', 'grense');

-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ?
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data,
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table reinbeitedistrikt_grense
DROP TABLE IF EXISTS topo_rein.reinbeitedistrikt_grense cascade;
CREATE TABLE topo_rein.reinbeitedistrikt_grense(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,

-- Reffers to the user that is logged in.
saksbehandler varchar

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rdg', 'topo_rein', 'reinbeitedistrikt_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.reinbeitedistrikt_flate ?


DROP TABLE IF EXISTS topo_rein.reinbeitedistrikt_flate cascade;
CREATE TABLE topo_rein.reinbeitedistrikt_flate(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
id serial PRIMARY KEY not null,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi
-- removed because this is equal for all rows the value are 'Årstidsbeite'.

-- column område
-- is added later and may renamed to geo
-- Should we call this geo, omrade or område ?
-- use omrade

-- column posisjon point from sosi
-- removed because we don't need it, we can generate it if we need id.
-- all rows here should be of type surface and no rows with point only

-- angir hvilket reinbeitedistrikt som bruker beiteområdet
-- Definition -- indicates which reindeer pasture district uses the pasture area
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')),

-- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
-- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
-- we use a simple comma separated text for now
alle_reinbeitebr_id varchar not null default '',

navn varchar not null default '',

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent
-- 10: Endret
status int not null default 0,

-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc
-- Definition -- identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
-- Reduces this to only vårbeite I og vårbeite II, because this types form one single map
-- reindrift_sesongomrade_id int CHECK ( reindrift_sesongomrade_id > 0 AND reindrift_sesongomrade_id < 3)
-- CONSTRAINT fk_reinbeitedistrikt_flate_reindrift_sesongomrade_id REFERENCES topo_rein.rein_kode_sesomr(kode) ,

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmarksbeite
-- TODO add not null
-- reindriftsanleggstype int default 3 NOT NULL CHECK ( reindriftsanleggstype = 3) ,

-- contains felles egenskaper for rein
-- should this be moved to the border, because the is just a result drawing border lines ??
-- what about the value the for indentfikajons ?
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- Reffers to the user that is logged in.
saksbehandler varchar,

-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)),

-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258)

);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rdg', 'topo_rein', 'reinbeitedistrikt_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t
	--WHERE t.name = 'topo_rein_sysdata_rdg' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'reinbeitedistrikt_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;


COMMENT ON TABLE topo_rein.reinbeitedistrikt_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.reinbeitedistrikt_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.reinbeitedistrikt_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.reinbeitedistrikt_flate.geo IS 'This holds the ref to topo_rein_sysdata_rdg.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_reinbeitedistrikt_flate_geo_relation_id_idx ON topo_rein.reinbeitedistrikt_flate(topo_rein.get_relation_id(omrade));

COMMENT ON INDEX topo_rein.topo_rein_reinbeitedistrikt_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';

select CreateTopology('topo_rein_sysdata_reb',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_reb.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_reb.face_face_id_seq', 3, false);

-- give puclic access

GRANT USAGE ON SCHEMA topo_rein_sysdata_reb TO public;

-- clear out old data added to make testing more easy
-- drop table topo_rein.reinbeiteomrade_flate cascade;
-- drop table topo_rein.reinbeiteomrade_grense cascade;
-- drop table topo_rein.reinbeiteomrade_punkt cascade;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'reinbeiteomrade_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'reinbeiteomrade_grense', 'grense');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'reinbeiteomrade_punk', 'punkt');

-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ?
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data,
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table reinbeiteomrade_punkt
DROP TABLE IF EXISTS topo_rein.reinbeiteomrade_punkt cascade;
CREATE TABLE topo_rein.reinbeiteomrade_punkt(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

reinbeiteområde_id varchar(3) CHECK (reinbeiteområde_id IN ('U', 'V', 'W', 'X', 'Y', 'Z')),

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,

-- Reffers to the user that is logged in.
saksbehandler varchar
);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_reb', 'topo_rein', 'reinbeiteomrade_punkt', 'punkt', 'POINT') As new_layer_id;

-- If yes then we need the table reinbeiteomrade_grense
DROP TABLE IF EXISTS topo_rein.reinbeiteomrade_grense cascade;
CREATE TABLE topo_rein.reinbeiteomrade_grense(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,

-- Reffers to the user that is logged in.
saksbehandler varchar
);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_reb', 'topo_rein', 'reinbeiteomrade_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.reinbeiteomrade_flate ?

DROP TABLE IF EXISTS topo_rein.reinbeiteomrade_flate cascade;
CREATE TABLE topo_rein.reinbeiteomrade_flate(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
id serial PRIMARY KEY not null,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi
-- removed because this is equal for all rows the value are 'Årstidsbeite'.

-- column område
-- is added later and may renamed to geo
-- Should we call this geo, omrade or område ?
-- use omrade

-- column posisjon point from sosi
-- removed because we don't need it, we can generate it if we need id.
-- all rows here should be of type surface and no rows with point only

reinbeiteområde_id VARCHAR(3) CHECK (reinbeiteområde_id IN ('U', 'V', 'W', 'X', 'Y', 'Z')),

-- angir hvilket reinbeiteomrade som bruker beiteområdet
-- Definition -- indicates which reindeer pasture district uses the pasture area
reinbeitebruker_id VARCHAR(3) CHECK (reinbeitebruker_id IN (
  'XI', 'ZA', 'ZB', 'ZC', 'ZD', 'ZE', 'ZF', 'ØG', 'UW', 'UX', 'UY', 'UZ', 'ØA',
  'ØB', 'ØC', 'ØE', 'ØF', 'ZG', 'ZH', 'ZJ', 'ZS', 'ZL', 'ZÅ', 'YA', 'YB', 'YC',
  'YD', 'YE', 'YF', 'YG', 'XM', 'XR', 'XT', 'YH', 'YI', 'YJ', 'YK', 'YL', 'YM',
  'YN', 'YP', 'YX', 'YR', 'YS', 'YT', 'YU', 'YV', 'YW', 'YY', 'XA', 'XD', 'XE',
  'XG', 'XH', 'XJ', 'XK', 'XL', 'XM', 'XR', 'XS', 'XT', 'XN', 'XØ', 'XP', 'XU',
  'XV', 'XW', 'XZ', 'XX', 'XY', 'WA', 'WB', 'WD', 'WF', 'WK', 'WL', 'WN', 'WP',
  'WR', 'WS', 'WX', 'WZ', 'VA', 'VF', 'VG', 'VJ', 'VM', 'VR', 'YQA', 'YQB',
  'YQC', 'ZZ', 'RR', 'ZQA'
)),

-- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
-- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
-- we use a simple comma separated text for now
-- alle_reinbeitebr_id varchar not null default '',

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent
-- 10: Endret
status int not null default 0,

-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc
-- Definition -- identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
-- Reduces this to only vårbeite I og vårbeite II, because this types form one single map
-- reindrift_sesongomrade_id int CHECK ( reindrift_sesongomrade_id > 0 AND reindrift_sesongomrade_id < 3)
-- CONSTRAINT fk_reinbeiteomrade_flate_reindrift_sesongomrade_id REFERENCES topo_rein.rein_kode_sesomr(kode) ,

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmarksbeite
-- TODO add not null
-- reindriftsanleggstype int default 3 NOT NULL CHECK ( reindriftsanleggstype = 3) ,

-- contains felles egenskaper for rein
-- should this be moved to the border, because the is just a result drawing border lines ??
-- what about the value the for indentfikajons ?
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- Reffers to the user that is logged in.
saksbehandler varchar,

-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)),

-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258)
);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_reb', 'topo_rein', 'reinbeiteomrade_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t
	--WHERE t.name = 'topo_rein_sysdata_reb' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'reinbeiteomrade_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;


COMMENT ON TABLE topo_rein.reinbeiteomrade_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.reinbeiteomrade_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.reinbeiteomrade_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvalitet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.reinbeiteomrade_flate.geo IS 'This holds the ref to topo_rein_sysdata_reb.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_reinbeiteomrade_flate_geo_relation_id_idx ON topo_rein.reinbeiteomrade_flate(topo_rein.get_relation_id(omrade));

COMMENT ON INDEX topo_rein.topo_rein_reinbeiteomrade_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';
select CreateTopology('topo_rein_sysdata_rro',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rro.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rro.face_face_id_seq', 3, false);

-- give puclic access
GRANT USAGE ON SCHEMA topo_rein_sysdata_rro TO public;

-- clear out old data added to make testing more easy
-- drop table topo_rein.restriksjonsomrade_flate;
-- drop table topo_rein.restriksjonsomrade_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'restriksjonsomrade_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'restriksjonsomrade_grense', 'grense');

-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ?
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data,
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table restriksjonsomrade_grense
DROP TABLE IF EXISTS topo_rein.restriksjonsomrade_grense cascade;
CREATE TABLE topo_rein.restriksjonsomrade_grense(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????
dom_instans varchar(2),
dom_dato date,
dom_i_kraft date,

informasjon text,

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,

-- Reffers to the user that is logged in.
saksbehandler varchar

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rro', 'topo_rein', 'restriksjonsomrade_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.restriksjonsomrade_flate ?


DROP TABLE IF EXISTS topo_rein.restriksjonsomrade_flate cascade;
CREATE TABLE topo_rein.restriksjonsomrade_flate(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
id serial PRIMARY KEY not null,
-- gjøres om til lokalid

-- column område
-- is added later and may renamed to geo
-- Should we call this geo, omrade or område ?
-- use omrade

-- column posisjon point from sosi
-- removed because we don't need it, we can generate it if we need id.
-- all rows here should be of type surface and no rows with point only

dom_instans varchar(2),
dom_dato date,
dom_i_kraft date,

informasjon text,

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent
-- 10: Endret
status int not null default 0,

-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc
-- Definition -- identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
-- Reduces this to only vårbeite I og vårbeite II, because this types form one single map
-- reindrift_sesongomrade_id int CHECK ( reindrift_sesongomrade_id > 0 AND reindrift_sesongomrade_id < 3)
-- CONSTRAINT fk_restriksjonsomrade_flate_reindrift_sesongomrade_id REFERENCES topo_rein.rein_kode_sesomr(kode) ,

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmarrobeite
-- TODO add not null
-- reindriftsanleggstype int default 3 NOT NULL CHECK ( reindriftsanleggstype = 3) ,

-- contains felles egenskaper for rein
-- should this be moved to the border, because the is just a result drawing border lines ??
-- what about the value the for indentfikajons ?
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

reinbeitebruker_id VARCHAR(3) CHECK (reinbeitebruker_id IN (
  'XI', 'ZA', 'ZB', 'ZC', 'ZD', 'ZE', 'ZF', 'ØG', 'UW', 'UX', 'UY', 'UZ', 'ØA',
  'ØB', 'ØC', 'ØE', 'ØF', 'ZG', 'ZH', 'ZJ', 'ZS', 'ZL', 'ZÅ', 'YA', 'YB', 'YC',
  'YD', 'YE', 'YF', 'YG', 'XM', 'XR', 'XT', 'YH', 'YI', 'YJ', 'YK', 'YL', 'YM',
  'YN', 'YP', 'YX', 'YR', 'YS', 'YT', 'YU', 'YV', 'YW', 'YY', 'XA', 'XD', 'XE',
  'XG', 'XH', 'XJ', 'XK', 'XL', 'XM', 'XR', 'XS', 'XT', 'XN', 'XØ', 'XP', 'XU',
  'XV', 'XW', 'XZ', 'XX', 'XY', 'WA', 'WB', 'WD', 'WF', 'WK', 'WL', 'WN', 'WP',
  'WR', 'WS', 'WX', 'WZ', 'VA', 'VF', 'VG', 'VJ', 'VM', 'VR', 'YQA', 'YQB',
  'YQC', 'ZZ', 'RR', 'ZQA'
)),

-- Reffers to the user that is logged in.
saksbehandler varchar,

-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)),

-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258)

);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rro', 'topo_rein', 'restriksjonsomrade_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t
	--WHERE t.name = 'topo_rein_sysdata_rro' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'restriksjonsomrade_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;


COMMENT ON TABLE topo_rein.restriksjonsomrade_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.restriksjonsomrade_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.restriksjonsomrade_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.restriksjonsomrade_flate.geo IS 'This holds the ref to topo_rein_sysdata_rro.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_restriksjonsomrade_flate_geo_relation_id_idx ON topo_rein.restriksjonsomrade_flate(topo_rein.get_relation_id(omrade));

COMMENT ON INDEX topo_rein.topo_rein_restriksjonsomrade_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';
DROP TABLE IF EXISTS topo_rein.restriksjonsomrade_linje cascade;
CREATE TABLE topo_rein.restriksjonsomrade_linje(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????
dom_instans varchar(2),
dom_dato date,
dom_i_kraft date,

status int not null default 0,

informasjon text,

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,

-- Reffers to the user that is logged in.
saksbehandler varchar,

slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1))

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rro', 'topo_rein', 'restriksjonsomrade_linje', 'linje', 'LINESTRING') As new_layer_id;

-- create function basded index to get performance
CREATE INDEX topo_rein_restriksjonsomrade_linje_geo_relation_id_idx ON topo_rein.restriksjonsomrade_linje(topo_rein.get_relation_id(linje));

COMMENT ON INDEX topo_rein.topo_rein_restriksjonsomrade_linje_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';

select CreateTopology('topo_rein_sysdata_rsi',4258,0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rsi.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rsi.face_face_id_seq', 3, false);

-- give puclic access
GRANT USAGE ON SCHEMA topo_rein_sysdata_rsi TO public;

-- clear out old data added to make testing more easy
-- drop table topo_rein.siidaomrade_flate;
-- drop table topo_rein.siidaomrade_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'siidaomrade_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'siidaomrade_grense', 'grense');

-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ?
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data,
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table siidaomrade_grense
DROP TABLE IF EXISTS topo_rein.siidaomrade_grense cascade;
CREATE TABLE topo_rein.siidaomrade_grense(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper
id serial PRIMARY KEY NOT NULL,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi and what should the value be ????

-- contains felles egenskaper for rein
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,

-- Reffers to the user that is logged in.
saksbehandler varchar

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rsi', 'topo_rein', 'siidaomrade_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.siidaomrade_flate ?

DROP TABLE IF EXISTS topo_rein.siidaomrade_flate cascade;
CREATE TABLE topo_rein.siidaomrade_flate(

-- a internal id will that can be changed when ver needed
-- may be used by the update client when reffering to a certain row when we do a update
-- We could here use indefikajons from the composite type felles_egenskaper, but I am not sure how to use this a primary key ?
-- We could also define this as UUID and use a copy from felles_egenskaper.indefikajons
id serial PRIMARY KEY not null,
-- gjøres om til lokalid

-- objtype VARCHAR(40) from sosi
-- removed because this is equal for all rows the value are 'Årstidsbeite'.

-- column område
-- is added later and may renamed to geo
-- Should we call this geo, omrade or område ?
-- use omrade

-- column posisjon point from sosi
-- removed because we don't need it, we can generate it if we need id.
-- all rows here should be of type surface and no rows with point only

-- angir hvilket siidaomrade som bruker beiteområdet
-- Definition -- indicates which reindeer pasture district uses the pasture area
reinbeitebruker_id VARCHAR(3) CHECK (reinbeitebruker_id IN (
  'XI', 'ZA', 'ZB', 'ZC', 'ZD', 'ZE', 'ZF', 'ØG', 'UW', 'UX', 'UY', 'UZ', 'ØA',
  'ØB', 'ØC', 'ØE', 'ØF', 'ZG', 'ZH', 'ZJ', 'ZS', 'ZL', 'ZÅ', 'YA', 'YB', 'YC',
  'YD', 'YE', 'YF', 'YG', 'XM', 'XR', 'XT', 'YH', 'YI', 'YJ', 'YK', 'YL', 'YM',
  'YN', 'YP', 'YX', 'YR', 'YS', 'YT', 'YU', 'YV', 'YW', 'YY', 'XA', 'XD', 'XE',
  'XG', 'XH', 'XJ', 'XK', 'XL', 'XM', 'XR', 'XS', 'XT', 'XN', 'XØ', 'XP', 'XU',
  'XV', 'XW', 'XZ', 'XX', 'XY', 'WA', 'WB', 'WD', 'WF', 'WK', 'WL', 'WN', 'WP',
  'WR', 'WS', 'WX', 'WZ', 'VA', 'VF', 'VG', 'VJ', 'VM', 'VR', 'YQA', 'YQB',
  'YQC', 'ZZ', 'RR', 'ZQA'
)),

-- Since we in sosi can have multiple reinbeitebruker_id, this list contains the origninal list from the sosi file
-- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]), but since we are not sure about how this field is used
-- we use a simple comma separated text for now
-- alle_reinbeitebr_id varchar not null default '',

-- navn text not null default '',
-- not null produces an error during sf2topo function that results in empty tables
navn text default '',

-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
-- Here is a list of the current states.
-- 0: Ukjent (uknown)
-- 1: Godkjent
-- 10: Endret
status int not null default 0,

-- identifiserer hvorvidt reinbeiteområdet er egnet og brukes til vårbeite, høstbeite, etc
-- Definition -- identifies whether the reindeer pasture area is suitable and is being used for spring grazing, autumn grazing, etc.
-- Reduces this to only vårbeite I og vårbeite II, because this types form one single map
-- reindrift_sesongomrade_id int CHECK ( reindrift_sesongomrade_id > 0 AND reindrift_sesongomrade_id < 3)
-- CONSTRAINT fk_siidaomrade_flate_reindrift_sesongomrade_id REFERENCES topo_rein.rein_kode_sesomr(kode) ,

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmarksbeite
-- TODO add not null
-- reindriftsanleggstype int default 3 NOT NULL CHECK ( reindriftsanleggstype = 3) ,

-- contains felles egenskaper for rein
-- should this be moved to the border, because the is just a result drawing border lines ??
-- what about the value the for indentfikajons ?
-- may be null because it is updated after id is set because it this id is used a localid
felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- Reffers to the user that is logged in.
saksbehandler varchar,

-- This is used by the user to indicate that he wants to delete object or not use it
-- 0 menas that the object exits in normal way
-- 1 menas that the users has selcted delete object
slette_status_kode smallint not null default 0  CHECK (slette_status_kode IN (0,1)),

-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258)

);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rsi', 'topo_rein', 'siidaomrade_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t
	--WHERE t.name = 'topo_rein_sysdata_rsi' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'siidaomrade_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;


COMMENT ON TABLE topo_rein.siidaomrade_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.siidaomrade_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.siidaomrade_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.siidaomrade_flate.geo IS 'This holds the ref to topo_rein_sysdata_rsi.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_siidaomrade_flate_geo_relation_id_idx ON topo_rein.siidaomrade_flate(topo_rein.get_relation_id(omrade));

COMMENT ON INDEX topo_rein.topo_rein_siidaomrade_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';
SELECT CreateTopology('topo_rein_sysdata_rdr', 4258, 0.0000000001);

-- Workaround for PostGIS bug from Sandro, see
-- http://trac.osgeo.org/postgis/ticket/3359
-- Start edge_id from 2
-- Start face_id from 3
SELECT setval('topo_rein_sysdata_rdr.edge_data_edge_id_seq', 2, false),
       setval('topo_rein_sysdata_rdr.face_face_id_seq', 3, false);

-- give puclic access

GRANT USAGE ON SCHEMA topo_rein_sysdata_rdr TO public;

-- clear out old data added to make testing more easy:
-- DROP TABLE topo_rein.flyttlei_grense, topo_rein.flyttlei;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'flyttlei_grense', 'grense');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'flyttlei', 'omrade');

-- If yes then we need the table beitehage_grense
CREATE TABLE topo_rein.flyttlei_grense(
  -- a internal id will that can be changed when ver needed
  id serial PRIMARY KEY NOT NULL,
  -- Felles egenskaper for rein
  felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL,
  -- Reffers to the user that is logged in.
  saksbehandler varchar
);
-- add a topogeometry column to get a ref to the borders
SELECT topology.AddTopoGeometryColumn(
  'topo_rein_sysdata_rdr', 'topo_rein', 'flyttlei_grense', 'grense', 'LINESTRING'
) AS new_layer_id;

-- rename to flate
CREATE TABLE topo_rein.flyttlei_flate(
  -- an internal id can be changed whenever needed
  -- may be used by the update client when reffering to a certain row when we update
  id SERIAL PRIMARY KEY NOT NULL,

  -- column område is added later and may be renamed to geo

  -- Definition: indicates which reindeer pasture district uses the pasture area
  reinbeitebruker_id VARCHAR(3) CHECK (reinbeitebruker_id IN (
    'XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC',
    'ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG',
    'XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT',
    'YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS',
    'XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK',
    'WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA',
    'YQB','YQC','ZZ','RR','ZQA'
  )),
  reinbeitebruker_id2 VARCHAR(3) CHECK (reinbeitebruker_id2 IN (
    'XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC',
    'ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG',
    'XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT',
    'YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS',
    'XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK',
    'WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA',
    'YQB','YQC','ZZ','RR','ZQA'
  )),
  reinbeitebruker_id3 VARCHAR(3) CHECK (reinbeitebruker_id3 IN (
    'XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC',
    'ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG',
    'XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT',
    'YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS',
    'XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK',
    'WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA',
    'YQB','YQC','ZZ','RR','ZQA'
  )),

  -- Since in sosi we can have multiple reinbeitebruker_id, this list contains
  -- the origninal list from the sosi file
  -- The format is a simple XI,ZA,ZF, but we could also have used an array (text[]),
  -- but since we are not sure about how this field is used
  -- we use a simple comma separated text for now
  -- alle_reinbeitebr_id VARCHAR NOT NULL DEFAULT '',

  -- This is flag used indicate the status of this record.
  -- -1: Avvist
  --  0: Ukjent
  --  1: Kvalitetssikret
  -- 11: Kvalitetssikret (automatisk godkjent)
  -- 10: Ikke kvalitetssikret
  status INT NOT NULL DEFAULT 0,

  -- contains common attribute for rein
  felles_egenskaper topo_rein.sosi_felles_egenskaper,

  -- Refers to the user that is logged in.
  saksbehandler VARCHAR,

  -- This is used by the user to indicate deleted objects
  -- 0 menas that the object exists
  -- 1 menas that the user has chosen to delete the object
  slette_status_kode SMALLINT NOT NULL DEFAULT 0 CHECK (slette_status_kode IN (0, 1)),

  -- added because of performance, used by wms and sp on
  -- update in the same transaction as the topo objekt
  simple_geo geometry(MultiPolygon, 4258)
);

-- add a topogeometry column that is a ref to polygpn surface:
SELECT topology.AddTopoGeometryColumn(
  'topo_rein_sysdata_rdr', 'topo_rein', 'flyttlei_flate', 'omrade', 'POLYGON'
) AS new_layer_id;

COMMENT ON TABLE topo_rein.flyttlei_flate IS '
  Contains attributtes for rein and ref. to topo surface data.
  For more info see http://www.statkart.no/Documents/Standard/SOSI kap3
  Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf
';
COMMENT ON COLUMN topo_rein.flyttlei_flate.id IS 'Unique identifier of a surface';
COMMENT ON COLUMN topo_rein.flyttlei_flate.felles_egenskaper IS '
  Sosi common meta attribute part of kvalitet TODO create user defined type?
';

-- create function basded index to get performance
CREATE INDEX topo_rein_flyttlei_geo_relation_id_idx ON topo_rein.flyttlei_flate(
  topo_rein.get_relation_id(omrade)
);

COMMENT ON INDEX topo_rein.topo_rein_flyttlei_geo_relation_id_idx IS '
  A function based index to faster find topo rows in the relation table
';
-- DROP VIEW topo_rein.arstidsbeite_host_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.arstidsbeite_host_flate_v 
AS
select 
id,
--((al.felles_egenskaper).kvalitet).maalemetode,
--((al.felles_egenskaper).kvalitet).noyaktighet,
--((al.felles_egenskaper).kvalitet).synbarhet,
--(al.felles_egenskaper).verifiseringsdato, 
--(al.felles_egenskaper).opphav, 
--(al.felles_egenskaper).informasjon::varchar as informasjon, 
reindrift_sesongomrade_kode,
omrade::geometry(MultiPolygon,4258) as geo 
from topo_rein.arstidsbeite_host_flate al;

-- DROP VIEW IF EXISTS topo_rein.arstidsbeite_host_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.arstidsbeite_host_topojson_flate_v 
AS
select 
id,
reindrift_sesongomrade_kode,
reinbeitebruker_id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato", 
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav", 
omrade ,
alle_reinbeitebr_id, 
status,
slette_status_kode,
CASE 
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = '*'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	-- a user have explicit access to selected table
	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = 'topo_rein.arstidsbeite_host_flate'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	WHEN  reinbeitebruker_id is null
	THEN true
	
	ELSE false 
END AS "editable"
from topo_rein.arstidsbeite_host_flate al;

--select * from topo_rein.arstidsbeite_host_topojson_flate_v-- DROP VIEW IF EXISTS topo_rein.arstidsbeite_hostvinter_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.arstidsbeite_hostvinter_topojson_flate_v 
AS
select 
id,
reindrift_sesongomrade_kode,
reinbeitebruker_id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato", 
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav", 
omrade,
alle_reinbeitebr_id, 
status,
slette_status_kode,
CASE 
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = '*'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	-- a user have explicit access to selected table
	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = 'topo_rein.arstidsbeite_hostvinter_flate'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true
	
	WHEN  reinbeitebruker_id is null
	THEN true
	
	ELSE false 
END AS "editable"
from topo_rein.arstidsbeite_hostvinter_flate al;

--select * from topo_rein.arstidsbeite_hostvinter_topojson_flate_v-- DROP VIEW topo_rein.arstidsbeite_sommer_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.arstidsbeite_sommer_flate_v 
AS
select 
id,
--((al.felles_egenskaper).kvalitet).maalemetode,
--((al.felles_egenskaper).kvalitet).noyaktighet,
--((al.felles_egenskaper).kvalitet).synbarhet,
--(al.felles_egenskaper).verifiseringsdato, 
--(al.felles_egenskaper).opphav, 
--(al.felles_egenskaper).informasjon::varchar as informasjon, 
reindrift_sesongomrade_kode,
omrade::geometry(MultiPolygon,4258) as geo 
from topo_rein.arstidsbeite_sommer_flate al;

-- DROP VIEW IF EXISTS topo_rein.arstidsbeite_sommer_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.arstidsbeite_sommer_topojson_flate_v 
AS
select 
id,
reindrift_sesongomrade_kode,
reinbeitebruker_id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato", 
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav", 
omrade,
alle_reinbeitebr_id, 
status,
slette_status_kode,
CASE 
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = '*'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	-- a user have explicit access to selected table
	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = 'topo_rein.arstidsbeite_sommer_flate'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	WHEN  reinbeitebruker_id is null
	THEN true
	
	ELSE false 
END AS "editable" 
from topo_rein.arstidsbeite_sommer_flate al;

--select * from topo_rein.arstidsbeite_sommer_topojson_flate_v-- DROP VIEW topo_rein.arstidsbeite_var_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.arstidsbeite_var_flate_v 
AS
select 
id,
--((al.felles_egenskaper).kvalitet).maalemetode,
--((al.felles_egenskaper).kvalitet).noyaktighet,
--((al.felles_egenskaper).kvalitet).synbarhet,
--(al.felles_egenskaper).verifiseringsdato, 
--(al.felles_egenskaper).opphav, 
--(al.felles_egenskaper).informasjon::varchar as informasjon, 
reindrift_sesongomrade_kode,
omrade::geometry(MultiPolygon,4258) as geo 
from topo_rein.arstidsbeite_var_flate al;

DROP VIEW IF EXISTS topo_rein.arstidsbeite_var_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.arstidsbeite_var_topojson_flate_v 
AS
select 
id,
reindrift_sesongomrade_kode,
reinbeitebruker_id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato", 
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav", 
omrade,
alle_reinbeitebr_id, 
status,
slette_status_kode,
CASE 
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = '*'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	-- a user have explicit access to selected table
	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = 'topo_rein.arstidsbeite_var_flate'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	WHEN  reinbeitebruker_id is null
	THEN true

	ELSE false 
END AS "editable"
from topo_rein.arstidsbeite_var_flate al;

--select * from topo_rein.arstidsbeite_var_topojson_flate_v-- DROP VIEW IF EXISTS topo_rein.arstidsbeite_vinter_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.arstidsbeite_vinter_topojson_flate_v 
AS
select 
id,
reindrift_sesongomrade_kode,
reinbeitebruker_id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato", 
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav", 
omrade,
alle_reinbeitebr_id, 
status,
slette_status_kode,
CASE 
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = '*'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	-- a user have explicit access to selected table
	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = 'topo_rein.arstidsbeite_vinter_flate'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	WHEN  reinbeitebruker_id is null
	THEN true
	
	ELSE false 
END AS "editable"
from topo_rein.arstidsbeite_vinter_flate al;

--select * from topo_rein.arstidsbeite_vinter_topojson_flate_v-- DROP VIEW IF EXISTS topo_rein.avtaleomrade_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.avtaleomrade_topojson_flate_v
AS
select
id,
avtaletype,
reinbeitebruker_id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato",
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav",
omrade,
status,
slette_status_kode,
CASE
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

	WHEN reinbeitebruker_id =
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = '*'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	WHEN  reinbeitebruker_id is null
	THEN true

	ELSE false
END AS "editable"
from topo_rein.avtaleomrade_flate al;

--select * from topo_rein.avtaleomrade_topojson_flate_v
-- DROP VIEW IF EXISTS topo_rein.beitehage_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.beitehage_topojson_flate_v 
AS
select 
id,
reindriftsanleggstype,
reinbeitebruker_id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato", 
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav", 
omrade,
alle_reinbeitebr_id, 
status,
slette_status_kode,
CASE 
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = '*'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	-- a user have explicit access to selected table
	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = 'topo_rein.beitehage_flate'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true


	WHEN  reinbeitebruker_id is null
	THEN true
	
	ELSE false 
END AS "editable"
from topo_rein.beitehage_flate al;

--select * from topo_rein.beitehage_topojson_flate_v-- DROP VIEW IF EXISTS topo_rein.ekspropriasjonsomrade_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.ekspropriasjonsomrade_topojson_flate_v
AS
select
id,
-- reindriftsanleggstype,
reinbeitebruker_id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato",
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav",
omrade,
kongeligresolusjon,
status,
slette_status_kode,
CASE
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

	WHEN reinbeitebruker_id =
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = '*'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	WHEN  reinbeitebruker_id is null
	THEN true

	ELSE false
END AS "editable"
from topo_rein.ekspropriasjonsomrade_flate al;

--select * from topo_rein.ekspropriasjonsomrade_topojson_flate_v
-- DROP VIEW IF EXISTS topo_rein.flyttlei_topojson_flate_v cascade ;
CREATE OR REPLACE VIEW topo_rein.flyttlei_topojson_flate_v AS SELECT
  id,
  reinbeitebruker_id,
  reinbeitebruker_id2,
  reinbeitebruker_id3,
  (al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato",
  (al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
  (al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
  (al.felles_egenskaper).opphav AS "fellesegenskaper.opphav",
  omrade,
  -- alle_reinbeitebr_id,
  status,
  slette_status_kode,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM topo_rein.rls_role_mapping rl
      WHERE rl.session_id = current_setting('pgtopo_update.session_id')
      AND rl.edit_all = true
    ) THEN true

    WHEN reinbeitebruker_id = ANY (
      SELECT  column_value FROM topo_rein.rls_role_mapping rl
      WHERE rl.session_id = current_setting('pgtopo_update.session_id')
      AND rl.table_name = '*'
      AND rl.column_name = 'reinbeitebruker_id'
    ) THEN true

      -- a user have explicit access to selected table
    WHEN reinbeitebruker_id = ANY (
      SELECT  column_value FROM topo_rein.rls_role_mapping rl
      WHERE rl.session_id = current_setting('pgtopo_update.session_id')
      AND rl.table_name = 'topo_rein.flyttlei_flate'
      AND rl.column_name = 'reinbeitebruker_id'
    ) THEN true

    WHEN  reinbeitebruker_id is null
    THEN true

    ELSE false
  END AS "editable"
FROM topo_rein.flyttlei_flate al;
-- DROP VIEW IF EXISTS topo_rein.konsesjonsomrade_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.konsesjonsomrade_topojson_flate_v
AS
select
id,
reinbeitebruker_id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato",
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav",
omrade,
status,
slette_status_kode,
CASE
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

	WHEN reinbeitebruker_id =
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = '*'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	WHEN  reinbeitebruker_id is null
	THEN true

	ELSE false
END AS "editable"
from topo_rein.konsesjonsomrade_flate al;

--select * from topo_rein.konsesjonsomrade_topojson_flate_v
-- DROP VIEW IF EXISTS topo_rein.konvensjonsomrade_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.konvensjonsomrade_topojson_flate_v
AS
select
id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato",
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav",
omrade,
status,
slette_status_kode,
CASE
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

  WHEN NOT EXISTS (
    SELECT * FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='konvensjonsomrade_flate' AND COLUMN_NAME='reinbeitebruker_id'
  )
  THEN true

	ELSE false
END AS "editable"
from topo_rein.konvensjonsomrade_flate al;

--select * from topo_rein.konvensjonsomrade_topojson_flate_v
-- DROP VIEW IF EXISTS topo_rein.oppsamlingsomrade_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.oppsamlingsomrade_topojson_flate_v
AS
select
id,
reinbeitebruker_id,
reinbeitebruker_id2,
reinbeitebruker_id3,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato",
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav",
omrade,
-- alle_reinbeitebr_id,
status,
slette_status_kode,
CASE
  WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
  WHERE rl.session_id = current_setting('pgtopo_update.session_id')
  AND rl.edit_all = true)
  THEN true

  WHEN reinbeitebruker_id =
  ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
  WHERE rl.session_id = current_setting('pgtopo_update.session_id')
  AND rl.table_name = '*'
  AND rl.column_name = 'reinbeitebruker_id')
  THEN true

    -- a user have explicit access to selected table
  WHEN reinbeitebruker_id =
  ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
  WHERE rl.session_id = current_setting('pgtopo_update.session_id')
  AND rl.table_name = 'topo_rein.oppsamlingsomrade_flate'
  AND rl.column_name = 'reinbeitebruker_id')
  THEN true

  WHEN  reinbeitebruker_id is null
  THEN true

  ELSE false
END AS "editable"
FROM topo_rein.oppsamlingsomrade_flate al;
DROP VIEW IF EXISTS topo_rein.rein_trekklei_topojson_linje_v cascade ;


CREATE OR REPLACE VIEW topo_rein.rein_trekklei_topojson_linje_v 
AS
select 
id,
reinbeitebruker_id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato", 
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav", 
((al.felles_egenskaper).kvalitet).maalemetode AS "fellesegenskaper.kvalitet.maalemetode",
((al.felles_egenskaper).kvalitet).noyaktighet AS "fellesegenskaper.kvalitet.noyaktighet",
linje,
alle_reinbeitebr_id, 
status,
slette_status_kode,
CASE 
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = '*'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true
	
	-- a user have explicit access to selected table
	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = 'topo_rein.rein_trekklei_linje'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true
	
	WHEN  reinbeitebruker_id is null
	THEN true

	ELSE false 
END AS "editable"
from topo_rein.rein_trekklei_linje al;

-- select * from topo_rein.rein_trekklei_topojson_linje_v ;


-- DROP VIEW IF EXISTS topo_rein.reinbeitedistrikt_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.reinbeitedistrikt_topojson_flate_v
AS
select
id,
-- reindriftsanleggstype,
reinbeitebruker_id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato",
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav",
omrade,
alle_reinbeitebr_id,
navn,
status,
slette_status_kode,
CASE
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

	WHEN reinbeitebruker_id =
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = '*'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	WHEN  reinbeitebruker_id is null
	THEN true

	ELSE false
END AS "editable"
from topo_rein.reinbeitedistrikt_flate al;

--select * from topo_rein.reinbeitedistrikt_topojson_flate_v
-- DROP VIEW IF EXISTS topo_rein.reinbeiteomrade_topojson_flate_v cascade ;

CREATE OR REPLACE VIEW topo_rein.reinbeiteomrade_topojson_flate_v
AS
select
id,
reinbeiteområde_id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato",
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav",
omrade,
status,
slette_status_kode,
CASE
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

	-- WHEN reinbeitebruker_id =
	-- ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	-- WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	-- AND rl.table_name = '*'
	-- AND rl.column_name = 'reinbeitebruker_id')
	-- THEN true
  --
	-- WHEN reinbeitebruker_id is null
	-- THEN true

  WHEN NOT EXISTS (
    SELECT * FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='reinbeiteomrade_flate' AND COLUMN_NAME='reinbeitebruker_id'
  )
  THEN true

	ELSE false
END AS "editable"
from topo_rein.reinbeiteomrade_flate al;

--select * from topo_rein.reinbeiteomrade_topojson_flate_v
DROP VIEW IF EXISTS topo_rein.reindrift_anlegg_topojson_linje_v cascade ;

CREATE OR REPLACE VIEW topo_rein.reindrift_anlegg_topojson_linje_v
AS
select
id,
reinbeitebruker_id,
reinbeitebruker_id2,
reinbeitebruker_id3,
-- reindriftsanleggstype,
-- anleggstype, -- does not work, since PSQL writing from java does not handle vector in json
-- anleggstype[0] AS anleggstype0, -- does not work, it reads, but not writes, through view
anleggstype,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato",
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav",
((al.felles_egenskaper).kvalitet).maalemetode AS "fellesegenskaper.maalemetode",
((al.felles_egenskaper).kvalitet).noyaktighet AS "fellesegenskaper.noyaktighet",
linje,
-- alle_reinbeitebr_id,
status,
slette_status_kode,
CASE
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

	WHEN reinbeitebruker_id =
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = '*'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	-- a user have explicit access to selected table
	WHEN
	reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = 'topo_rein.reindrift_anlegg_linje'
	AND rl.column_name = 'reinbeitebruker_id')
	AND
	anleggstype::varchar  = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = 'topo_rein.reindrift_anlegg_linje'
	AND rl.column_name = 'anleggstype')
	THEN true

	WHEN
	reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = 'topo_rein.reindrift_anlegg_linje'
	AND rl.column_name = 'reinbeitebruker_id')
	AND
	(
	anleggstype is null
	OR 
	anleggstype::varchar  = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = 'topo_rein.reindrift_anlegg_linje'
	AND rl.column_name = 'anleggstype')
	)
	THEN true

	WHEN  reinbeitebruker_id is null
	THEN true

	ELSE false
END AS "editable"
from topo_rein.reindrift_anlegg_linje al;

-- select * from topo_rein.reindrift_anlegg_topojson_linje_v ;
DROP VIEW IF EXISTS topo_rein.reindrift_anlegg_topojson_punkt_v cascade ;


CREATE OR REPLACE VIEW topo_rein.reindrift_anlegg_topojson_punkt_v
AS
select
id,
reinbeitebruker_id,
reinbeitebruker_id2,
reinbeitebruker_id3,
-- reindriftsanleggstype,
-- anleggstype, -- does not work, since PSQL writing from java does not handle vector in json
-- anleggstype[0] AS anleggstype0, -- does not work, it reads, but not writes, through view
anleggstype,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato",
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav",
((al.felles_egenskaper).kvalitet).maalemetode AS "fellesegenskaper.kvalitet.maalemetode",
((al.felles_egenskaper).kvalitet).noyaktighet AS "fellesegenskaper.kvalitet.noyaktighet",
punkt,
-- alle_reinbeitebr_id,
status,
slette_status_kode,
CASE
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

	WHEN reinbeitebruker_id =
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = '*'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	-- a user have explicit access to selected table
	WHEN reinbeitebruker_id = 
	ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.table_name = 'topo_rein.reindrift_anlegg_punkt'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	
	WHEN  reinbeitebruker_id is null
	THEN true

	ELSE false
END AS "editable"
from topo_rein.reindrift_anlegg_punkt al;


--select * from topo_rein.reindrift_anlegg_topojson_punkt_v ;
-- DROP VIEW IF EXISTS topo_rein.restriksjonsomrade_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.restriksjonsomrade_topojson_flate_v
AS
select
id,
dom_instans,
dom_dato,
dom_i_kraft,
informasjon,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato",
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav",
omrade,
status,
slette_status_kode,
CASE
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

  WHEN NOT EXISTS (
    SELECT * FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='restriksjonsomrade_flate' AND COLUMN_NAME='reinbeitebruker_id'
  )
  THEN true

	ELSE false
END AS "editable"
from topo_rein.restriksjonsomrade_flate al;

--select * from topo_rein.restriksjonsomrade_topojson_flate_v
CREATE OR REPLACE VIEW topo_rein.restriksjonsomrade_topojson_linje_v
AS
select
id,
dom_instans,
dom_dato,
dom_i_kraft,
informasjon,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato",
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav",
linje,
-- linje::geometry(MultiLineString,4258) as geo,
status,
slette_status_kode,
CASE
  WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
  WHERE rl.session_id = current_setting('pgtopo_update.session_id')
  AND rl.edit_all = true)
  THEN true

  WHEN NOT EXISTS (
    SELECT * FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='restriksjonsomrade_grense' AND COLUMN_NAME='reinbeitebruker_id'
  )
  THEN true

  ELSE false
END AS "editable"
from topo_rein.restriksjonsomrade_linje al;
-- DROP VIEW IF EXISTS topo_rein.siidaomrade_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.siidaomrade_topojson_flate_v
AS
select
id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato",
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav",
omrade,
navn,
status,
slette_status_kode,
CASE
	WHEN EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
	WHERE rl.session_id = current_setting('pgtopo_update.session_id')
	AND rl.edit_all = true)
	THEN true

  WHEN NOT EXISTS (
    SELECT * FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='siidaomrade_flate' AND COLUMN_NAME='reinbeitebruker_id'
  )
  THEN true

	ELSE false
END AS "editable"
from topo_rein.siidaomrade_flate al;

--select * from topo_rein.siidaomrade_topojson_flate_v

-- create surface view
DO
$body$
DECLARE
tbl_name text;
schema_name text = 'topo_rein';
topo_tables text[];
cmd_text text;
BEGIN
foreach tbl_name IN array string_to_array(
  'arstidsbeite_sommer_flate,arstidsbeite_host_flate,arstidsbeite_hostvinter_flate,arstidsbeite_vinter_flate,arstidsbeite_var_flate,beitehage_flate,oppsamlingsomrade_flate,reindrift_anlegg_linje,rein_trekklei_linje,reindrift_anlegg_punkt,flyttlei_flate',
  ','
)
loop
	cmd_text = format('-- add row level security
	ALTER TABLE %3$s ENABLE ROW LEVEL SECURITY;

	-- Drop if exits
	DROP POLICY IF EXISTS %2$s_select_policy ON %3$s;

	-- Give all users select rights , Is it another way to do this
	CREATE POLICY %2$s_select_policy ON %3$s FOR SELECT  USING(true);

	-- Drop if exits
	DROP POLICY IF EXISTS %2$s_update_policy ON %3$s;

	-- Handle update
	CREATE POLICY %2$s_update_policy ON %3$s
	FOR ALL
	USING
	(
		-- a user that edit anything
		EXISTS (SELECT 1 FROM %8$s rl
		WHERE rl.session_id = current_setting(%4$L)
		AND rl.edit_all = true)
		OR

		reinbeitebruker_id is null

		OR
		-- a user that has access to certain areas
		reinbeitebruker_id = ANY((SELECT  column_value FROM %8$s rl
		WHERE rl.session_id = current_setting(%4$L)
		AND rl.table_name = %6$L
		AND rl.column_name = %5$L))

		-- a user have explicit access to selected table
		OR
		reinbeitebruker_id = ANY((SELECT  column_value FROM %8$s rl
		WHERE rl.session_id = current_setting(%4$L)
		AND rl.table_name = %3$L
		AND rl.column_name = %5$L))

		-- handles insert new lines on surfaces
		OR
		current_setting(%7$L) = %9$L
	)
	WITH CHECK
	(
		-- a user that edit anything
		EXISTS (SELECT 1 FROM %8$s rl
		WHERE rl.session_id = current_setting(%4$L)
		AND rl.edit_all = true)
		OR

		reinbeitebruker_id is null

		OR
		-- a user that has access to certain areas
		reinbeitebruker_id = ANY((SELECT  column_value FROM %8$s rl
		WHERE rl.session_id = current_setting(%4$L)
		AND rl.table_name = %6$L
		AND rl.column_name = %5$L))

		-- a user have explicit access to selected table
		OR
		reinbeitebruker_id = ANY((SELECT  column_value FROM %8$s rl
		WHERE rl.session_id = current_setting(%4$L)
		AND rl.table_name = %3$L
		AND rl.column_name = %5$L))

		-- handles insert new lines on surfaces
		OR
		current_setting(%7$L) = %9$L
	)
;
',
	tbl_name,
	schema_name||'_'||tbl_name,
	schema_name||'.'||tbl_name,
	'pgtopo_update.session_id',
	'reinbeitebruker_id',
	'*',
	'pgtopo_update.draw_line_opr',
	'topo_rein.rls_role_mapping',
	1
	);

	RAISE NOTICE 'Set rowlevel security for %', schema_name||'.'||tbl_name;
	--RAISE NOTICE 'cmd_text %', cmd_text;

	execute cmd_text;


END loop;
END
$body$;


/**
 * Creates a "logging" schema with an "history" table where are stored records in JSON format
 *
 * Requires PostgreSQL >= 9.3 since data is stored in JSON format
 *
 * Info http://www.cybertec.at/2013/12/tracking-changes-in-postgresql/ and  https://gist.github.com/cristianp6/29ce1c942448e95c2f95
 */



/* Create the table in which to store changes in tables logs */
--drop TABLE topo_rein.data_update_log cascade;

CREATE TABLE IF NOT EXISTS topo_rein.data_update_log (
    id              serial primary key not null,
    action_time     timestamptz not null DEFAULT CURRENT_TIMESTAMP,
    schema_name     text not null,
    table_name      text not null,
    row_id 			int not null, -- used to find row for the table in the schema name and table name
    reinbeitebruker_id character varying(3), -- used to select rows for logged in saksbehandler to verify

	-- This is flag used indicate the status of this record. The rules for how to use this flag is not decided yet.
	-- Here is a list of the current states.
	-- -1 recjected by user
	-- 0: Ukjent (uknown)
	-- 1: Godkjent
	-- 10: Endret
    status 			int,
    saksbehandler   text,
    operation       text not null,
    json_row_data   json null,
    change_confirmed_by_admin boolean NOT null default false,

    -- this is used when a object is split in two or more parts
    -- this object will not bi visiable in any lists any more
    removed_by_splitt_operation boolean NOT null default false


);


/* Create view need by the update function, this view is just made to get a generic way of naming */
--CREATE OR REPLACE VIEW topo_rein.arstidsbeite_sommer_flate_json_update_log as select v1.*,v2.saksbehandler
--from topo_rein.arstidsbeite_sommer_topojson_flate_v v1, topo_rein.arstidsbeite_sommer_flate v2 where v1.id = v2.id;

-- create surface view
DO
$body$
DECLARE
tbl_name text;
topo_tables text[];
BEGIN
foreach tbl_name IN array string_to_array('arstidsbeite_sommer,arstidsbeite_host,arstidsbeite_hostvinter,arstidsbeite_vinter,arstidsbeite_var,beitehage,oppsamlingsomrade,flyttlei',',')
loop
	EXECUTE format('DROP VIEW IF EXISTS %1$s_flate_json_update_log; CREATE OR REPLACE VIEW %1$s_flate_json_update_log as select v1.*,v2.saksbehandler from %1$s_topojson_flate_v v1, %1$s_flate v2 where v1.id = v2.id', 'topo_rein.'||tbl_name);
END loop;
END
$body$;

-- create line view
DO
$body$
DECLARE
tbl_name text;
topo_tables text[];
BEGIN
foreach tbl_name IN array string_to_array('reindrift_anlegg,rein_trekklei',',')
loop
	EXECUTE format('DROP VIEW IF EXISTS %1$s_linje_json_update_log; CREATE OR REPLACE VIEW %1$s_linje_json_update_log as select v1.*,v2.saksbehandler from %1$s_topojson_linje_v v1, %1$s_linje v2 where v1.id = v2.id', 'topo_rein.'||tbl_name);
END loop;
END
$body$;

-- create point view
DO
$body$
DECLARE
tbl_name text;
topo_tables text[];
BEGIN
foreach tbl_name IN array string_to_array('reindrift_anlegg',',')
loop
	EXECUTE format('DROP VIEW IF EXISTS %1$s_punkt_json_update_log; CREATE OR REPLACE VIEW %1$s_punkt_json_update_log as select v1.*,v2.saksbehandler from %1$s_topojson_punkt_v v1, %1$s_punkt v2 where v1.id = v2.id', 'topo_rein.'||tbl_name);
END loop;
END
$body$;



-- Clean up old function name if exists
DROP FUNCTION IF EXISTS topo_rein.table_change_trigger_insert_after() cascade;
DROP FUNCTION IF EXISTS topo_rein.change_trigger_update_before() cascade;
DROP FUNCTION IF EXISTS topo_rein.change_trigger_update_after() cascade;
DROP FUNCTION IF EXISTS topo_rein.change_trigger_delete_after() cascade;
DROP FUNCTION IF EXISTS topo_rein.change_i_trigger_insert_after() cascade;
DROP FUNCTION IF EXISTS topo_rein.change_trigger_insert_after() cascade;
DROP FUNCTION IF EXISTS topo_rein.change_iu_trigger_insert_after() cascade;



/* Create a function that convert to json if possible */
DROP FUNCTION IF EXISTS topo_rein.data_update_log_get_json_row_data(query text, srid_out int, maxdecimaldigits int, simplify_patteren int) cascade;
DROP FUNCTION IF EXISTS topo_rein.data_update_log_get_json_row_data(query text, srid_out int, maxdecimaldigits int, simplify_patteren int, only_valid boolean) cascade;

/* Create a function that convert to json if possible */
CREATE OR REPLACE FUNCTION topo_rein.data_update_log_get_json_row_data(query text, srid_out int, maxdecimaldigits int, simplify_patteren int)
RETURNS text AS
$$
DECLARE
  json_result text;
BEGIN
  BEGIN
   json_result := topo_rein.query_to_topojson(query, srid_out, maxdecimaldigits, simplify_patteren)::json;
  EXCEPTION WHEN OTHERS THEN
  	RAISE NOTICE 'Failed to ake json for %', query;

  END;
  RETURN json_result;

END;
$$ LANGUAGE 'plpgsql' VOLATILE;


/*
 * Create the functions used for trigger insert after, this is used for lines and surfaces
 * TODO find a better wat to solve this
 */
CREATE OR REPLACE FUNCTION topo_rein.change_trigger_insert_after() RETURNS trigger AS $$
	DECLARE
	is_ready_stage boolean = false;
	is_accpeted boolean = false;
    BEGIN
        IF (TG_OP = 'INSERT') THEN


            -- is_ready_stage := topo_rein.is_ready_stage('arstidsbeite_var_flate',NEW);
            -- Check if object in ready stage
            -- TODO find way to move this procdure
	        IF (TG_RELNAME IN ('arstidsbeite_sommer_flate','arstidsbeite_host_flate','arstidsbeite_hostvinter_flate','arstidsbeite_vinter_flate','arstidsbeite_var_flate')) THEN
	        	IF (
	        	NEW.reinbeitebruker_id is not null and
	        	NEW.reindrift_sesongomrade_kode is not null
	        	) THEN
	        		is_ready_stage := true;
	        	END IF;
	        ELSIF (TG_RELNAME IN ('reindrift_anlegg_linje','reindrift_anlegg_punkt')) THEN
	        	IF (
	        	NEW.reinbeitebruker_id is not null and
	        	NEW.anleggstype is not null
	        	) THEN
	        		is_ready_stage := true;
	        	END IF;
	        ELSIF (TG_RELNAME IN ('beitehage_flate')) THEN
	        	IF (
	        	NEW.reinbeitebruker_id is not null and
	        	NEW.reindriftsanleggstype is not null
	        	) THEN
	        		is_ready_stage := true;
	        	END IF;
	        ELSIF (TG_RELNAME IN ('oppsamlingsomrade_flate','flyttlei_flate')) THEN
	        	IF (
	        	NEW.reinbeitebruker_id is not null
	        	) THEN
	        		is_ready_stage := true;
	        	END IF;
	        END IF;

	        IF (NEW.status IN (1)) THEN
	        	is_accpeted := true;
	        END IF;

	        IF (is_accpeted=false) THEN
	           INSERT INTO topo_rein.data_update_log (table_name, schema_name, saksbehandler, row_id, status, reinbeitebruker_id, operation, json_row_data)
                VALUES (TG_RELNAME, TG_TABLE_SCHEMA, NEW.saksbehandler, NEW.id, NEW.status, NEW.reinbeitebruker_id, TG_OP||'_BEFORE_VALID',
                '{}'
               );
	       	END IF;

	        IF (is_ready_stage=true and is_accpeted=false) THEN
	       		-- We are not in init stage
            	INSERT INTO topo_rein.data_update_log (table_name, schema_name, saksbehandler, row_id, status, reinbeitebruker_id, operation, json_row_data)
                VALUES (TG_RELNAME, TG_TABLE_SCHEMA, NEW.saksbehandler, NEW.id, NEW.status, NEW.reinbeitebruker_id, TG_OP||'_AFTER_VALID',
                topo_rein.data_update_log_get_json_row_data('select distinct a.* from '||TG_TABLE_SCHEMA||'.'||TG_RELNAME||'_json_update_log a where a.id = '||NEW.id,4258,8,0)::json
                );
	       	END IF;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE 'plpgsql' SECURITY DEFINER;

/* Create the functions used for trigger update before  */
CREATE OR REPLACE FUNCTION topo_rein.change_trigger_update_before() RETURNS trigger AS $$
	DECLARE
	is_ready_stage boolean = false;
	is_accpeted boolean = false;
    BEGIN
	    -- no map data before they or ok
		IF (TG_OP = 'UPDATE') THEN
            -- is_ready_stage := topo_rein.is_ready_stage('arstidsbeite_var_flate',OLD);
            -- Check if object in ready stage
            -- TODO find way to move this procdure
	        IF (TG_RELNAME IN ('arstidsbeite_sommer_flate','arstidsbeite_host_flate','arstidsbeite_hostvinter_flate','arstidsbeite_vinter_flate','arstidsbeite_var_flate')) THEN
	        	IF (
	        	OLD.reinbeitebruker_id is not null and
	        	OLD.reindrift_sesongomrade_kode is not null
	        	) THEN
	        		is_ready_stage := true;
	        	END IF;
	        ELSIF (TG_RELNAME IN ('reindrift_anlegg_linje','reindrift_anlegg_punkt')) THEN
	        	IF (
	        	OLD.reinbeitebruker_id is not null and
	        	OLD.anleggstype is not null
	        	) THEN
	        		is_ready_stage := true;
	        	END IF;
	        ELSIF (TG_RELNAME IN ('beitehage_flate')) THEN
	        	IF (
	        	OLD.reinbeitebruker_id is not null and
	        	OLD.reindriftsanleggstype is not null
	        	) THEN
	        		is_ready_stage := true;
	        	END IF;
	        ELSIF (TG_RELNAME IN ('oppsamlingsomrade_flate','flyttlei_flate')) THEN
	        	IF (
	        	OLD.reinbeitebruker_id is not null
	        	) THEN
	        		is_ready_stage := true;
	        	END IF;
	        END IF;

	        IF (NEW.status IN (1)) THEN
	        	is_accpeted := true;
	        END IF;

	        IF (is_ready_stage=true and is_accpeted=false) THEN
           		INSERT INTO topo_rein.data_update_log (table_name, schema_name, saksbehandler, row_id, status, reinbeitebruker_id, operation, json_row_data)
                VALUES (TG_RELNAME, TG_TABLE_SCHEMA, OLD.saksbehandler, OLD.id, OLD.status, OLD.reinbeitebruker_id, TG_OP||'_BEFORE',
                topo_rein.data_update_log_get_json_row_data('select distinct a.* from '||TG_TABLE_SCHEMA||'.'||TG_RELNAME||'_json_update_log a where a.id = '||OLD.id,4258,8,0)::json
                );
	       	END IF;

        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE 'plpgsql' SECURITY DEFINER;

/* Create the functions used for trigger update after  */
CREATE OR REPLACE FUNCTION topo_rein.change_trigger_update_after() RETURNS trigger AS $$
	DECLARE
	is_ready_stage boolean = false;
	is_accpeted boolean = false;
    BEGIN
		IF (TG_OP = 'UPDATE') THEN
            -- is_ready_stage := topo_rein.is_ready_stage('arstidsbeite_var_flate',NEW);
            -- Check if object in ready stage
            -- TODO find way to move this procdure
	        IF (TG_RELNAME IN ('arstidsbeite_sommer_flate','arstidsbeite_host_flate','arstidsbeite_hostvinter_flate','arstidsbeite_vinter_flate','arstidsbeite_var_flate')) THEN
	        	IF (
	        	NEW.reinbeitebruker_id is not null and
	        	NEW.reindrift_sesongomrade_kode is not null
	        	) THEN
	        		is_ready_stage := true;
	        	END IF;
	        ELSIF (TG_RELNAME IN ('reindrift_anlegg_linje','reindrift_anlegg_punkt')) THEN
	        	IF (
	        	NEW.reinbeitebruker_id is not null and
	        	NEW.anleggstype is not null
	        	) THEN
	        		is_ready_stage := true;
	        	END IF;
	        ELSIF (TG_RELNAME IN ('beitehage_flate')) THEN
	        	IF (
	        	NEW.reinbeitebruker_id is not null and
	        	NEW.reindriftsanleggstype is not null
	        	) THEN
	        		is_ready_stage := true;
	        	END IF;
	        ELSIF (TG_RELNAME IN ('oppsamlingsomrade_flate','flyttlei_flate')) THEN
	        	IF (
	        	NEW.reinbeitebruker_id is not null
	        	) THEN
	        		is_ready_stage := true;
	        	END IF;
	        END IF;

	        IF (NEW.status IN (1)) THEN
	        	is_accpeted := true;
	        END IF;

	        IF (is_ready_stage=true and is_accpeted=false) THEN
           		-- clean up current after update, since we only need one after
				DELETE FROM topo_rein.data_update_log WHERE ROW_ID = NEW.id AND table_name = TG_RELNAME AND schema_name = TG_TABLE_SCHEMA AND operation = TG_OP||'_AFTER';

	            INSERT INTO topo_rein.data_update_log (table_name, schema_name, saksbehandler, row_id, status, reinbeitebruker_id, operation, json_row_data)
	                VALUES (TG_RELNAME, TG_TABLE_SCHEMA, NEW.saksbehandler, NEW.id, NEW.status, NEW.reinbeitebruker_id, TG_OP||'_AFTER',
	                topo_rein.data_update_log_get_json_row_data('select distinct a.* from '||TG_TABLE_SCHEMA||'.'||TG_RELNAME||'_json_update_log a where a.id = '||NEW.id,4258,8,0)::json
	                );
	       	END IF;

        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE 'plpgsql' SECURITY DEFINER;

/* Create the functions used for trigger delete after  */
CREATE OR REPLACE FUNCTION topo_rein.change_trigger_delete_after() RETURNS trigger AS $$
    BEGIN
		IF (TG_OP = 'DELETE') THEN
            INSERT INTO topo_rein.data_update_log (table_name, schema_name, saksbehandler, row_id, status, reinbeitebruker_id, operation, json_row_data)
                VALUES (TG_RELNAME, TG_TABLE_SCHEMA, OLD.saksbehandler, OLD.id, OLD.status, OLD.reinbeitebruker_id, TG_OP||'_AFTER',
                topo_rein.data_update_log_get_json_row_data('select distinct a.* from '||TG_TABLE_SCHEMA||'.'||TG_RELNAME||'_json_update_log a where a.id = '||OLD.id,4258,8,0)::json
                );
            UPDATE topo_rein.data_update_log set  removed_by_splitt_operation = true
            WHERE table_name = TG_RELNAME AND schema_name = TG_TABLE_SCHEMA AND row_id =  OLD.id;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE 'plpgsql' SECURITY DEFINER;

/* Create the triggers surfaces and lines */

DO
$body$
DECLARE
tbl_name text;
topo_tables text[];
BEGIN
foreach tbl_name IN array string_to_array('arstidsbeite_sommer_flate,arstidsbeite_host_flate,arstidsbeite_hostvinter_flate,arstidsbeite_vinter_flate,arstidsbeite_var_flate,beitehage_flate,oppsamlingsomrade_flate,reindrift_anlegg_linje,rein_trekklei_linje,reindrift_anlegg_punkt,flyttlei_flate',',')
loop

EXECUTE format('DROP TRIGGER IF EXISTS table_change_i_trigger_insert_after ON %1$s', 'topo_rein.'||tbl_name);
EXECUTE format('DROP TRIGGER IF EXISTS table_change_iu_trigger_insert_after ON %1$s', 'topo_rein.'||tbl_name);

EXECUTE format('DROP TRIGGER IF EXISTS table_change_trigger_insert_after ON %1$s;
     CREATE TRIGGER table_change_trigger_insert_after
     AFTER INSERT ON %1$s
     FOR EACH ROW EXECUTE PROCEDURE topo_rein.change_trigger_insert_after()', 'topo_rein.'||tbl_name);

EXECUTE format('DROP TRIGGER IF EXISTS table_change_trigger_update_before ON %1$s;
     CREATE TRIGGER table_change_trigger_update_before
     BEFORE UPDATE ON %1$s
     FOR EACH ROW EXECUTE PROCEDURE topo_rein.change_trigger_update_before()', 'topo_rein.'||tbl_name);

EXECUTE format('DROP TRIGGER IF EXISTS table_change_trigger_update_after ON %1$s;
     CREATE TRIGGER table_change_trigger_update_after
     AFTER UPDATE ON %1$s
     FOR EACH ROW EXECUTE PROCEDURE topo_rein.change_trigger_update_after()', 'topo_rein.'||tbl_name);

EXECUTE format('DROP TRIGGER IF EXISTS table_change_trigger_delete_after ON %1$s;
     CREATE TRIGGER table_change_trigger_delete_after
     AFTER DELETE ON %1$s
     FOR EACH ROW EXECUTE PROCEDURE topo_rein.change_trigger_delete_after()', 'topo_rein.'||tbl_name);

END loop;
END
$body$;



-- this function that used to select

-- Create view to show changes before and after for each single row


-- the problem we have is to differ from a object created from nothing or if it's created by a splitting a exting object.

-- if it's a new object it should show up in the list as new object, so the user can select to delete it

-- if it's splitting of a exting object it's should not show up in the list until it's changed

-- When we create a new object from nothing it's not narked is any way, but it will have an insert and update and a delete the same timestamp.

--DROP VIEW topo_rein.data_update_log_new_v;



CREATE OR REPLACE VIEW topo_rein.data_update_log_new_v AS (
select * from (
	select
	'READY'::text as data_row_state,
	g.schema_name,
	g.table_name,
	g.min_data_row_id_before as data_row_id,

	g.min_id_before as id_before,
	g.min_action_time_before as date_before,
	g.min_operation_before as operation_before,
	g.min_reinbeitebruker_id_before as reinbeitebruker_id_before ,
	g.min_saksbehandler_before as saksbehandler_before,
	g.min_json_row_data_before as json_before,


	g.max_id_after as id_after,
	g.max_action_time_after as date_after,
	g.max_operation_after as operation_after,
	g.max_reinbeitebruker_id_after as reinbeitebruker_id_after ,
	g.max_saksbehandler_after as saksbehandler_after,
	g.max_json_row_data_after as json_after

	from (
		SELECT
		l1_min_id.schema_name,
		l1_min_id.table_name,

		l1_min_id.id as min_id_before,
		l1_min_id.row_id as min_data_row_id_before,
		l1_min_id.operation as min_operation_before,
		l1_min_id.action_time as min_action_time_before,
		l1_min_id.reinbeitebruker_id as min_reinbeitebruker_id_before,
		l1_min_id.saksbehandler as min_saksbehandler_before,
		l1_min_id.json_row_data as min_json_row_data_before,

		l2_max_id.id as max_id_after,
		l2_max_id.row_id as max_data_row_id_after,
		l2_max_id.operation as max_operation_after,
		l2_max_id.action_time as max_action_time_after,
		l2_max_id.reinbeitebruker_id as max_reinbeitebruker_id_after,
		l2_max_id.saksbehandler as max_saksbehandler_after,
		l2_max_id.json_row_data as max_json_row_data_after


		from (
			select schema_name , table_name , row_id,
			min(data_update_log_id_before) as min_data_update_log_id_before, -- get the first changed row at the oldest available change time
			max(data_update_log_id_after) as max_data_update_log_id_after -- get the last changed row at time two,the latest change time
			from (
				select
				l1.id as data_update_log_id_before, first_action_id,
				l2.id as data_update_log_id_after, latest_action_id,
				g.schema_name , g.table_name , g.row_id
				from (
				-- only select does with status 10 and that not have been checked before
				-- group by the table and the row id
				SELECT distinct
					schema_name , table_name , row_id ,
					min(id) as first_action_id, -- the time oldest available change
					max(id) as latest_action_id   -- the time latest avaiable change
					from topo_rein.data_update_log
					where change_confirmed_by_admin = false and
--					json_row_data is not null and
--					json_row_data::text <> '{}'::text and
					removed_by_splitt_operation = false
					-- and saksbehandler is not null
					-- and operation in ('UPDATE_BEFORE','UPDATE_AFTER')
					-- and status in (10,0)
					group by schema_name , table_name , row_id
				) as g,
				topo_rein.data_update_log l1,
				topo_rein.data_update_log l2
				where l1.id = g.first_action_id and l1.row_id = g.row_id
				-- and l2.status in (10,0)
				and l2.id = g.latest_action_id  and l2.row_id = g.row_id
			) as g
			group by schema_name , table_name , row_id
		) g,
		topo_rein.data_update_log l1_min_id,
		topo_rein.data_update_log l2_max_id
		where l1_min_id.id = g.min_data_update_log_id_before
		and l2_max_id.id = g.max_data_update_log_id_after
		order by l1_min_id.schema_name , l1_min_id.table_name , max_id_after desc
	) as g
) as g
where id_before != id_after and json_after is not null and json_after::text <> '{}'::text
)
;

--select * from topo_rein.data_update_log_new_v ;

--select topo_update.layer_accept_update(id_after,'lop') from topo_rein.data_update_log_new_v;

--select topo_update.layer_reject_update(id_before,'lop') from topo_rein.data_update_log_new_v;



-- Used for tesing
--TRUNCATE table topo_rein.data_update_log;
--SELECT * FROM topo_rein.data_update_log;
--SET pgtopo_update.session_id ='session_id';
--SET pgtopo_update.draw_line_opr = '1';
--SET client_min_messages to 'debug';

--SELECT '31', topo_update.apply_attr_on_topo_line('{"properties":{"id":2,"status":1,"reinbeitebruker_id":"ZH","reindrift_sesongomrade_kode":4}}','topo_rein', 'arstidsbeite_sommer_flate', 'omrade');
--SELECT '32', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, status  from topo_rein.arstidsbeite_sommer_flate;
-- create schema for topo_ar5 data, tables, ....
CREATE SCHEMA topo_ar5;
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
  grunnforhold SMALLINT CHECK (grunnforhold IN (41, 42, 43, 44, 45, 98, 99)),

  -- This is flag used indicate the status of this record.
  -- The rules for how to use this flag is not decided yet. May not be used in AR5
  -- Here is a list of the current states.
  -- 0: Ukjent (uknown)
  -- 1: Godkjent
  -- 10: Endret
  status INT NOT NULL DEFAULT 0,

  -- contains felles egenskaper for ar5
  felles_egenskaper topo_rein.sosi_felles_egenskaper,

  informasjon TEXT,

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
  'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_ar5.webclient_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_ar5.webclient_flate.felles_egenskaper IS
  'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_ar5.webclient_flate.geo IS 'This holds the ref to topo_ar5_sysdata_webclient.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_ar5_webclient_flate_geo_relation_id_idx
  ON topo_ar5.webclient_flate(topo_rein.get_relation_id(omrade));

COMMENT ON INDEX topo_ar5.topo_ar5_webclient_flate_geo_relation_id_idx IS
  'A function based index to faster find the topo rows for in the relation table';

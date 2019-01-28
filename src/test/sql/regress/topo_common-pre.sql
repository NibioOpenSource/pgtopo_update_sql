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

-- add row level security
ALTER TABLE topo_rein.arstidsbeite_var_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights  
-- Is another way to do this
CREATE POLICY topo_rein_arstidsbeite_var_flate_select_policy ON topo_rein.arstidsbeite_var_flate FOR SELECT  USING(true);

-- Handle update 
DROP POLICY IF EXISTS topo_rein_arstidsbeite_var_flate_update_policy ON topo_rein.arstidsbeite_var_flate ;

CREATE POLICY topo_rein_arstidsbeite_var_flate_update_policy ON topo_rein.arstidsbeite_var_flate 
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
AND rl.table_name = 'topo_rein.arstidsbeite_var_flate'
AND rl.column_name = 'reinbeitebruker_id'))

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
AND rl.table_name = 'topo_rein.arstidsbeite_var_flate'
AND rl.column_name = 'reinbeitebruker_id'))

)
;
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

-- add row level security
ALTER TABLE topo_rein.arstidsbeite_sommer_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights  
-- Is another way to do this
CREATE POLICY topo_rein_arstidsbeite_sommer_flate_select_policy ON topo_rein.arstidsbeite_sommer_flate FOR SELECT  USING(true);

-- Drp if exits
DROP POLICY IF EXISTS topo_rein_arstidsbeite_sommer_flate_update_policy ON topo_rein.arstidsbeite_sommer_flate;

-- Handle update 
CREATE POLICY topo_rein_arstidsbeite_sommer_flate_update_policy ON topo_rein.arstidsbeite_sommer_flate 
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
AND rl.table_name = 'topo_rein.arstidsbeite_sommer_flate'
AND rl.column_name = 'reinbeitebruker_id'))

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
AND rl.table_name = 'topo_rein.arstidsbeite_sommer_flate'
AND rl.column_name = 'reinbeitebruker_id'))

)
;
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

-- add row level security
ALTER TABLE topo_rein.arstidsbeite_hostvinter_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights  
-- Is another way to do this
CREATE POLICY topo_rein_arstidsbeite_hostvinter_flate_select_policy ON topo_rein.arstidsbeite_hostvinter_flate FOR SELECT  USING(true);

-- Drp if exits
DROP POLICY IF EXISTS topo_rein_arstidsbeite_hostvinter_flate_update_policy ON topo_rein.arstidsbeite_hostvinter_flate ;

-- Handle update 
CREATE POLICY topo_rein_arstidsbeite_hostvinter_flate_update_policy ON topo_rein.arstidsbeite_hostvinter_flate 
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
AND rl.table_name = 'topo_rein.arstidsbeite_hostvinter_flate'
AND rl.column_name = 'reinbeitebruker_id'))

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
AND rl.table_name = 'topo_rein.arstidsbeite_hostvinter_flate'
AND rl.column_name = 'reinbeitebruker_id'))

)
;
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

-- add row level security
ALTER TABLE topo_rein.arstidsbeite_vinter_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights  
-- Is another way to do this
CREATE POLICY topo_rein_arstidsbeite_vinter_flate_select_policy ON topo_rein.arstidsbeite_vinter_flate FOR SELECT  USING(true);

-- Drp if exits
DROP POLICY IF EXISTS topo_rein_arstidsbeite_vinter_flate_update_policy ON topo_rein.arstidsbeite_vinter_flate;

-- Handle update 
CREATE POLICY topo_rein_arstidsbeite_vinter_flate_update_policy ON topo_rein.arstidsbeite_vinter_flate 
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
AND rl.table_name = 'topo_rein.arstidsbeite_vinter_flate'
AND rl.column_name = 'reinbeitebruker_id'))

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
AND rl.table_name = 'topo_rein.arstidsbeite_vinter_flate'
AND rl.column_name = 'reinbeitebruker_id'))

)
;

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
reindriftsanleggstype int CHECK ( (reindriftsanleggstype > 0 AND reindriftsanleggstype < 8) or (reindriftsanleggstype = 12)),

anleggstype int[3] CHECK (
  (anleggstype[0] > 0 AND anleggstype[0] < 8) or (anleggstype[0] = 12) AND
  (anleggstype[1] > 0 AND anleggstype[1] < 8) or (anleggstype[1] = 12) AND
  (anleggstype[2] > 0 AND anleggstype[2] < 8) or (anleggstype[2] = 12)
)

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_ran', 'topo_rein', 'reindrift_anlegg_linje', 'linje', 'LINESTRING') As new_layer_id;


-- create function basded index to get performance
CREATE INDEX topo_rein_reindrift_anlegg_linje_geo_relation_id_idx ON topo_rein.reindrift_anlegg_linje(topo_rein.get_relation_id(linje));


-- add row level security
ALTER TABLE topo_rein.reindrift_anlegg_linje ENABLE ROW LEVEL SECURITY;

-- Give all users select rights
-- Is another way to do this
CREATE POLICY topo_rein_reindrift_anlegg_linje_select_policy ON topo_rein.reindrift_anlegg_linje FOR SELECT  USING(true);

-- Handle update
DROP POLICY if EXISTS topo_rein_reindrift_anlegg_linje_update_policy ON topo_rein.reindrift_anlegg_linje;

CREATE POLICY topo_rein_reindrift_anlegg_linje_update_policy ON topo_rein.reindrift_anlegg_linje
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
(
reinbeitebruker_id = ANY((SELECT  column_value FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.table_name = 'topo_rein.reindrift_anlegg_linje'
AND rl.column_name = 'reinbeitebruker_id'))
AND
anleggstype::varchar  = 
ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.table_name = 'topo_rein.reindrift_anlegg_linje'
AND rl.column_name = 'anleggstype')
)

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
(
reinbeitebruker_id = ANY((SELECT  column_value FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.table_name = 'topo_rein.reindrift_anlegg_linje'
AND rl.column_name = 'reinbeitebruker_id'))
AND
anleggstype::varchar  = 
ANY (SELECT  column_value FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.table_name = 'topo_rein.reindrift_anlegg_linje'
AND rl.column_name = 'anleggstype')
)

)
;

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
reindriftsanleggstype int CHECK (reindriftsanleggstype > 9 AND reindriftsanleggstype < 21),

anleggstype int[3] CHECK (
  (anleggstype[0] > 9 AND anleggstype[0] < 21) AND
  (anleggstype[1] > 9 AND anleggstype[1] < 21) AND
  (anleggstype[2] > 9 AND anleggstype[2] < 21)
)

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_ran', 'topo_rein', 'reindrift_anlegg_punkt', 'punkt', 'POINT') As new_layer_id;


-- create function basded index to get performance
CREATE INDEX topo_rein_reindrift_anlegg_punkt_geo_relation_id_idx ON topo_rein.reindrift_anlegg_punkt(topo_rein.get_relation_id(punkt));

-- add row level security
ALTER TABLE topo_rein.reindrift_anlegg_punkt ENABLE ROW LEVEL SECURITY;

-- Give all users select rights
-- Is another way to do this
CREATE POLICY topo_rein_reindrift_anlegg_punkt_select_policy ON topo_rein.reindrift_anlegg_punkt FOR SELECT  USING(true);

DROP POLICY if EXISTS topo_rein_reindrift_anlegg_punkt_update_policy ON topo_rein.reindrift_anlegg_punkt;

-- Handle update
CREATE POLICY topo_rein_reindrift_anlegg_punkt_update_policy ON topo_rein.reindrift_anlegg_punkt
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
AND rl.table_name = 'topo_rein.reindrift_anlegg_punkt'
AND rl.column_name = 'reinbeitebruker_id'))

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
AND rl.table_name = 'topo_rein.reindrift_anlegg_punkt'
AND rl.column_name = 'reinbeitebruker_id'))

)
;
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

-- add row level security
ALTER TABLE topo_rein.beitehage_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights
-- Is another way to do this
CREATE POLICY topo_rein_beitehage_flate_select_policy ON topo_rein.beitehage_flate FOR SELECT  USING(true);

DROP POLICY if EXISTS topo_rein_beitehage_flate_update_policy ON topo_rein.beitehage_flate;

-- Handle update
CREATE POLICY topo_rein_beitehage_flate_update_policy ON topo_rein.beitehage_flate
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
AND rl.table_name = 'topo_rein.beitehage_flate'
AND rl.column_name = 'reinbeitebruker_id'))

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
AND rl.table_name = 'topo_rein.beitehage_flate'
AND rl.column_name = 'reinbeitebruker_id'))

)
;
select CreateTopology('topo_rein_sysdata_rop',4258,0.0000000001);

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
-- drop table topo_rein.oppsamlingomr_flate;
-- drop table topo_rein.oppsamlingomr_grense;
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'oppsamlingomr_flate', 'omrade');
-- SELECT topology.DropTopoGeometryColumn('topo_rein', 'oppsamlingomr_grense', 'grense');


-- Do we want attributtes on the borders or only on the surface ?
-- If yes is it only felles_egenskaper ? 
-- If yes should we felles_egenskaper remove from the surface ?
-- If yes should how should we get value from the old data, 
-- do we then have use the sosi files and not org_rein tables ?

-- If yes then we need the table oppsamlingomr_grense
CREATE TABLE topo_rein.oppsamlingomr_grense(

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
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rop', 'topo_rein', 'oppsamlingomr_grense', 'grense', 'LINESTRING') As new_layer_id;

-- What should with do with linestrings that are not used form any surface ?
-- What should wihh linestrings that form a surface but are not reffered to by the topo_rein.oppsamlingomr_flate ?


CREATE TABLE topo_rein.oppsamlingomr_flate(

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
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata_rop', 'topo_rein', 'oppsamlingomr_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t 
	--WHERE t.name = 'topo_rein_sysdata_rop' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'oppsamlingomr_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;




COMMENT ON TABLE topo_rein.oppsamlingomr_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.oppsamlingomr_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.oppsamlingomr_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.oppsamlingomr_flate.geo IS 'This holds the ref to topo_rein_sysdata_rop.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_oppsamlingomr_flate_geo_relation_id_idx ON topo_rein.oppsamlingomr_flate(topo_rein.get_relation_id(omrade));	

COMMENT ON INDEX topo_rein.topo_rein_oppsamlingomr_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';

-- add row level security
ALTER TABLE topo_rein.oppsamlingomr_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights  
-- Is another way to do this
CREATE POLICY topo_rein_oppsamlingomr_flate_select_policy ON topo_rein.oppsamlingomr_flate FOR SELECT  USING(true);

DROP POLICY if EXISTS topo_rein_oppsamlingomr_flate_update_policy ON topo_rein.oppsamlingomr_flate;

-- Handle update 
CREATE POLICY topo_rein_oppsamlingomr_flate_update_policy ON topo_rein.oppsamlingomr_flate 
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
AND rl.table_name = 'topo_rein.oppsamlingomr_flate'
AND rl.column_name = 'reinbeitebruker_id'))

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
AND rl.table_name = 'topo_rein.oppsamlingomr_flate'
AND rl.column_name = 'reinbeitebruker_id'))

)
;
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

-- add row level security
ALTER TABLE topo_rein.avtaleomrade_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights
-- Is another way to do this
CREATE POLICY topo_rein_avtaleomrade_flate_select_policy ON topo_rein.avtaleomrade_flate FOR SELECT  USING(true);

-- Handle update
CREATE POLICY topo_rein_avtaleomrade_flate_update_policy ON topo_rein.avtaleomrade_flate
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
)
;
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

-- add row level security
ALTER TABLE topo_rein.ekspropriasjonsomrade_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights
-- Is another way to do this
CREATE POLICY topo_rein_ekspropriasjonsomrade_flate_select_policy ON topo_rein.ekspropriasjonsomrade_flate FOR SELECT  USING(true);

-- Handle update
CREATE POLICY topo_rein_ekspropriasjonsomrade_flate_update_policy ON topo_rein.ekspropriasjonsomrade_flate
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
)
;
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

-- add row level security
ALTER TABLE topo_rein.konsesjonsomrade_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights
-- Is another way to do this
CREATE POLICY topo_rein_konsesjonsomrade_flate_select_policy ON topo_rein.konsesjonsomrade_flate FOR SELECT  USING(true);

-- Handle update
CREATE POLICY topo_rein_konsesjonsomrade_flate_update_policy ON topo_rein.konsesjonsomrade_flate
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
)
;
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

-- add row level security
ALTER TABLE topo_rein.konvensjonsomrade_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights
-- Is another way to do this
CREATE POLICY topo_rein_konvensjonsomrade_flate_select_policy ON topo_rein.konvensjonsomrade_flate FOR SELECT  USING(true);

-- Handle update
CREATE POLICY topo_rein_konvensjonsomrade_flate_update_policy ON topo_rein.konvensjonsomrade_flate
FOR ALL
USING
(
-- a user that edit anything
EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.edit_all = true)
OR
NOT EXISTS (
  SELECT * FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='konvensjonsomrade_flate' AND COLUMN_NAME='reinbeitebruker_id'
)
)
WITH CHECK
(
-- a user that edit anything
EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.edit_all = true)
OR
NOT EXISTS (
  SELECT * FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='konvensjonsomrade_flate' AND COLUMN_NAME='reinbeitebruker_id'
)
)
;
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

-- add row level security
ALTER TABLE topo_rein.reinbeitedistrikt_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights
-- Is another way to do this
CREATE POLICY topo_rein_reinbeitedistrikt_flate_select_policy ON topo_rein.reinbeitedistrikt_flate FOR SELECT  USING(true);

-- Handle update
CREATE POLICY topo_rein_reinbeitedistrikt_flate_update_policy ON topo_rein.reinbeitedistrikt_flate
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
)
;
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

reinbeiteområde_id varchar(3) CHECK (reinbeiteområde_id IN ('U','V','W','X','Y','Z')),

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

reinbeiteområde_id varchar(3) CHECK (reinbeiteområde_id IN ('U','V','W','X','Y','Z')),

-- angir hvilket reinbeiteomrade som bruker beiteområdet
-- Definition -- indicates which reindeer pasture district uses the pasture area
-- reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')),

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

-- add row level security
ALTER TABLE topo_rein.reinbeiteomrade_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights
-- Is another way to do this
CREATE POLICY topo_rein_reinbeiteomrade_flate_select_policy ON topo_rein.reinbeiteomrade_flate FOR SELECT USING(true);

-- Handle update
CREATE POLICY topo_rein_reinbeiteomrade_flate_update_policy ON topo_rein.reinbeiteomrade_flate
FOR ALL
USING
(
-- a user that edit anything
EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.edit_all = true)
-- OR
-- reinbeitebruker_id is null
OR
NOT EXISTS (
  SELECT * FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='reinbeiteomrade_flate' AND COLUMN_NAME='reinbeitebruker_id'
)
)
WITH CHECK
(
-- a user that edit anything
EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.edit_all = true)
-- OR
-- reinbeitebruker_id is null
OR
NOT EXISTS (
  SELECT * FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='reinbeiteomrade_flate' AND COLUMN_NAME='reinbeitebruker_id'
)
)
;
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

-- add row level security
ALTER TABLE topo_rein.restriksjonsomrade_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights
-- Is another way to do this
CREATE POLICY topo_rein_restriksjonsomrade_flate_select_policy ON topo_rein.restriksjonsomrade_flate FOR SELECT  USING(true);

-- Handle update
CREATE POLICY topo_rein_restriksjonsomrade_flate_update_policy ON topo_rein.restriksjonsomrade_flate
FOR ALL
USING
(
-- a user that edit anything
EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.edit_all = true)
OR
NOT EXISTS (
  SELECT * FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='restriksjonsomrade_flate' AND COLUMN_NAME='reinbeitebruker_id'
)
)
WITH CHECK
(
-- a user that edit anything
EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.edit_all = true)
OR
NOT EXISTS (
  SELECT * FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='restriksjonsomrade_flate' AND COLUMN_NAME='reinbeitebruker_id'
)
)
;
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

-- add row level security
ALTER TABLE topo_rein.restriksjonsomrade_linje ENABLE ROW LEVEL SECURITY;

-- Give all users select rights
-- Is another way to do this
CREATE POLICY topo_rein_restriksjonsomrade_linje_select_policy ON topo_rein.restriksjonsomrade_linje FOR SELECT  USING(true);

-- Handle update
CREATE POLICY topo_rein_restriksjonsomrade_linje_update_policy ON topo_rein.restriksjonsomrade_linje
FOR ALL
USING
(
-- a user that edit anything
EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.edit_all = true)
OR
NOT EXISTS (
  SELECT * FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='restriksjonsomrade_linje' AND COLUMN_NAME='reinbeitebruker_id'
)
)
WITH CHECK
(
-- a user that edit anything
EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.edit_all = true)
OR
NOT EXISTS (
  SELECT * FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='restriksjonsomrade_linje' AND COLUMN_NAME='reinbeitebruker_id'
)
)
;
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
-- reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')),

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

-- add row level security
ALTER TABLE topo_rein.siidaomrade_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights
-- Is another way to do this
CREATE POLICY topo_rein_siidaomrade_flate_select_policy ON topo_rein.siidaomrade_flate FOR SELECT  USING(true);

-- Handle update
CREATE POLICY topo_rein_siidaomrade_flate_update_policy ON topo_rein.siidaomrade_flate
FOR ALL
USING
(
-- a user that edit anything
EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.edit_all = true)
-- OR
-- reinbeitebruker_id is null
OR
NOT EXISTS (
  SELECT * FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='siidaomrade_flate' AND COLUMN_NAME='reinbeitebruker_id'
)
)
WITH CHECK
(
-- a user that edit anything
EXISTS (SELECT 1 FROM topo_rein.rls_role_mapping rl
WHERE rl.session_id = current_setting('pgtopo_update.session_id')
AND rl.edit_all = true)
-- OR
-- reinbeitebruker_id is null
OR
NOT EXISTS (
  SELECT * FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'topo_rein' AND TABLE_NAME='siidaomrade_flate' AND COLUMN_NAME='reinbeitebruker_id'
)
)
;
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
-- DROP VIEW IF EXISTS topo_rein.oppsamlingomr_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.oppsamlingomr_topojson_flate_v 
AS
select 
id,
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
	AND rl.table_name = 'topo_rein.oppsamlingomr_flate'
	AND rl.column_name = 'reinbeitebruker_id')
	THEN true

	WHEN  reinbeitebruker_id is null
	THEN true

	ELSE false 
END AS "editable"
from topo_rein.oppsamlingomr_flate al;

--select * from topo_rein.oppsamlingomr_topojson_flate_vDROP VIEW IF EXISTS topo_rein.rein_trekklei_topojson_linje_v cascade ;


CREATE OR REPLACE VIEW topo_rein.rein_trekklei_topojson_linje_v 
AS
select 
id,
reinbeitebruker_id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato", 
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav", 
((al.felles_egenskaper).kvalitet).maalemetode AS "fellesegenskaper.maalemetode",
((al.felles_egenskaper).kvalitet).noyaktighet AS "fellesegenskaper.noyaktighet",
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
((al.felles_egenskaper).kvalitet).maalemetode AS "fellesegenskaper.maalemetode",
((al.felles_egenskaper).kvalitet).noyaktighet AS "fellesegenskaper.noyaktighet",
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


-- add row level security
ALTER TABLE topo_rein.arstidsbeite_host_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights  
-- Is another way to do this
CREATE POLICY topo_rein_arstidsbeite_host_flate_select_policy ON topo_rein.arstidsbeite_host_flate FOR SELECT  USING(true);

-- Drp if exits
DROP POLICY IF EXISTS topo_rein_arstidsbeite_host_flate_update_policy ON topo_rein.arstidsbeite_host_flate;

-- Handle update 
CREATE POLICY topo_rein_arstidsbeite_host_flate_update_policy ON topo_rein.arstidsbeite_host_flate 
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
AND rl.table_name = 'topo_rein.arstidsbeite_host_flate'
AND rl.column_name = 'reinbeitebruker_id'))

-- handles insert new lines on surfaces
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
AND rl.table_name = 'topo_rein.arstidsbeite_host_flate'
AND rl.column_name = 'reinbeitebruker_id'))

-- handles insert new lines on surfaces
OR
current_setting('pgtopo_update.draw_line_opr') = '1'

)
;


/**
 * Creates a "logging" schema with an "history" table where are stored records in JSON format
 * 
 * Requires PostgreSQL >= 9.3 since data is stored in JSON format
 *
 * Info http://www.cybertec.at/2013/12/tracking-changes-in-postgresql/ and  https://gist.github.com/cristianp6/29ce1c942448e95c2f95
 */



/* Create the table in which to store changes in tables logs */
--drop TABLE topo_rein.data_update_log cascade;

CREATE TABLE topo_rein.data_update_log (
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
    change_confirmed_by_admin boolean NOT null default false
    
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
foreach tbl_name IN array string_to_array('arstidsbeite_sommer,arstidsbeite_host,arstidsbeite_hostvinter,arstidsbeite_vinter,arstidsbeite_var,beitehage,oppsamlingomr',',')
loop
	EXECUTE format('DROP VIEW IF EXISTS %1$s_flate_json_update_log; CREATE OR REPLACE VIEW %1$s_flate_json_update_log as select v1.*,v2.saksbehandler from %1$s_topojson_flate_v v1, %1$s_flate v2 where v1.id = v2.id', 'topo_rein.'||tbl_name);
END loop;
END
$body$;

-- create line view
-- what about trekklei ?????
DO
$body$
DECLARE
tbl_name text;
topo_tables text[];
BEGIN
foreach tbl_name IN array string_to_array('reindrift_anlegg',',')
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



/* Create the functions used for trigger insert after  */
CREATE OR REPLACE FUNCTION topo_rein.table_change_trigger_insert_after() RETURNS trigger AS $$
    BEGIN
        IF    (TG_OP = 'INSERT') THEN
            INSERT INTO topo_rein.data_update_log (table_name, schema_name, saksbehandler, row_id, status, reinbeitebruker_id, operation, json_row_data)
                VALUES (TG_RELNAME, TG_TABLE_SCHEMA, NEW.saksbehandler, NEW.id, NEW.status, NEW.reinbeitebruker_id, TG_OP||'_AFTER', 
                topo_rein.data_update_log_get_json_row_data('select distinct a.* from '||TG_TABLE_SCHEMA||'.'||TG_RELNAME||'_json_update_log a where a.id = '||NEW.id,32633,0,0)::json
                );
            RETURN NEW;
        END IF;
        RETURN NULL;
    END;
$$ LANGUAGE 'plpgsql' SECURITY DEFINER;

/* Create the functions used for trigger update before  */
CREATE OR REPLACE FUNCTION topo_rein.change_trigger_update_before() RETURNS trigger AS $$
    BEGIN
		IF (TG_OP = 'UPDATE') THEN
            INSERT INTO topo_rein.data_update_log (table_name, schema_name, saksbehandler, row_id, status, reinbeitebruker_id, operation, json_row_data)
                VALUES (TG_RELNAME, TG_TABLE_SCHEMA, OLD.saksbehandler, OLD.id, OLD.status, OLD.reinbeitebruker_id, TG_OP||'_BEFORE', 
                topo_rein.data_update_log_get_json_row_data('select distinct a.* from '||TG_TABLE_SCHEMA||'.'||TG_RELNAME||'_json_update_log a where a.id = '||OLD.id,32633,0,0)::json
                );
            RETURN NEW;
        END IF;
        RETURN NULL;
    END;
$$ LANGUAGE 'plpgsql' SECURITY DEFINER;

/* Create the functions used for trigger update after  */
CREATE OR REPLACE FUNCTION topo_rein.change_trigger_update_after() RETURNS trigger AS $$
    BEGIN
		IF (TG_OP = 'UPDATE') THEN
            INSERT INTO topo_rein.data_update_log (table_name, schema_name, saksbehandler, row_id, status, reinbeitebruker_id, operation, json_row_data)
                VALUES (TG_RELNAME, TG_TABLE_SCHEMA, NEW.saksbehandler, NEW.id, NEW.status, NEW.reinbeitebruker_id, TG_OP||'_AFTER', 
                topo_rein.data_update_log_get_json_row_data('select distinct a.* from '||TG_TABLE_SCHEMA||'.'||TG_RELNAME||'_json_update_log a where a.id = '||NEW.id,32633,0,0)::json
                );
            RETURN NEW;
        END IF;
        RETURN NULL;
    END;
$$ LANGUAGE 'plpgsql' SECURITY DEFINER;

/* Create the triggers */

DO
$body$
DECLARE
tbl_name text;
topo_tables text[];
BEGIN
foreach tbl_name IN array string_to_array('arstidsbeite_sommer_flate,arstidsbeite_host_flate,arstidsbeite_hostvinter_flate,arstidsbeite_vinter_flate,arstidsbeite_var_flate,beitehage_flate,oppsamlingomr_flate,reindrift_anlegg_linje,reindrift_anlegg_punkt',',')
loop

EXECUTE format('DROP TRIGGER IF EXISTS table_change_trigger_insert_after ON %1$s;
     CREATE TRIGGER table_change_trigger_insert_after                                            
     AFTER INSERT ON %1$s       
     FOR EACH ROW EXECUTE PROCEDURE topo_rein.table_change_trigger_insert_after()', 'topo_rein.'||tbl_name);           

EXECUTE format('DROP TRIGGER IF EXISTS table_change_trigger_update_before ON %1$s;
     CREATE TRIGGER table_change_trigger_update_before                                            
     BEFORE UPDATE ON %1$s        
     FOR EACH ROW EXECUTE PROCEDURE topo_rein.change_trigger_update_before()', 'topo_rein.'||tbl_name);             

EXECUTE format('DROP TRIGGER IF EXISTS table_change_trigger_update_after ON %1$s;
     CREATE TRIGGER table_change_trigger_update_after                                            
     AFTER UPDATE ON %1$s       
     FOR EACH ROW EXECUTE PROCEDURE topo_rein.change_trigger_update_after()', 'topo_rein.'||tbl_name);           
     
END loop;
END
$body$;


-- this function that used to select 

-- Create view to show changes before and after for each single row
CREATE OR REPLACE VIEW topo_rein.data_update_log_new_v AS (
SELECT 
g.schema_name , g.table_name, l1.row_id as data_row_id,
-- TODO test that it's ok tha we get srid from json

l1.id as id_before,
l1.reinbeitebruker_id as reinbeitebruker_id_before ,
l1.saksbehandler as saksbehandler_before,
l1.json_row_data as json_before,
l2.id as id_after,
l2.reinbeitebruker_id as reinbeitebruker_id_after ,
l2.saksbehandler as saksbehandler_after,
l2.json_row_data as json_after 
from 
(
 -- only select does with status 10 and that not have been checked before
 -- group by the table and the row id
 SELECT 
 schema_name , table_name , min(id) as data_update_log_id_before, max(id) as data_update_log_id_after 
 from topo_rein.data_update_log 
 where change_confirmed_by_admin = false
-- and operation in ('UPDATE_BEFORE','UPDATE_AFTER')
 and status in (10,0)
 group by schema_name , table_name , row_id
) g,
topo_rein.data_update_log l1,
topo_rein.data_update_log l2
where data_update_log_id_before != data_update_log_id_after
and l1.id = g.data_update_log_id_before
and  l2.id = g.data_update_log_id_after

);


-- Used for tesing          
--TRUNCATE table topo_rein.data_update_log;
--SELECT * FROM topo_rein.data_update_log;
--SET pgtopo_update.session_id ='session_id';
--SET pgtopo_update.draw_line_opr = '1';
--SET client_min_messages to 'debug';

--SELECT '31', topo_update.apply_attr_on_topo_line('{"properties":{"id":2,"status":1,"reinbeitebruker_id":"ZH","reindrift_sesongomrade_kode":4}}','topo_rein', 'arstidsbeite_sommer_flate', 'omrade');
--SELECT '32', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, status  from topo_rein.arstidsbeite_sommer_flate;



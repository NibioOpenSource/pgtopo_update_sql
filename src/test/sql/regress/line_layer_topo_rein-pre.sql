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
	"fellesegenskaper.kvalitet.maalemetode" int 
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


-- add row level security
ALTER TABLE topo_rein.arstidsbeite_host_flate ENABLE ROW LEVEL SECURITY;

-- Give all users select rights  
-- Is another way to do this
CREATE POLICY topo_rein_arstidsbeite_host_flate_select_policy ON topo_rein.arstidsbeite_host_flate FOR SELECT  USING(true);

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

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmarksbeite 
-- TODO add not null
reindriftsanleggstype int CHECK ( (reindriftsanleggstype > 0 AND reindriftsanleggstype < 8) or (reindriftsanleggstype=12)) 


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

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmarksbeite 
reindriftsanleggstype int CHECK (reindriftsanleggstype > 9 AND reindriftsanleggstype < 21) 


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

DROP VIEW IF EXISTS topo_rein.arstidsbeite_var_mbrs_v cascade ;


CREATE OR REPLACE VIEW topo_rein.arstidsbeite_var_mbrs_v 
AS
select 
 face_id,
 0 as id,
0 reindrift_sesongomrade_kode,
-- ST_Simplify(ST_Union(mbr),0.001) as omrade ,
 mbr as omrade ,
true AS "mbr" 
from topo_rein_sysdata_rvr.face;

--SELECT ST_AStext(ST_union(mbr)) from topo_rein_sysdata_rvr.face;

--select * from topo_rein.arstidsbeite_var_mbrs_vDROP VIEW IF EXISTS topo_rein.arstidsbeite_var_topojson_flate_v cascade ;


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

	WHEN  reinbeitebruker_id is null
	THEN true
	
	ELSE false 
END AS "editable"
from topo_rein.arstidsbeite_vinter_flate al;

--select * from topo_rein.arstidsbeite_vinter_topojson_flate_v-- DROP VIEW IF EXISTS topo_rein.beitehage_topojson_flate_v cascade ;


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

	WHEN  reinbeitebruker_id is null
	THEN true
	
	ELSE false 
END AS "editable"
from topo_rein.beitehage_flate al;

--select * from topo_rein.beitehage_topojson_flate_v-- DROP VIEW IF EXISTS topo_rein.oppsamlingomr_topojson_flate_v cascade ;


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
	
	WHEN  reinbeitebruker_id is null
	THEN true

	ELSE false 
END AS "editable"
from topo_rein.rein_trekklei_linje al;

-- select * from topo_rein.rein_trekklei_topojson_linje_v ;


-- DROP VIEW topo_rein.reindrift_anlegg_linje_v cascade ;


CREATE OR REPLACE VIEW topo_rein.reindrift_anlegg_linje_v 
AS
select 
id,
--((al.felles_egenskaper).kvalitet).maalemetode,
--((al.felles_egenskaper).kvalitet).noyaktighet,
--((al.felles_egenskaper).kvalitet).synbarhet,
--(al.felles_egenskaper).verifiseringsdato, 
--(al.felles_egenskaper).opphav, 
--(al.felles_egenskaper).informasjon::varchar as informasjon, 
reinbeitebruker_id,
reindriftsanleggstype,
linje::geometry(MultiLineString,4258) as geo 
from topo_rein.reindrift_anlegg_linje al;

-- select * from topo_rein.reindrift_anlegg_linje_v ;


--DROP VIEW topo_rein.reindrift_anlegg_punkt_v cascade ;


CREATE OR REPLACE VIEW topo_rein.reindrift_anlegg_punkt_v 
AS
select 
id,
--((al.felles_egenskaper).kvalitet).maalemetode,
--((al.felles_egenskaper).kvalitet).noyaktighet,
--((al.felles_egenskaper).kvalitet).synbarhet,
--(al.felles_egenskaper).verifiseringsdato, 
--(al.felles_egenskaper).opphav, 
--(al.felles_egenskaper).informasjon::varchar as informasjon, 
reinbeitebruker_id,
reindriftsanleggstype,
punkt::geometry(MultiPoint,4258) as geo 
from topo_rein.reindrift_anlegg_punkt al;

-- select * from topo_rein.reindrift_anlegg_punkt_v ;


 DROP VIEW IF EXISTS topo_rein.reindrift_anlegg_topojson_linje_v cascade ;


CREATE OR REPLACE VIEW topo_rein.reindrift_anlegg_topojson_linje_v 
AS
select 
id,
reinbeitebruker_id,
reindriftsanleggstype,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato", 
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav", 
((al.felles_egenskaper).kvalitet).maalemetode AS "fellesegenskaper.maalemetode",
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
reindriftsanleggstype,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangstdato", 
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav", 
((al.felles_egenskaper).kvalitet).maalemetode AS "fellesegenskaper.maalemetode",
punkt,
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
	
	WHEN  reinbeitebruker_id is null
	THEN true

	ELSE false 
END AS "editable"
from topo_rein.reindrift_anlegg_punkt al;


--select * from topo_rein.reindrift_anlegg_topojson_punkt_v ;


-- create schema for topo_update data, tables, .... 
CREATE SCHEMA topo_update;

-- make comment this schema  
COMMENT ON SCHEMA topo_update IS 'Is a schema for topo_update attributes and ref to topolygy data. Don´t do any direct update on tables in this schema, all changes should be done using stored proc.';

-- make the scema public
GRANT USAGE ON SCHEMA topo_update to public;


-- craeted to make it possible to return a set of objects from the topo function
-- Todo find a better way to du this 
DROP TABLE IF EXISTS topo_update.topogeometry_def; 
CREATE TABLE topo_update.topogeometry_def(topo topogeometry);
-- A composite type to hold key value that will recoreded before a update
-- and compared after the update, used be sure no changes hapends out side 
-- the area that should be updated 
-- DROP TYPE topo_update.closeto_values_type cascade;

CREATE TYPE topo_update.closeto_values_type
AS (
	-- line length that intersects ar5flate
	closeto_length_ar5flate_inter numeric,
	
	-- line count that intersects the edge
	closeto_count_edge_inter int,
	
	-- line count that intersetcs ar5linje 
	closeto_count_ar5linje_inter int,
	
	-- used to check that attribute value close has not changed a close to
	artype_and_length_as_text text,
	
	-- used to check that the area is ok after update 
	-- as we use today we do not remove any data we just add new polygins or change exiting 
	-- the layer should always be covered
	envelope_area_inter  numeric

);


-- This function is used to create indexes
CREATE OR REPLACE FUNCTION topo_update.get_relation_id( geo TopoGeometry) RETURNS integer AS $$DECLARE
    relation_id integer;
BEGIN
	relation_id := (geo).id;
   	RETURN relation_id;
END;
$$ LANGUAGE plpgsql
IMMUTABLE;

COMMENT ON FUNCTION topo_update.get_relation_id(TopoGeometry) IS 'Return the id used to find the row in the relation for polygons). Needed to create function based indexs.';


-- A composite type to hold sosi kvalitet
CREATE TYPE topo_update.sosi_kvalitet 
AS (
	maalemetode smallint,
	noyaktighet integer,
	synbarhet smallint
);


-- A composite type to hold sosi kopi_data
CREATE TYPE topo_update.sosi_kopidata 
AS (
	omradeid smallint,
	originaldatavert  VARCHAR(50),
	kopidato DATE
);

-- A composite type to hold sosi registreringsversjon
CREATE TYPE topo_update.sosi_registreringsversjon 
AS (
	produkt varchar,
	versjon varchar
);

-- A composite type to hold sosi sosi felles egenskaper
CREATE TYPE topo_update.sosi_felles_egenskaper
AS (
	datafangstdato DATE,
	informasjon  VARCHAR(255) ARRAY, 
	kopidata topo_update.sosi_kopidata, -- not used in this case
	kvalitet topo_update.sosi_kvalitet,
	oppdateringsdato DATE, -- only used by qms when data to keep track of server update
	opphav VARCHAR(255),
	prosess_historie VARCHAR(255) ARRAY,
	registreringsversjon topo_update.sosi_registreringsversjon,
	verifiseringsdato DATE
);



---------------------------------------------------------------------------------

-- A composite type to hold infor about the currrent layers that will be updated 
-- this will be used to pick up meta info from the topolgy layer doing a update
CREATE TYPE topo_update.input_meta_info 
AS (
	-- refferes to topology.topology
	topology_name varchar,
	
	-- reffers to topology.layer
	layer_schema_name varchar,
	layer_table_name varchar,
	layer_feature_column varchar,

	-- For a edge this is 2 and for a surface this is 3 
	element_type int,

	-- this is the snapp to tolerance used for snap to when adding new vector data 
	-- a typical value used for degrees is 0.0000000001
	snap_tolerance float8,
	
	-- this is computed by using function topo_update.get_topo_layer_id
	border_layer_id int
	

);



---------------------------------------------------------------------------------

-- A composite type to hold infor about the currrent layers that will be updated 
-- this will be used to pick up meta info from the topolgy layer doing a update
CREATE TYPE topo_update.json_input_structure 
AS (

-- the input geo picked from the client properties
input_geo geometry,

-- JSON that is sent from the client combained with the server json properties
json_properties json,

-- this build up based on the input json  this used for both line and  point
sosi_felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- this only used for the surface objectand does not contain any info about drawing
sosi_felles_egenskaper_flate topo_rein.sosi_felles_egenskaper

);

-- TODO move this function to it's file

-- DROP function topo_update.create_temp_tbl_as(tblname text,qry text);
-- {
CREATE OR replace function topo_update.create_temp_tbl_as(tblname text,qry text)
returns text as
$$ 
BEGIN
$1 = trim($1);
IF NOT EXISTS (SELECT relname FROM pg_catalog.pg_class where relname =$1) THEN
	return 'CREATE TEMP TABLE '||$1||' ON COMMIT DROP AS '||$2||'';
--IF NOT EXISTS (SELECT 1 FROM pg_tables where tablename = substr($1,strpos($1,'.')+1) AND schemaname = substr($1,0,strpos($1,'.')) ) THEN
--	return 'CREATE TABLE '||$1||' AS '||$2||'';
else
	return 'TRUNCATE TABLE '||$1||'';
END IF;
END
$$
language plpgsql;
--}

-- TODO move this function to it's file

-- DROP function topo_update.create_temp_tbl_def(tblname text,def text);
-- {
CREATE OR replace function topo_update.create_temp_tbl_def(tblname text,def text)
returns text as
$$ 
BEGIN
$1 = trim($1);
IF NOT EXISTS (SELECT relname FROM pg_catalog.pg_class where relname =$1) THEN
	return 'CREATE TEMP TABLE '||$1||''||$2||' ON COMMIT DROP';
--IF NOT EXISTS (SELECT 1 FROM pg_tables where tablename = substr($1,strpos($1,'.')+1) AND schemaname=substr($1,0,strpos($1,'.')) ) THEN
--	return 'CREATE TABLE '||$1||''||$2||'';
else
	return 'TRUNCATE TABLE '||$1||'';
END IF;
END
$$
language plpgsql;
--}


CREATE OR REPLACE FUNCTION topo_rein.findExtent(schema_name text, table_name text , geocolumn_name text )
RETURNS geometry AS $$
DECLARE
bb geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

command_result text;

BEGIN

	RAISE NOTICE 'schema_name is %',  schema_name;

	command_string := FORMAT('SELECT 1 FROM %I.edge_data limit 1',
                        schema_name);

    RAISE NOTICE 'command_string eeee is %',  command_string;

    EXECUTE command_string into command_result;
		
        
	IF command_result IS NOT NULL THEN
		BEGIN
			SELECT ST_EstimatedExtent(schema_name,table_name, geocolumn_name)::geometry into bb;
        EXCEPTION WHEN internal_error THEN
        -- ERROR:  XX000: stats for "edge_data.geom" do not exist
        -- Catch error and return a return null ant let application decide what to do
        END;
	END IF;
	
	RETURN bb;
END;
$$ LANGUAGE 'plpgsql' VOLATILE;
-- Adjust the input edge based on given simplify_patteren

-- 1-9 point
-- 10-20 linestring
-- 20-30 surface

CREATE OR REPLACE FUNCTION topo_update.get_adjusted_edge(edge geometry, simplify_patteren int) 
RETURNS geometry AS $$
DECLARE
-- used for creating new topo objects
new_edge geometry := edge;
num_points int;
divide_by int;
point_array_line geometry[2];
BEGIN
	-- linstrings
	IF simplify_patteren = 10 THEN 
		num_points := ST_NumPoints(edge);
		IF ST_NumPoints(edge) > 4 THEN
			point_array_line[0] := ST_StartPoint(edge) ;
			point_array_line[1] := ST_EndPoint(edge) ;
			new_edge := ST_MakeLine(point_array_line);	
		END IF;
	-- linestring
	ELSIF simplify_patteren = 11 THEN 
		num_points := ST_NumPoints(edge);
		IF ST_NumPoints(edge) > 4 THEN
			new_edge := ST_SimplifyPreserveTopology(edge,0.01);
	 	END IF;
	ELSIF simplify_patteren = 20 THEN 
		num_points := ST_NumPoints(edge);
		IF ST_NumPoints(edge) > 4 THEN
			new_edge := ST_SimplifyPreserveTopology(edge,0.01);
	 	END IF;
	END IF;

	RETURN new_edge;

END;
$$ LANGUAGE plpgsql IMMUTABLE;


		
-- Default value for Ar5LinjeV
CREATE OR REPLACE FUNCTION topo_rein.get_rein_felles_egenskaper_linje(localid_in int) 
RETURNS topo_rein.sosi_felles_egenskaper AS $$DECLARE

DECLARE 

res topo_rein.sosi_felles_egenskaper;
res_kvalitet topo_rein.sosi_kvalitet;
res_sosi_registreringsversjon topo_rein.sosi_registreringsversjon;


BEGIN

-- TODO find out how to default values to declare
	
res.forstedatafangstdato := now();
-- res.informasjon 
-- res.kopidata

res.identifikasjon := 'NO_LDIR_REINDRIFT_VAARBEITE 0 ' || localid_in;

-- TODO find out what malemetode to use
res_kvalitet.maalemetode := 99;
res_kvalitet.noyaktighet := 200;
res_kvalitet.synbarhet := 0;
res.kvalitet = res_kvalitet;

-- TODO find if we should use oppdaterings dato the same way as QMS
-- res.oppdateringsdato only used by QMS

res.verifiseringsdato := now(); 

-- TODO that will be a input from the user
-- How to handle lines that crosses municipality
res.opphav := 'komnr'; 

--res.prosess_historie

-- TODO find out if we can have different values in ar5 for this
res_sosi_registreringsversjon.versjon := '4.5';
-- Is alvays ar5 because we use attributtes for different types
-- res_sosi_registreringsversjon.produkt
res.registreringsversjon := res_sosi_registreringsversjon;

-- TODO find out what to with informasjon
-- res.informasjon 

res.verifiseringsdato := now();

	
return res;

END;
$$ LANGUAGE plpgsql STABLE;
-- to use IMMUTABLE we to add date as parameter

-- select topo_rein.get_rein_felles_egenskaper_linje();

-- Default value for Ar5FlateV
CREATE OR REPLACE FUNCTION topo_rein.get_rein_felles_egenskaper_flate(localid_in int) 
RETURNS topo_rein.sosi_felles_egenskaper AS $$DECLARE

DECLARE 

res topo_rein.sosi_felles_egenskaper;
res_kvalitet topo_rein.sosi_kvalitet;
res_sosi_registreringsversjon topo_rein.sosi_registreringsversjon;


BEGIN

-- TODO find out how to default values to declare
	
res.forstedatafangstdato := now();
-- res.informasjon 
-- res.kopidata

-- TODO find out what malemetode to use
res_kvalitet.maalemetode := 99;
res_kvalitet.noyaktighet := 0;
res_kvalitet.synbarhet := 0;
res.kvalitet = res_kvalitet;

-- TODO find if we should use oppdaterings dato the same way as QMS
-- res.oppdateringsdato only used by QMS

res.verifiseringsdato := now(); 

-- TODO that will be a input from the user
-- How to handle lines that crosses municipality
res.opphav := 'komnr'; 

--res.prosess_historie

-- TODO find out if we can have different values in ar5 for this
res_sosi_registreringsversjon.versjon := '4.5';
-- Is alvays ar5 because we use attributtes for different types
-- res_sosi_registreringsversjon.produkt
res.registreringsversjon := res_sosi_registreringsversjon;

-- TODO find out what to with informasjon
-- res.informasjon 

res.verifiseringsdato := now();

	
return res;

END;
$$ LANGUAGE plpgsql STABLE;
-- to use IMMUTABLE we to add date as parameter

-- select topo_rein.get_rein_felles_egenskaper_flate(100);
-- select topo_rein.get_rein_felles_egenskaper_linje(100000);
 -- Return a set of identifiers for edges within
-- the union of given faces
CREATE OR REPLACE FUNCTION topo_rein.get_edges_within_faces(faces int[], border_topo_info topo_update.input_meta_info  )
RETURNS int[]
AS $$DECLARE

-- holds dynamic sql to be able to use the same code for different
command_string text;

result int[];

BEGIN

command_string := FORMAT('SELECT array_agg(e.edge_id)
  FROM %I.edge_data e,
  %I.relation re
  WHERE e.left_face = ANY ( %L )
    AND e.right_face = ANY ( %L )
    AND e.edge_id = re.element_id 
    AND re.layer_id =  %L',
   border_topo_info.topology_name,
   border_topo_info.topology_name,
    faces,
    faces,
  	border_topo_info.border_layer_id
	);
	-- RAISE NOTICE '%', command_string;
EXECUTE command_string INTO result;
    
RETURN result;
		
END;
$$ LANGUAGE plpgsql;
-- Return a set of identifiers for edges within a surface TopoGeometry
--
--{
CREATE OR REPLACE FUNCTION topo_rein.get_edges_within_toposurface(tg TopoGeometry,border_topo_info topo_update.input_meta_info)
RETURNS int[]
AS $$DECLARE

-- holds dynamic sql to be able to use the same code for different
command_string text;

result int[];

BEGIN

command_string := FORMAT('WITH tgdata as (
    select array_agg(r.element_id) as faces
    from %I.relation r
    where topogeo_id = id($1)
      and layer_id = layer_id($1)
      and element_type = 3 -- a face
  )
  SELECT array_agg(e.edge_id)
  FROM %I.edge_data e, tgdata t
  WHERE e.left_face = ANY ( t.faces )
    AND e.right_face = ANY ( t.faces )',
   border_topo_info.topology_name,
   border_topo_info.topology_name
   
	);
	-- RAISE NOTICE '%', command_string;
EXECUTE command_string INTO result;
    
RETURN result;

		
END;
$$ LANGUAGE plpgsql;

-- used to get felles egenskaper for with all values
-- including måle metode

CREATE OR REPLACE FUNCTION topo_rein.get_rein_felles_egenskaper(felles topo_rein.simple_sosi_felles_egenskaper ) 
RETURNS topo_rein.sosi_felles_egenskaper AS $$DECLARE

DECLARE 

res topo_rein.sosi_felles_egenskaper ;
res_kvalitet topo_rein.sosi_kvalitet;


BEGIN

res := topo_rein.get_rein_felles_egenskaper_flate(felles);
	

res_kvalitet.maalemetode := (felles)."fellesegenskaper.kvalitet.maalemetode";
--res_kvalitet.noyaktighet := 200;
--res_kvalitet.synbarhet := 0;
res.kvalitet = res_kvalitet;
return res;

END;
$$ LANGUAGE plpgsql IMMUTABLE ;


-- used to get felles egenskaper for where we don't use målemetode
CREATE OR REPLACE FUNCTION topo_rein.get_rein_felles_egenskaper_flate(felles topo_rein.simple_sosi_felles_egenskaper ) 
RETURNS topo_rein.sosi_felles_egenskaper AS $$DECLARE

DECLARE 

res topo_rein.sosi_felles_egenskaper;
res_kvalitet topo_rein.sosi_kvalitet;
res_sosi_registreringsversjon topo_rein.sosi_registreringsversjon;


BEGIN

-- TODO find out how to default values to declare
	
-- res.forstedatafangstdato := now();
-- res.informasjon 
-- res.kopidata

-- res.identifikasjon := 'NO_LDIR_REINDRIFT_VAARBEITE 0 ' || localid_in;

	
-- if we have a value for felles_egenskaper.verifiseringsdato or else use current date
res.verifiseringsdato :=  (felles)."fellesegenskaper.verifiseringsdato";
IF res.verifiseringsdato is null THEN
	res.verifiseringsdato :=  current_date;
END IF;

-- if we have a value for felles_egenskaper.forstedatafangstdato or else use verifiseringsdato
res.forstedatafangstdato :=  (felles)."fellesegenskaper.forstedatafangstdato";
IF res.forstedatafangstdato is null THEN
	res.forstedatafangstdato :=  res.verifiseringsdato;
END IF;

-- if we have a value for oppdateringsdato or else use current date
-- The only time will have values for oppdateringsdato is when we transfer data from simple feature.
-- From the client this should always be null
-- TODO Or should er here always use current_date
--res.oppdateringsdato :=  (felles)."fellesegenskaper.oppdateringsdato";
--IF res.oppdateringsdato is null THEN
	res.oppdateringsdato :=  current_date;
--END IF;

-- TODO verufy that we always should reset oppdaterings dato
-- If this is the case we may remove oppdateringsdato

-- TODO that will be a input from the user
-- How to handle lines that crosses municipality
res.opphav :=  (felles)."fellesegenskaper.opphav";

--res.prosess_historie

-- TODO find out if we can have different values in ar5 for this
--res_sosi_registreringsversjon.versjon := '4.5';
-- Is alvays ar5 because we use attributtes for different types
-- res_sosi_registreringsversjon.produkt
--res.registreringsversjon := res_sosi_registreringsversjon;

-- TODO find out what to with informasjon
-- res.informasjon 

return res;

END;
$$ LANGUAGE plpgsql IMMUTABLE ;



-- used to get felles egenskaper when it is a update
-- we then only update verifiseringsdato, opphav
CREATE OR REPLACE FUNCTION topo_rein.get_rein_felles_egenskaper_update(
res topo_rein.sosi_felles_egenskaper,
felles topo_rein.sosi_felles_egenskaper) 
RETURNS topo_rein.sosi_felles_egenskaper AS $$DECLARE

DECLARE 

BEGIN

	
-- if we have a value for felles_egenskaper.verifiseringsdato or else use current date
res.verifiseringsdato :=  (felles)."verifiseringsdato";
IF res.verifiseringsdato is null THEN
	res.verifiseringsdato :=  current_date;
END IF;

res.oppdateringsdato :=  current_date;

res.opphav :=  (felles)."opphav";


return res;

END;
$$ LANGUAGE plpgsql IMMUTABLE ;







-- Return the geom from Json and transform it to correct zone

CREATE OR REPLACE FUNCTION topo_rein.get_geom_from_json(feat json, srid_out int) 
RETURNS geometry AS $$DECLARE

DECLARE 
geom geometry;
srid int;
BEGIN

	geom := ST_GeomFromGeoJSON(feat->>'geometry');
	srid = St_Srid(geom);
	
	IF (srid_out != srid) THEN
		geom := ST_transform(geom,srid_out);
	END IF;
	
	geom := ST_SetSrid(geom,srid_out);

	RAISE NOTICE 'srid %, geom  %',   srid_out, ST_AsEWKT(geom);

	RETURN geom;

END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Find topology layer_id info for given input structure

-- DROP FUNCTION topo_update.get_linestring_no_loose_ends(topo_info topo_update.input_meta_info);

-- Get the new line string with no loose ends, where not left_face and right_phase is null


CREATE OR REPLACE FUNCTION topo_update.get_linestring_no_loose_ends(topo_info topo_update.input_meta_info, topo topogeometry) 
RETURNS geometry AS $$DECLARE
DECLARE 
edge_with_out_loose_ends geometry;
command_string text;
BEGIN

	-- create command string
	command_string := FORMAT('
	 	SELECT ST_union(ed.geom)  
		FROM 
		%1$s re,
		%2$s ed
		WHERE 
		%3$s  = re.topogeo_id AND
		re.layer_id =  topo_update.get_topo_layer_id( %4$L ) AND 
		re.element_type = %5$L AND 
		ed.edge_id = re.element_id AND
		NOT (ed.left_face = 0 AND ed.right_face = 0) AND 
		NOT (ed.left_face > 0 AND ed.right_face > 0 AND ed.left_face = ed.right_face)
		', 
		topo_info.topology_name || '.relation', -- the edge data name
		topo_info.topology_name || '.edge_data', -- the edge data name
		topo.id, -- get feature colmun name
		topo_info, -- Used to find layer_id
		topo_info.element_type -- Ser correct layer_type, 2 for egde
		
	);
		
    -- display the string
    -- RAISE NOTICE '%', command_string;

	-- execute the string
    EXECUTE command_string INTO edge_with_out_loose_ends;
		
    -- Put this together to on single line string
    -- TODO check if this is save Is this safe ???
    
	RETURN ST_LineMerge(edge_with_out_loose_ends);

END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION topo_update.get_linestring_no_loose_ends(topo_info topo_update.input_meta_info, topo topogeometry)  IS 'Get the new line string with no loose ends';


-- Find topology layer_id info for given input structure

-- DROP FUNCTION topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info);

-- Find topology layer_id info for the structure topo_update.input_meta_info

CREATE OR REPLACE FUNCTION topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info) 
RETURNS int AS $$DECLARE
DECLARE 
layer_id_res int;

-- holds dynamic sql to be able to use the same code for different
command_string text;

BEGIN

	command_string := FORMAT('SELECT layer_id 
	FROM topology.layer l, topology.topology t 
	WHERE t.name = %L AND
	t.id = l.topology_id AND
	l.schema_name = %L AND
	l.table_name = %L AND
	l.feature_column = %L',
    topo_info.topology_name,
    topo_info.layer_schema_name,
    topo_info.layer_table_name,
    topo_info.layer_feature_column
    );

	EXECUTE command_string INTO layer_id_res;
	
	return layer_id_res;

END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info)  IS ' Find topology layer_id info for the structure topo_update.input_meta_info';
-- Return the faces that are not used by any TopoGeometry
CREATE OR REPLACE FUNCTION topo_rein.get_unused_faces(surface_topo_info topo_update.input_meta_info)
RETURNS setof int
AS $$DECLARE

-- holds dynamic sql to be able to use the same code for different
command_string text;

BEGIN

command_string := FORMAT('
    SELECT f.face_id as faces
    FROM
      %I.face f
    EXCEPT
    SELECT r.element_id
    FROM
      %I.relation r,
      topology.layer l
    WHERE r.layer_id = l.layer_id 
      and l.layer_id = %L
      and l.level = 0 -- non hierarchical
      and r.element_type = 3 -- a face',
   surface_topo_info.topology_name,
   surface_topo_info.topology_name,
   surface_topo_info.border_layer_id);

	-- RAISE NOTICE '%', command_string;
    RETURN QUERY EXECUTE  command_string;

END;
$$ LANGUAGE plpgsql;

-- Return a set of identifiers for edges that are not covered
-- by any surface TopoGeometry
-- DROP FUNCTION topo_update.has_linestring_loose_ends(topo_info topo_update.input_meta_info, _tbl regclass) 

-- Return 1 if this line has no loose ends or the lines are not part of any surface
-- test the function with goven structure


CREATE OR REPLACE FUNCTION topo_update.has_linestring_loose_ends(topo_info topo_update.input_meta_info, topo topogeometry) 
RETURNS int AS $$DECLARE
DECLARE 
has_loose_ends int;
command_string text;
BEGIN

	-- create command string
	command_string := FORMAT('
	 	SELECT (EXISTS (SELECT 1  
		FROM 
		%1$s re,
		%2$s ed
		WHERE 
		%3$s  = re.topogeo_id AND
		re.layer_id =  topo_update.get_topo_layer_id( %4$L ) AND 
		re.element_type = %5$L AND 
		ed.edge_id = re.element_id AND
		(
		(ed.left_face = 0 AND ed.right_face = 0) OR
		(ed.left_face > 0 AND ed.right_face > 0 AND ed.left_face = ed.right_face)
		)
		))::int', 
		topo_info.topology_name || '.relation', -- the edge data name
		topo_info.topology_name || '.edge_data', -- the edge data name
		topo.id, -- get feature colmun name
		topo_info, -- Used to find layer_id
		topo_info.element_type -- Ser correct layer_type, 2 for egde
	);
		
    -- display the string
    -- RAISE NOTICE '%', command_string;

    -- execute the string
    EXECUTE command_string INTO has_loose_ends;
		
	RETURN has_loose_ends;

END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION  topo_update.has_linestring_loose_ends(topo_info topo_update.input_meta_info, topo topogeometry)  IS 'Return 1 if thIs line has loose ends';


-- from http://stackoverflow.com/questions/18209625/how-do-i-modify-fields-inside-the-new-postgresql-json-datatype
-- since we dont have postgres 9.5
CREATE OR REPLACE FUNCTION topo_update.json_object_set_keys(
  "json"          json,
  "keys_to_set"   TEXT[],
  "values_to_set" anyarray
)
  RETURNS json
  LANGUAGE sql
  IMMUTABLE
  STRICT
AS $function$
SELECT concat('{', string_agg(to_json("key") || ':' || "value", ','), '}')::json
  FROM (SELECT *
          FROM json_each("json")
         WHERE "key" <> ALL ("keys_to_set")
         UNION ALL
        SELECT DISTINCT ON ("keys_to_set"["index"])
               "keys_to_set"["index"],
               CASE
                 WHEN "values_to_set"["index"] IS NULL THEN 'null'::json
                 ELSE to_json("values_to_set"["index"])
               END
          FROM generate_subscripts("keys_to_set", 1) AS "keys"("index")
          JOIN generate_subscripts("values_to_set", 1) AS "values"("index")
         USING ("index")) AS "fields"
$function$;

-- This is a simple helper function that createa a common dataholder object based on input objects
-- TODO splitt in different objects dependig we don't send unused parameters around
-- snap_tolerance float8 is optinal if not given default is 0

CREATE OR REPLACE FUNCTION topo_update.make_input_meta_info(layer_schema text, layer_table text, layer_column text,
  snap_tolerance float8 = 0)
RETURNS topo_update.input_meta_info AS $$
DECLARE


topo_info topo_update.input_meta_info ;

BEGIN
	
	
	-- Read parameters
	topo_info.layer_schema_name := layer_schema;
	topo_info.layer_table_name := layer_table;
	topo_info.layer_feature_column := layer_column;
	topo_info.snap_tolerance := snap_tolerance;

-- Find out topology name and element_type from layer identifier
  BEGIN
    SELECT t.name, l.feature_type
    FROM topology.topology t, topology.layer l
    WHERE l.level = 0 -- need be primitive
      AND l.schema_name = topo_info.layer_schema_name
      AND l.table_name = topo_info.layer_table_name
      AND l.feature_column = topo_info.layer_feature_column
      AND t.id = l.topology_id
    INTO STRICT topo_info.topology_name,
                topo_info.element_type;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE EXCEPTION 'Cannot find info for primitive layer %.%.%',
        topo_info.layer_schema_name,
        topo_info.layer_table_name,
        topo_info.layer_feature_column;
  END;

	-- find border layer id
	topo_info.border_layer_id := topo_update.get_topo_layer_id(topo_info);

    return topo_info;
END;
$$ LANGUAGE plpgsql STABLE;

-- find one row that intersecst
-- TODO find teh one with loongts egde

-- DROP FUNCTION IF EXISTS topo_update.touches(_new_topo_objects regclass,id_to_check int) ;

CREATE OR REPLACE FUNCTION topo_update.touches(_new_topo_objects regclass, id_to_check int,surface_topo_info topo_update.input_meta_info) 
RETURNS int AS $$DECLARE
DECLARE 
command_string text;
res int;
BEGIN


-- TODO rewrite code

CREATE TEMP TABLE IF NOT EXISTS idlist_temp(id_t int[]);

--IF EXISTS (SELECT * FROM pg_tables WHERE tablename='idlist_temp') THEN	
	TRUNCATE TABLE idlist_temp;
--ELSE 
--	CREATE TEMP TABLE  idlist_temp(id_t int[]);
--END IF;

--DROP TABLE IF EXISTS idlist_temp;
--CREATE TEMP TABLE  idlist_temp(id_t int[]);

command_string := format('INSERT INTO idlist_temp(id_t) 
SELECT id_list as id_t FROM 
	( SELECT array_agg( object_id) id_list, count(*) as antall
	  FROM (
	  WITH
	  faces AS (
	    SELECT (GetTopoGeomElements(%s))[1] face_id, id AS object_id FROM (
	      SELECT %s, id from  %s 
	    ) foo
	  ),
	  ary AS ( 
	    SELECT array_agg(face_id) ids, face_id, object_id FROM faces
	    GROUP BY face_id, object_id
	  )
	  SELECT object_id, face_id, e.edge_id 
	  FROM %I.edge e, ary f
	  WHERE ( left_face = any (f.ids) and not right_face = any (f.ids) )
	     OR ( right_face = any (f.ids) and not left_face = any (f.ids) )
	  ) AS t
	  GROUP BY edge_id
  	) AS r
WHERE antall > 1
AND id_list[1] != id_list[2]
AND (id_list[1] = %L OR id_list[2] = %L)
ORDER BY id_t',
surface_topo_info.layer_feature_column,
surface_topo_info.layer_feature_column,
_new_topo_objects,
surface_topo_info.topology_name,
id_to_check, 
id_to_check);

RAISE NOTICE 'command_string %',  command_string;

EXECUTE command_string;

DROP TABLE IF EXISTS idlist;

CREATE TEMP TABLE  idlist(id int);

INSERT INTO idlist(id) SELECT id_t[1] AS id FROM idlist_temp WHERE id_to_check != id_t[1];
INSERT INTO idlist(id) SELECT id_t[2] AS id FROM idlist_temp WHERE id_to_check != id_t[2];

SELECT id FROM idlist limit 1 into res;

RETURN res;

END;
$$ LANGUAGE plpgsql;


--SELECT * FROM topo_update.touches('topo_rein.arstidsbeite_var_flate',10);
-- Return a topojson document with the contents of the query results
-- topojson specs:
-- https://github.com/mbostock/topojson-specification/blob/master/README.md
--
-- NOTE: will use TopoGeometry identifier as the feature identifier
--
--{
CREATE OR REPLACE FUNCTION topo_rein.query_to_topojson(query text, srid_out int, maxdecimaldigits int, simplify_patteren int)
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

  outary := ARRAY[
    '{"type":"Topology", "crs":{"type":"name","properties":{"name":"',
    crs,
  '"}}'];

  CREATE TEMP TABLE topo_rein_topojson_edgemap
      (arc_id serial primary key, edge_id int);
  CREATE INDEX ON topo_rein_topojson_edgemap(edge_id);

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
    DROP TABLE topo_rein_topojson_edgemap;
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
      tmptext := AsTopoJSON(rec.obj, 'topo_rein_topojson_edgemap');
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

  sql := 'SELECT array_agg(ST_AsGeoJSON(' ||
      'ST_transform(topo_update.get_adjusted_edge(e.geom,$1),$2),$3' ||
--      'ST_transform(e.geom,$1),$2' ||
      ')::json->>''coordinates'' ' ||
      'ORDER BY m.arc_id) FROM topo_rein_topojson_edgemap m ' ||
      'INNER JOIN ' || quote_ident(toponame) || '.edge e ' ||
      'ON (e.edge_id = m.edge_id)';
  --RAISE DEBUG '%', sql;
  EXECUTE sql USING simplify_patteren,srid_out,maxdecimaldigits INTO objary;

  outary = outary || ']'::text || '}'::text || '}'::text;

  outary = outary || ',"arcs": ['::text
                  || array_to_string(objary, ',')
                  || ']'::text;

  outary = outary || '}'::text;


  --RAISE DEBUG '%', array_to_string(outary, '');
  
  DROP TABLE topo_rein_topojson_edgemap;
  
  json_result = array_to_string(outary, '')::varchar;
  RETURN json_result;

END;
$$ LANGUAGE 'plpgsql' VOLATILE;

--\timing
--select length(topo_rein.query_to_topojson('select distinct a.* from topo_rein.arstidsbeite_var_topojson_flate_v a',32633,0,0));
-- Create new new surface object after after the new valid intersect line is dranw

--DROP FUNCTION topo_update.create_edge_surfaces(surface_topo_info topo_update.input_meta_info, border_topo_info topo_update.input_meta_info , new_border_data topogeometry, valid_user_geometry geometry, felles_egenskaper_flate topo_rein.sosi_felles_egenskaper) cascade;

-- TODO make general 


CREATE OR REPLACE FUNCTION topo_update.create_edge_surfaces(surface_topo_info topo_update.input_meta_info, border_topo_info topo_update.input_meta_info , new_border_data topogeometry, valid_user_geometry geometry, felles_egenskaper_flate topo_rein.sosi_felles_egenskaper) 
RETURNS SETOF topo_update.topogeometry_def AS $$
DECLARE

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this surface layer id will picked up by input parameters
surface_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- holds the num rows affected when needed
num_rows_affected int;

-- number of rows to delete from org table
num_rows_to_delete int;

-- used for logging
add_debug_tables int = 0;

-- used for looping
rec RECORD;

-- used for creating new topo objects
new_surface_topo topogeometry;

-- the closed geom if the instring is closed
valid_closed_user_geometry geometry;

BEGIN
	
	-- find border layer id
	border_layer_id := border_topo_info.border_layer_id;
	RAISE NOTICE 'border_layer_id   %',  border_layer_id ;
	
	-- find surface layer id
	surface_layer_id := surface_topo_info.border_layer_id;
	RAISE NOTICE 'surface_layer_id   %',  surface_layer_id ;
	
	RAISE NOTICE 'The topo objected added  %, isClosed %',  new_border_data, St_IsClosed(valid_user_geometry);
	
	IF St_IsClosed(valid_user_geometry) THEN
		valid_closed_user_geometry = ST_MakePolygon(valid_user_geometry);
	END IF;
	
	
	
	-------------------- Surface ---------------------------------

	-- find new facec that needs to be creted
	DROP TABLE IF EXISTS new_faces; 
	CREATE TEMP TABLE new_faces(face_id int);

	-- find left faces
	command_string := FORMAT('INSERT INTO new_faces(face_id) 
	SELECT DISTINCT(fa.face_id) as face_id
	FROM 
	%I.relation re,
	%I.edge_data ed,
	%I.face fa
	WHERE 
	%L = re.topogeo_id AND
    re.layer_id =  %L AND 
    re.element_type = 2 AND  -- TODO use variable element_type_edge=2
    ed.edge_id = re.element_id AND
    fa.face_id=ed.left_face AND -- How do I know if a should use left or right ?? 
    fa.mbr IS NOT NULL',
    border_topo_info.topology_name,
    border_topo_info.topology_name,
    border_topo_info.topology_name,
    new_border_data.id,
    border_layer_id);
    
	-- display the string
    -- RAISE NOTICE '%', command_string;
	-- execute the string
    EXECUTE command_string;

    
    GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of face objects found on the left side  % ',  num_rows_affected;

    -- find right faces
	command_string := FORMAT('INSERT INTO new_faces(face_id) 
	SELECT DISTINCT(fa.face_id) as face_id
	FROM 
	%I.relation re,
	%I.edge_data ed,
	%I.face fa
	WHERE 
	%L = re.topogeo_id AND
    re.layer_id =  %L AND 
    re.element_type = 2 AND  -- TODO use variable element_type_edge=2
    ed.edge_id = re.element_id AND
    fa.face_id=ed.right_face AND -- How do I know if a should use left or right ?? 
    fa.mbr IS NOT NULL',
    border_topo_info.topology_name,
    border_topo_info.topology_name,
    border_topo_info.topology_name,
    new_border_data.id,
    border_layer_id);
    
	-- display the string
    -- RAISE NOTICE '%', command_string;
	-- execute the string
    EXECUTE command_string;



    GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of face objects found on the right side  % ',  num_rows_affected;

	DROP TABLE IF EXISTS new_surface_data; 
	-- Create a temp table to hold new surface data
	CREATE TEMP TABLE new_surface_data(surface_topo topogeometry, felles_egenskaper_flate topo_rein.sosi_felles_egenskaper);
	-- create surface geometry if a surface exits for the left side

	-- if input is a closed ring only geneate objects for faces


	FOR rec IN SELECT distinct face_id FROM new_faces
	LOOP
		--IF  NOT EXISTS(SELECT 1 FROM used_topo_faces WHERE face_id = rec.face_id) AND
		--EXISTS(SELECT 1 FROM valid_topo_faces WHERE face_id = rec.face_id) THEN 
		-- Test if this surface already used by another topo object
			new_surface_topo := topology.CreateTopoGeom(surface_topo_info.topology_name,surface_topo_info.element_type,surface_layer_id,topology.TopoElementArray_Agg(ARRAY[rec.face_id,3])  );
			-- if not null
			IF new_surface_topo IS NOT NULL THEN
			
				-- check if this topo already exist
				-- TODO find out this chck is needed then we can only check on id 
	--			IF NOT EXISTS(SELECT 1 FROM topo_rein.arstidsbeite_var_flate WHERE (omrade).id = (new_surface_topo).id) AND
	--			   NOT EXISTS(SELECT 1 FROM new_surface_data WHERE (surface_topo).id = (new_surface_topo).id)
	--			THEN
				-- Could we here have used topplogical equality 
				IF valid_closed_user_geometry IS NOT NULL AND NOT ST_Intersects(valid_closed_user_geometry,ST_PointOnSurface (new_surface_topo::geometry)) THEN
					RAISE NOTICE 'Use new topo object % , but this new surface is outside user input %',  ST_asText(valid_closed_user_geometry), ST_AsText(ST_PointOnSurface (new_surface_topo::geometry));
				ELSE
					RAISE NOTICE 'Use new topo object % for face % created from user input %',  new_surface_topo, rec.face_id, new_border_data;
				END IF;
				
				INSERT INTO new_surface_data(surface_topo,felles_egenskaper_flate) VALUES(new_surface_topo,felles_egenskaper_flate);

			END IF;
		--END IF;
    END LOOP;

    
	-- We now objects that are missing attribute values that should be inheretaded from mother object.

		
	RETURN QUERY SELECT a.surface_topo::topogeometry as t FROM new_surface_data a;
	
END;
$$ LANGUAGE plpgsql;



-- SELECT * FROM topo_update.create_edge_surfaces((select topo_update.create_surface_edge('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.55375, 5.70152 58.55373, 5.70182 58.55131)'))::topogeometry)
		
-- this creates a valid edge based on the surface that alreday exits
-- the geometry in must be in the same coord system as the exting edge layer
-- return a set valid edges that may used be used by topo object later
-- the egdes may be old ones or new ones

CREATE OR REPLACE FUNCTION topo_update.create_surface_edge(geo_in geometry, 
border_topo_info topo_update.input_meta_info) 
RETURNS topogeometry   AS $$DECLARE

-- result 
new_border_data topogeometry;

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

command_result text;


BEGIN
	
	
	-- Holds of the id of rows inserted, we need this to keep track rows added to the main table
	CREATE TEMP TABLE IF NOT EXISTS ids_added_border_layer ( id integer );

	-- get new topo border data.
	new_border_data := topology.toTopoGeom(geo_in, border_topo_info.topology_name, border_topo_info.border_layer_id, border_topo_info.snap_tolerance); 

	-- Test if there are any loose ends	
	-- TODO use topo object as input and not a object, since will bee one single topo object,
	-- TOTO add a test if this is a linestring or not
	-- TODO add a tes if this has no loose ends
	-- but we may need line attributes then it's easier table as a parameter
 
	IF topo_update.has_linestring_loose_ends(border_topo_info, new_border_data)  = 1 THEN
		-- Clean up loose ends	and ends that do not participate in surface
	
		-- get the new line string with no loose ends
		-- TODO we may here also use a topo object as a parameter, but that depends on if we need the the attributes 
		-- for to this line later 
		edge_with_out_loose_ends := topo_update.get_linestring_no_loose_ends(border_topo_info, new_border_data);
		
		
		
		-- get a copy of the relation data we added because we will need this for delete later
		command_string := FORMAT('
			CREATE TEMP TABLE old_relation AS ( 
			SELECT re.* 
			FROM 
			%1$s re,
			%2$s ed
			WHERE 
			%3s  = re.topogeo_id AND
			re.layer_id =  %4$L AND 
			re.element_type = %5$L AND 
			ed.edge_id = re.element_id)',
			border_topo_info.topology_name || '.relation', -- the edge data name
			border_topo_info.topology_name || '.edge_data', -- the edge data name
			new_border_data.id, -- get feature colmun name
			border_topo_info.border_layer_id,
			border_topo_info.element_type
		);
	    -- display the string
	    -- RAISE NOTICE '%', command_string;
		-- execute the string
	    EXECUTE command_string;

		-- clear out this new topo object, because we need to recreate it we the new linestring 
		PERFORM topology.clearTopoGeom(new_border_data);

		-- remove all edges and relations created with first topo object
		command_string := FORMAT('
			SELECT ST_RemEdgeModFace(%1$L, ed.edge_id)
			FROM 
			old_relation re,
			%2$s ed
			WHERE 
			re.layer_id =  %3$L AND 
			re.element_type = %4$L AND 
			ed.edge_id = re.element_id AND
			(
			(ed.left_face = 0 AND ed.right_face = 0) OR 
			(ed.left_face > 0 AND ed.right_face > 0 AND ed.left_face = ed.right_face)
			)
			',
			border_topo_info.topology_name,
			border_topo_info.topology_name || '.edge_data', -- the edge data name
			border_topo_info.border_layer_id,
			border_topo_info.element_type
		);

	    -- RAISE NOTICE '%', command_string;

	    EXECUTE command_string;
		--We are done clean up loose ends from the first relations loose ends

	    
		RAISE NOTICE 'edge_with_out_loose_ends ::::   %',  ST_AsText(edge_with_out_loose_ends);
		
	    
	    DROP TABLE IF EXISTS edge_with_out_loose_ends ;
    	CREATE TEMP TABLE edge_with_out_loose_ends  AS (SELECT edge_with_out_loose_ends as geom);
		
	    
    	DROP TABLE IF EXISTS end_points ;
    	-- Create a temp table to hold new surface data
		CREATE TEMP TABLE end_points  AS (SELECT ST_StartPoint(edge_with_out_loose_ends) as geom);
		INSERT INTO end_points(geom) SELECT ST_EndPoint(edge_with_out_loose_ends) as geom;

		command_string := FORMAT('SELECT 1  
                        FROM 
                        %I.relation re1,
                        %I.relation re2,
                        %I.edge_data ed1,
                        %I.edge_data ed2
                        WHERE 
                    re1.layer_id =  %L AND 
                    re1.element_type = %L AND  
                    ed1.edge_id = re1.element_id AND
                    ST_touches(ed1.geom,  ST_StartPoint(%L)) AND
                    re2.layer_id =  %L AND 
                    re2.element_type = %L AND  -- TODO use variable element_type_edge=2
                    ed2.edge_id = re2.element_id AND
                    ST_touches(ed2.geom,  ST_EndPoint(%L))
					limit 1',
                        border_topo_info.topology_name,
                        border_topo_info.topology_name,
                        border_topo_info.topology_name,
                        border_topo_info.topology_name,
                        border_topo_info.border_layer_id,
                        border_topo_info.element_type,
                        edge_with_out_loose_ends,
                        border_topo_info.border_layer_id,
                        border_topo_info.element_type,
                        edge_with_out_loose_ends
                );

       	RAISE NOTICE 'command_string is %',  command_string;

        EXECUTE command_string into command_result;
		
        
		IF command_result IS NOT NULL THEN

	 	RAISE NOTICE 'Ok surface cutting line to add ----------------------';

		-- create new topo object with noe loose into temp table.
		new_border_data := topology.toTopoGeom(edge_with_out_loose_ends, border_topo_info.topology_name, border_topo_info.border_layer_id, border_topo_info.snap_tolerance);
		
		ELSE 
			-- remove all because this is not valid line at all
			command_string := FORMAT('
				SELECT ST_RemEdgeModFace(%1$L, ed.edge_id)
				FROM 
				old_relation re,
				%2$s ed
				WHERE 
				re.layer_id =  %3$L AND 
				re.element_type = %4$L AND 
				ed.edge_id = re.element_id',
				border_topo_info.topology_name,
				border_topo_info.topology_name || '.edge_data', -- the edge data name
				border_topo_info.border_layer_id,
				border_topo_info.element_type
			);
	
		    -- RAISE NOTICE '%', command_string;
	
		    EXECUTE command_string;
			--We are done clean up loose ends from the first relations loose ends

			RAISE NOTICE 'NOT Ok surface cutting line to add ----------------';

			END IF;
	
			-- TODO add test if the lines are new or not
			-- drop old temp dara relation
			DROP TABLE old_relation;
	
	END IF;

	RETURN new_border_data;

END;
$$ LANGUAGE plpgsql;



-- select topo_update.create_surface_edge('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.55375, 5.70152 58.55373, 5.70182 58.55131)');


-- This is a common method to parse all input data
-- It returns a struture that is adjusted reindrift that depends on sosi felles eganskaper

CREATE OR REPLACE FUNCTION  topo_update.handle_input_json_props(client_json_feature json,  server_json_feature json, srid_out int) 
RETURNS topo_update.json_input_structure AS $$DECLARE

DECLARE 
-- holds the value for felles egenskaper from input
simple_sosi_felles_egenskaper topo_rein.simple_sosi_felles_egenskaper;

-- JSON that is sent from the cleint
client_json_properties json;

-- JSON produced on the server side
server_json_properties json;

-- Keys in the server JSON properties
server_json_keys text;
keys_to_set   TEXT[];
values_to_set json[];

-- holde the computed value for json input reday to use
json_input_structure topo_update.json_input_structure;  

BEGIN

	RAISE NOTICE 'client_json_feature %, server_json_feature %',  client_json_feature, server_json_feature ;
	
	-- geth the geometry may be null
	json_input_structure.input_geo := topo_rein.get_geom_from_json(client_json_feature::json,4258);

	-- get json from the client
	client_json_properties := to_json(client_json_feature::json->'properties');
	RAISE NOTICE 'client_json_properties %',  client_json_properties ;
	
	-- get the json from the serrver, may be null
	IF server_json_feature IS NOT NULL THEN
		server_json_properties := to_json(server_json_feature::json->'properties');
	  	RAISE NOTICE 'server_json_properties  % ',  server_json_properties ;
	
		-- overwrite client JSON properties with server property values
	  	SELECT array_agg("key"),array_agg("value")  INTO keys_to_set,values_to_set
		FROM json_each(server_json_properties) WHERE "value"::text != 'null';
		client_json_properties := topo_update.json_object_set_keys(client_json_properties, keys_to_set, values_to_set);
		RAISE NOTICE 'json_properties after update  %',  client_json_properties ;
	END IF;

	json_input_structure.json_properties := client_json_properties;
	
	-- This maps from the simple format used on the client 
	-- Because the client do not support Postgres user defined types like we have used in  topo_rein.sosi_felles_egenskaper;
	-- First append the info from the client properties, only properties that maps to valid names in topo_rein.simple_sosi_felles_egenskaper will be used.
	simple_sosi_felles_egenskaper := json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,client_json_properties );

	-- Here we map from simple properties to topo_rein.sosi_felles_egenskaper for line an point objects
	json_input_structure.sosi_felles_egenskaper := topo_rein.get_rein_felles_egenskaper(simple_sosi_felles_egenskaper);
	
	-- Here we get info for the surface objects
   	json_input_structure.sosi_felles_egenskaper_flate := topo_rein.get_rein_felles_egenskaper_flate(simple_sosi_felles_egenskaper);
	
	RAISE NOTICE 'felles_egenskaper_sosi  %',  json_input_structure.sosi_felles_egenskaper;

	RETURN json_input_structure;

END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- apply the list of new surfaces to the exting list of object
-- pick values from objects close to an so on
-- return the id's of the rows affected

-- DROP FUNCTION topo_update.update_domain_surface_layer(_new_topo_objects regclass) cascade;


CREATE OR REPLACE FUNCTION topo_update.update_domain_surface_layer(surface_topo_info topo_update.input_meta_info, border_topo_info topo_update.input_meta_info, valid_user_geometry geometry,  _new_topo_objects regclass) 
RETURNS SETOF topo_update.topogeometry_def AS $$
DECLARE

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this surface layer id will picked up by input parameters
surface_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- holds the num rows affected when needed
num_rows_affected int;

-- number of rows to delete from org table
num_rows_to_delete int;

-- The border topology
new_border_data topogeometry;

-- used for logging
add_debug_tables int = 0;

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the target table
update_fields text[];

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the temp table
update_fields_t text[];

-- String surface layer name
surface_layer_name text;

-- the closed geom if the instring is closed
valid_closed_user_geometry geometry = null;


BEGIN

	-- find border layer id
	border_layer_id := border_topo_info.border_layer_id;
	RAISE NOTICE 'topo_update.update_domain_surface_layer border_layer_id   %',  border_layer_id ;
	
	-- find surface layer id
	surface_layer_id := surface_topo_info.border_layer_id;
	RAISE NOTICE 'topo_update.update_domain_surface_layer surface_layer_id   %',  surface_layer_id ;

	surface_layer_name := surface_topo_info.layer_schema_name || '.' || surface_topo_info.layer_table_name;

	-- check if this is closed polygon drawn by the user 
	-- if it's a closed polygon the only surface inside this polygon should be affected
	IF St_IsClosed(valid_user_geometry) THEN
		valid_closed_user_geometry = ST_MakePolygon(valid_user_geometry);
	END IF;

	-- get the data into a new tmp table
	DROP TABLE IF EXISTS new_surface_data; 

	
	EXECUTE format('CREATE TEMP TABLE new_surface_data AS (SELECT * FROM %s)', _new_topo_objects);
	ALTER TABLE new_surface_data ADD COLUMN id_foo SERIAL PRIMARY KEY;
	
	DROP TABLE IF EXISTS old_surface_data; 
	-- Find out if any old topo objects overlaps with this new objects using the relation table
	-- by using the surface objects owned by the both the new objects and the exting one
	-- Exlude the the new surface object created
	-- We are using the rows in new_surface_data to cpare with, this contains all the rows which are affected
	command_string :=  format('CREATE TEMP TABLE old_surface_data AS 
	(SELECT 
	re.* 
	FROM 
	%I.relation re,
	%I.relation re_tmp,
	new_surface_data new_sd
	WHERE 
	re.layer_id =%L AND
	re.element_type = 3 AND
	re.element_id = re_tmp.element_id AND
	re_tmp.layer_id = %L AND
	re_tmp.element_type = 3 AND
	(new_sd.surface_topo).id = re_tmp.topogeo_id AND
	(new_sd.surface_topo).id != re.topogeo_id)',
    surface_topo_info.topology_name,
    surface_topo_info.topology_name,
    surface_layer_id,
    surface_layer_id);  
	EXECUTE command_string;
	
	DROP TABLE IF EXISTS old_surface_data_not_in_new; 
	-- Find any old objects that are not covered totaly by new surfaces 
	-- This objets should not be deleted, but the geometry should only decrease in size.
	-- TODO Take a disscusion about how to handle attributtes in this cases
	-- TODO add a test case for this
	command_string :=  format('CREATE TEMP TABLE old_surface_data_not_in_new AS 
	(SELECT 
	re.* 
	FROM 
	%I.relation re,
	old_surface_data re_tmp
	WHERE 
	re.layer_id = %L AND
	re.element_type = 3 AND
	re.topogeo_id = re_tmp.topogeo_id AND
	re.element_id NOT IN (SELECT element_id FROM old_surface_data))',
    surface_topo_info.topology_name,
    surface_layer_id);  
	EXECUTE command_string;

	
	
	DROP TABLE IF EXISTS old_rows_be_reused;
	-- IF old_surface_data_not_in_new is empty we know that all areas are coverbed by the new objects
	-- and we can delete/resuse this objects for the new rows
	-- Get a list of old row id's used
	
	command_string :=  format('CREATE TEMP TABLE old_rows_be_reused AS 
	-- we can have distinct here 
	(SELECT distinct(old_data_row.id) FROM 
	%I.%I old_data_row,
	old_surface_data sf 
	WHERE (old_data_row.%I).id = sf.topogeo_id)',
    surface_topo_info.layer_schema_name,
    surface_topo_info.layer_table_name,
    surface_topo_info.layer_feature_column);  
	EXECUTE command_string;

	
	-- Take a copy of old attribute values because they will be needed when you add new rows.
	-- The new surfaces should pick up old values from the old row attributtes that overlaps the new rows
	-- We also have to take copy of the geometry we need that to find overlaps when we pick up old values
	-- TODO this should have been solved by using topology relation table, but I do that later 
	DROP TABLE IF EXISTS old_rows_attributes;
	
	command_string :=  format('CREATE TEMP TABLE old_rows_attributes AS 
	(SELECT distinct old_data_row.*, old_data_row.omrade::geometry as foo_geo FROM 
	%I.%I  old_data_row,
	old_surface_data sf 
	WHERE (old_data_row.%I).id = sf.topogeo_id)',
    surface_topo_info.layer_schema_name,
    surface_topo_info.layer_table_name,
    surface_topo_info.layer_feature_column);  
	EXECUTE command_string;

		-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- list topo objects to be reused
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.update_domain_surface_layer_t4;
		CREATE TABLE topo_rein.update_domain_surface_layer_t4 AS 
		( SELECT * FROM old_rows_attributes) ;
	END IF;

	
	-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- list topo objects to be reused
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.update_domain_surface_layer_t1;
		CREATE TABLE topo_rein.update_domain_surface_layer_t1 AS 
		( SELECT r.id, r.omrade::geometry AS geo, 'reuse topo objcts' || r.omrade::text AS topo
			FROM topo_rein.arstidsbeite_sommer_flate r, old_rows_be_reused reuse WHERE reuse.id = r.id) ;
	END IF;

	
	-- We now know which rows we can reuse clear out old data rom the realation table
	command_string :=  format('UPDATE %I.%I  r
	SET %I = clearTopoGeom(%I)
	FROM old_rows_be_reused reuse
	WHERE reuse.id = r.id',
    surface_topo_info.layer_schema_name,
    surface_topo_info.layer_table_name,
    surface_topo_info.layer_feature_column,
    surface_topo_info.layer_feature_column);  
	EXECUTE command_string;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'topo_update.update_domain_surface_layer Number rows to be reused in org table %',  num_rows_affected;

	-- If no rows are updated the user don't have update rights, we are using row level security
	-- We return no data and it will done a rollback
	IF num_rows_affected = 0 AND (SELECT count(*) FROM old_rows_be_reused)::int > 0 THEN
		RETURN;	
	END IF;
	
	SELECT (num_rows_affected - (SELECT count(*) FROM new_surface_data)) INTO num_rows_to_delete;

	RAISE NOTICE 'topo_update.update_domain_surface_layer Number rows to be added in org table  %',  count(*) FROM new_surface_data;

	RAISE NOTICE 'topo_update.update_domain_surface_layer Number rows to be deleted in org table  %',  num_rows_to_delete;

	-- When overwrite we may have more rows in the org table so we may need do delete the rows that are not needed 
	-- from  topo_rein.arstidsbeite_var_flate, we the just delete the left overs 
	command_string :=  format('DELETE FROM %I.%I
	WHERE ctid IN (
	SELECT r.ctid FROM
	%I.%I r,
	old_rows_be_reused reuse
	WHERE reuse.id = r.id 
	LIMIT  greatest(%L, 0))',
    surface_topo_info.layer_schema_name,
    surface_topo_info.layer_table_name,
    surface_topo_info.layer_schema_name,
    surface_topo_info.layer_table_name,
    num_rows_to_delete
  	);  
	EXECUTE command_string;
	
	
	-- Delete rows, also rows that could be reused, since I was not able to update those.
	-- TODO fix update of old rows instead of using delete
	DROP TABLE IF EXISTS new_rows_updated_in_org_table;
	
	command_string :=  format('CREATE TEMP TABLE new_rows_updated_in_org_table AS (SELECT * FROM %I.%I  limit 0);
	WITH updated AS (
		DELETE FROM %I.%I  old
		USING old_rows_be_reused reuse
		WHERE old.id = reuse.id
		returning *
	)
	INSERT INTO new_rows_updated_in_org_table(omrade)
	SELECT omrade FROM updated',
    surface_topo_info.layer_schema_name,
    surface_topo_info.layer_table_name,
    surface_topo_info.layer_schema_name,
    surface_topo_info.layer_table_name
  	);  
	EXECUTE command_string;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'topo_update.update_domain_surface_layer Number old rows to deleted in table %',  num_rows_affected;
	
	


	-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- list new objects added reused
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.update_domain_surface_layer_t2;
		CREATE TABLE topo_rein.update_domain_surface_layer_t2 AS 
		( SELECT r.id, r.omrade::geometry AS geo, 'old rows deleted update' || r.omrade::text AS topo
			FROM new_rows_updated_in_org_table r) ;
	END IF;

	-- insert missing rows and keep a copy in them a temp table
	DROP TABLE IF EXISTS new_rows_added_in_org_table;
	
	command_string :=  format('CREATE TEMP TABLE new_rows_added_in_org_table AS (SELECT * FROM %I.%I limit 0);
	WITH inserted AS (
	INSERT INTO  %I.%I(%I,felles_egenskaper)
	SELECT new.surface_topo, new.felles_egenskaper_flate as felles_egenskaper
	FROM new_surface_data new
	WHERE NOT EXISTS ( SELECT f.id FROM %I.%I f WHERE (new.surface_topo).id = (f.%I).id )
	returning *
	)
	INSERT INTO new_rows_added_in_org_table(id,omrade)
	SELECT inserted.id, omrade FROM inserted',
    surface_topo_info.layer_schema_name,
    surface_topo_info.layer_table_name,
    surface_topo_info.layer_schema_name,
    surface_topo_info.layer_table_name,
    surface_topo_info.layer_feature_column,
    surface_topo_info.layer_schema_name,
    surface_topo_info.layer_table_name,
    surface_topo_info.layer_feature_column
  	);  
	EXECUTE command_string;
	
	
	-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- list new objects added reused
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.update_domain_surface_layer_t3;
		CREATE TABLE topo_rein.update_domain_surface_layer_t3 AS 
		( SELECT r.id, r.omrade::geometry AS geo, 'new topo objcts' || r.omrade::text AS topo
			FROM new_rows_added_in_org_table r) ;
	END IF;

  -- Extract name of fields with not-null values:
  -- Extract name of fields with not-null values and append the table prefix n.:
  -- Only update json value that exits 
  IF (SELECT count(*) FROM old_rows_attributes)::int > 0 THEN
  
 	 	RAISE NOTICE 'topo_update.update_domain_surface_layer num rows in old attrbuttes: %', (SELECT count(*) FROM old_rows_attributes)::int;
	
  		SELECT
	  	array_agg(quote_ident(update_column)) AS update_fields,
	  	array_agg('c.'||quote_ident(update_column)) as update_fields_t
		  INTO
		  	update_fields,
		  	update_fields_t
		  FROM (
		   SELECT distinct(key) AS update_column
		   FROM old_rows_attributes t, json_each_text(to_json((t)))  
		   WHERE key != 'id' AND key != 'foo_geo'  AND key != 'omrade'  
		  ) AS keys;
		
		  RAISE NOTICE 'topo_update.update_domain_surface_layer Extract name of not-null fields-c: %', update_fields_t;
		  RAISE NOTICE 'topo_update.update_domain_surface_layer Extract name of not-null fields-c: %', update_fields;
		
	    command_string := format(
	    'UPDATE %I.%I a
		SET 
		(%s) = (%s) 
		FROM new_rows_added_in_org_table b, 
		old_rows_attributes c
		WHERE 
	    a.id = b.id AND                           
	    ST_Intersects(c.foo_geo,ST_pointOnSurface(a.%I::geometry))',
	    surface_topo_info.layer_schema_name,
	    surface_topo_info.layer_table_name,
	    array_to_string(update_fields, ','),
	    array_to_string(update_fields_t, ','),
	    surface_topo_info.layer_feature_column
	    );
		RAISE NOTICE 'topo_update.update_domain_surface_layer command_string %', command_string;
		EXECUTE command_string;
		
		GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

		RAISE NOTICE 'topo_update.update_domain_surface_layer no old attribute values found  %',  num_rows_affected;

	
	END IF;

    

	   	-- update the newly inserted rows with attribute values based from old_rows_table
    -- find the rows toubching
  DROP TABLE IF EXISTS touching_surface;
  

  -- If this is a not a closed polygon you have use touches
  IF  valid_closed_user_geometry IS NULL  THEN
	  CREATE TEMP TABLE touching_surface AS 
	  (SELECT a.id, topo_update.touches(surface_layer_name,a.id,surface_topo_info) as id_from 
	  FROM new_rows_added_in_org_table a);
  ELSE
  -- IF this a cloesed polygon only use objcet thats inside th e surface drawn by the user
	  CREATE TEMP TABLE touching_surface AS 
	  (
	  SELECT a.id, topo_update.touches(surface_layer_name,a.id,surface_topo_info) as id_from 
	  FROM new_rows_added_in_org_table a
	  WHERE ST_Covers(valid_closed_user_geometry,ST_PointOnSurface(a.omrade::geometry))
	  );
	  
  END IF;


  -- if there are any toching interfaces  
	IF (SELECT count(*) FROM touching_surface)::int > 0 THEN

	   SELECT
		  	array_agg(quote_ident(update_column)) AS update_fields,
		  	array_agg('d.'||quote_ident(update_column)) as update_fields_t
		  INTO
		  	update_fields,
		  	update_fields_t
		  FROM (
		   SELECT distinct(key) AS update_column
		   FROM new_rows_added_in_org_table t, json_each_text(to_json((t)))  
		   WHERE key != 'id' AND key != 'foo_geo' AND key != 'omrade' AND key != 'felles_egenskaper' AND key != 'status'
		  ) AS keys;
		
		  RAISE NOTICE 'topo_update.update_domain_surface_layer Extract name of not-null fields-a: %', update_fields_t;
		  RAISE NOTICE 'topo_update.update_domain_surface_layer Extract name of not-null fields-a: %', update_fields;
		
	   	-- update the newly inserted rows with attribute values based from old_rows_table
	    -- find the rows toubching
--	  	DROP TABLE IF EXISTS touching_surface;
--		CREATE TEMP TABLE touching_surface AS 
--		(SELECT topo_update.touches(surface_layer_name,a.id,surface_topo_info) as id 
--		FROM new_rows_added_in_org_table a);
	
	
		-- we set values with null row that can pick up a value from a neighbor.
		-- NB! this onlye work if new rows dont' have any defalut value
		-- TODO use a test based on new rows added and not a test on null values
	    command_string := format('UPDATE %I.%I a
		SET 
			(%s) = (%s) 
		FROM 
		%I.%I d,
		touching_surface b
		WHERE 
		a.%I is null AND
		d.id = b.id_from AND
		a.id = b.id',
	    surface_topo_info.layer_schema_name,
	    surface_topo_info.layer_table_name,
	    array_to_string(update_fields, ','),
	    array_to_string(update_fields_t, ','),
	    surface_topo_info.layer_schema_name,
	    surface_topo_info.layer_table_name,
	    'reinbeitebruker_id');
		RAISE NOTICE 'topo_update.update_domain_surface_layer command_string %', command_string;
		EXECUTE command_string;
	
		GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	
		RAISE NOTICE 'topo_update.update_domain_surface_layer Number num_rows_affected  %',  num_rows_affected;
		
	END IF;


	RETURN QUERY SELECT a.surface_topo::topogeometry as t FROM new_surface_data a;

	
END;
$$ LANGUAGE plpgsql;




-- update attribute values for given topo object

CREATE OR REPLACE FUNCTION topo_update.apply_attr_on_topo_line(json_feature text,
  layer_schema text, layer_table text, layer_column text,server_json_feature text default null) 
RETURNS int AS $$DECLARE

num_rows int;

-- common meta info
topo_info topo_update.input_meta_info ;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- holds the num rows affected when needed
num_rows_affected int;

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the target table
update_fields text[];

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the temp table
update_fields_t text[];

-- holde the computed value for json input reday to use
json_input_structure topo_update.json_input_structure;  

BEGIN

	-- get meta data
	topo_info := topo_update.make_input_meta_info(layer_schema, layer_table , layer_column );
	
	-- parse the input values
	json_input_structure := topo_update.handle_input_json_props(json_feature::json,server_json_feature::json,4258);

	
	RAISE NOTICE 'topo_update.apply_attr_on_topo_line json_input_structure %', json_input_structure;


	-- Create temporary table ttt2_aaotl_new_topo_rows_in_org_table to receive the new record
	command_string := topo_update.create_temp_tbl_as(
	  'ttt2_aaotl_new_topo_rows_in_org_table',
	  format('SELECT * FROM %I.%I LIMIT 0',
	         topo_info.layer_schema_name,
	         topo_info.layer_table_name));
	EXECUTE command_string;

	
  	-- Insert all matching column names into temp table ttt2_aaotl_new_topo_rows_in_org_table 
	INSERT INTO ttt2_aaotl_new_topo_rows_in_org_table
	SELECT * FROM json_populate_record(null::ttt2_aaotl_new_topo_rows_in_org_table,json_input_structure.json_properties);
	
	RAISE NOTICE 'topo_update.apply_attr_on_topo_line Added all attributes to ttt2_aaotl_new_topo_rows_in_org_table';

	-- Update felles egenskaper with new values
	command_string := format('UPDATE ttt2_aaotl_new_topo_rows_in_org_table AS s
	SET felles_egenskaper = topo_rein.get_rein_felles_egenskaper_update(r.felles_egenskaper, %L)
	FROM  %I.%I r
	WHERE r.id = s.id',
	json_input_structure.sosi_felles_egenskaper,
    topo_info.layer_schema_name,
    topo_info.layer_table_name
	);
	RAISE NOTICE 'topo_update.apply_attr_on_topo_line command_string %', command_string;
	EXECUTE command_string;

  RAISE NOTICE 'topo_update.apply_attr_on_topo_line Set felles_egenskaper field';

  -- Extract name of fields with not-null values:
  -- Extract name of fields with not-null values and append the table prefix n.:
  -- Only update json value that exits 
  SELECT
  	array_agg(quote_ident(update_column)) AS update_fields,
  	array_agg('n.'||quote_ident(update_column)) as update_fields_t
  INTO
  	update_fields,
  	update_fields_t
  FROM (
   SELECT distinct(key) AS update_column
   FROM ttt2_aaotl_new_topo_rows_in_org_table t, json_each_text(to_json((t)))  ,
   (SELECT json_object_keys(json_input_structure.json_properties) as res) as key_list
   WHERE key != 'id' AND 
   key = key_list.res 
  ) AS keys;
  
  -- This is hardcoding if a column name that should have been done i a better way
  update_fields := array_append(update_fields, 'felles_egenskaper');
  update_fields_t := array_append(update_fields_t, 'n.felles_egenskaper');
  
  RAISE NOTICE 'topo_update.apply_attr_on_topo_line Extract name of not-null fields: %', update_fields_t;
  RAISE NOTICE 'topo_update.apply_attr_on_topo_line Euuxtract name of not-null fields: %', update_fields;
  
  -- update the org table with not null values
  command_string := format(
    'UPDATE %I.%I s SET
	(%s) = (%s) 
	FROM ttt2_aaotl_new_topo_rows_in_org_table n WHERE n.id = s.id',
    topo_info.layer_schema_name,
    topo_info.layer_table_name,
    array_to_string(update_fields, ','),
    array_to_string(update_fields_t, ',')
    );
	RAISE NOTICE 'topo_update.apply_attr_on_topo_line command_string %', command_string;
	EXECUTE command_string;
	
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'topo_update.apply_attr_on_topo_line Number num_rows_affected  %',  num_rows_affected;
	

	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;



--{ kept for backward compatility
CREATE OR REPLACE FUNCTION  topo_update.apply_attr_on_topo_line(json_feature text) 
RETURNS TABLE(id integer) AS $$
  SELECT topo_update.apply_attr_on_topo_line($1, 'topo_rein', 'reindrift_anlegg_linje', 'linje');
$$ LANGUAGE 'sql';
--}


-- update attribute values for given topo object
CREATE OR REPLACE FUNCTION topo_update.apply_attr_on_topo_point(json_feature text,
  layer_schema text, layer_table text, layer_column text, snap_tolerance float8,server_json_feature text default null) 
RETURNS int AS $$DECLARE

num_rows int;


-- this point layer id will picked up by input parameters
point_layer_id int;


-- TODO use as parameter put for testing we just have here for now
point_topo_info topo_update.input_meta_info ;

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- holds the num rows affected when needed
num_rows_affected int;

geo_point geometry;

row_id int;

-- holde the computed value for json input reday to use
json_input_structure topo_update.json_input_structure;  


BEGIN
	
	point_topo_info := topo_update.make_input_meta_info(layer_schema, layer_table , layer_column );
	point_layer_id := topo_update.get_topo_layer_id(point_topo_info);
	
	-- parse the input values
	json_input_structure := topo_update.handle_input_json_props(json_feature::json,server_json_feature::json,4258);
	geo_point := json_input_structure.input_geo;

	RAISE NOTICE 'geo_point from json %',  ST_AsEWKT(geo_point);

	-- update attributtes by common proc
	num_rows_affected := topo_update.apply_attr_on_topo_line(json_feature,
 	point_topo_info.layer_schema_name, point_topo_info.layer_table_name, point_topo_info.layer_feature_column,server_json_feature) ;

 	
	RAISE NOTICE 'geo_point %',  ST_AsEWKT(geo_point);

	-- if move point
	IF geo_point is not NULL THEN
	
		row_id := (json_input_structure.json_properties->>'id')::int;
	
		command_string := format('SELECT topology.clearTopoGeom(%s) FROM  %I.%I r WHERE id = %s',
		point_topo_info.layer_feature_column,
	    point_topo_info.layer_schema_name,
	    point_topo_info.layer_table_name,
	    row_id
		);

		RAISE NOTICE 'command_string update point geom %', command_string;
		EXECUTE command_string;

		command_string := format('UPDATE  %I.%I r
		SET %s = topology.toTopoGeom(%L, %L, %L, %L)
		WHERE id = %s',
	    point_topo_info.layer_schema_name,
	    point_topo_info.layer_table_name,
		point_topo_info.layer_feature_column,
		geo_point,
    	point_topo_info.topology_name, 
    	point_layer_id,
    	point_topo_info.snap_tolerance,
	    row_id
		);

		RAISE NOTICE 'command_string %', command_string;
		EXECUTE command_string;

		
		GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	
	END IF;
	
	RAISE NOTICE 'Number num_rows_affected  %',  num_rows_affected;
	

	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;





--{ kept for backward compatility
CREATE OR REPLACE FUNCTION  topo_update.apply_attr_on_topo_point(json_feature text) 
RETURNS int AS $$
  SELECT topo_update.apply_attr_on_topo_point($1, 'topo_rein', 'reindrift_anlegg_punkt', 'punkt',  1e-10);
$$ LANGUAGE 'sql';
--}


-- This a function that will be called from the client when user is drawing a line
-- This line will be applied the data in the line layer

-- The result is a set of id's of the new line objects created

-- TODO set attributtes for the line


-- {
CREATE OR REPLACE FUNCTION
topo_update.create_line_edge_domain_obj(json_feature text,
  layer_schema text, layer_table text, layer_column text,
  snap_tolerance float8,
  server_json_feature text default null)
RETURNS TABLE(id integer) AS $$
DECLARE

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this is the tolerance used for snap to 
-- TODO use as parameter put for testing we just have here for now
border_topo_info topo_update.input_meta_info ;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- the number times the input line intersects
num_edge_intersects int;

input_geo geometry;

-- holds the value for felles egenskaper from input
felles_egenskaper_linje topo_rein.sosi_felles_egenskaper;

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the target table
not_null_fields text[];
all_fields text[];
all_fields_a text[];

-- holde the computed value for json input reday to use
json_input_structure topo_update.json_input_structure;  

BEGIN
	
	-- TODO totally rewrite this code
	json_input_structure := topo_update.handle_input_json_props(json_feature::json,server_json_feature::json,4258);
	input_geo := json_input_structure.input_geo;

	
	
	-- get meta data the border line for the surface
	border_topo_info := topo_update.make_input_meta_info(layer_schema, layer_table , layer_column );
		-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);

	
	RAISE NOTICE 'The JSON input %',  json_feature;

	RAISE NOTICE 'border_layer_id %', border_layer_id;


	-- get the json values
	command_string := topo_update.create_temp_tbl_def('ttt2_new_attributes_values_c_l_e_d','(geom geometry,properties json)');
	RAISE NOTICE 'command_string %', command_string;

	EXECUTE command_string;

	-- TRUNCATE TABLE ttt2_new_attributes_values_c_l_e_d;
	INSERT INTO ttt2_new_attributes_values_c_l_e_d(geom,properties)
	VALUES(json_input_structure.input_geo,json_input_structure.json_properties) ;

		-- check that it is only one row put that value into 
	-- TODO rewrite this to not use table in
	
	RAISE NOTICE 'Step::::::::::::::::: 1';


	felles_egenskaper_linje := json_input_structure.sosi_felles_egenskaper;

	

	RAISE NOTICE 'Step::::::::::::::::: 2';

	-- Create temporary table to receive the new record
	command_string := topo_update.create_temp_tbl_as(
	  'ttt2_new_topo_rows_in_org_table',
	  format('SELECT * FROM %I.%I LIMIT 0',
	         border_topo_info.layer_schema_name,
	         border_topo_info.layer_table_name));
	EXECUTE command_string;

  -- Insert all matching column names into temp table
	INSERT INTO ttt2_new_topo_rows_in_org_table
		SELECT r.* --, t2.geom
		FROM ttt2_new_attributes_values_c_l_e_d t2,
         json_populate_record(
            null::ttt2_new_topo_rows_in_org_table,
            t2.properties) r;

  RAISE NOTICE 'Added all attributes to ttt2_new_topo_rows_in_org_table';

  -- Convert geometry to TopoGeometry, write it in the temp table
  command_string := format('UPDATE ttt2_new_topo_rows_in_org_table
    SET %I = topology.toTopoGeom(%L, %L, %L, %L)',
    border_topo_info.layer_feature_column, input_geo,
    border_topo_info.topology_name, border_layer_id,
    border_topo_info.snap_tolerance);
	EXECUTE command_string;

  RAISE NOTICE 'Converted to TopoGeometry';

  -- Add the common felles_egenskaper field
  command_string := format('UPDATE ttt2_new_topo_rows_in_org_table
    SET felles_egenskaper = %L', felles_egenskaper_linje);
	EXECUTE command_string;

  RAISE NOTICE 'Set felles_egenskaper field';

  -- Extract name of fields with not-null values:
  SELECT array_agg(quote_ident(key))
    FROM ttt2_new_topo_rows_in_org_table t, json_each_text(to_json((t)))
   WHERE value IS NOT NULL
    INTO not_null_fields;


  RAISE NOTICE 'Extract name of not-null fields: %', not_null_fields;

  -- Copy full record from temp table to actual table and
  -- update temp table with actual table values
  command_string := format(
    'WITH inserted AS ( INSERT INTO %I.%I (%s) SELECT %s FROM
ttt2_new_topo_rows_in_org_table RETURNING * ), deleted AS ( DELETE
FROM ttt2_new_topo_rows_in_org_table ) INSERT INTO
ttt2_new_topo_rows_in_org_table SELECT * FROM inserted ',
    border_topo_info.layer_schema_name,
    border_topo_info.layer_table_name,
    array_to_string(not_null_fields, ','),
    array_to_string(not_null_fields, ',')
    );
	EXECUTE command_string;

	RAISE NOTICE 'Step::::::::::::::::: 3';

  -- Count number of objects sharing edges with this new one
  command_string := format('
	SELECT count(distinct a.id)
    FROM 
	%I.relation re,
	%I.edge_data ed,
	%I.%I  a,
	ttt2_new_topo_rows_in_org_table nr2,
	%I.relation re2,
	%I.edge_data ed2
	WHERE 
	(a.%I).id = re.topogeo_id AND
	re.layer_id = %L AND 
	re.element_type = 2 AND  -- TODO use variable element_type_edge=2
	ed.edge_id = re.element_id AND
	(nr2.%I).id = re2.topogeo_id and
	re2.layer_id = %L and 
	re2.element_type = 2 and  -- todo use variable element_type_edge=2
	ed2.edge_id = re2.element_id and
	(ed2.start_node = ed.start_node or
	ed2.end_node = ed.end_node or
	ed2.start_node = ed.end_node or
	ed2.start_node = ed.end_node) AND
	(a.%I).id != (nr2.%I).id;
  ',
	  border_topo_info.topology_name,
	  border_topo_info.topology_name,
    border_topo_info.layer_schema_name,
	  border_topo_info.layer_table_name,
	  border_topo_info.topology_name,
	  border_topo_info.topology_name,
	  border_topo_info.layer_feature_column,
    border_layer_id,
	  border_topo_info.layer_feature_column,
    border_layer_id,
	  border_topo_info.layer_feature_column,
	  border_topo_info.layer_feature_column
  );
  EXECUTE command_string INTO  num_edge_intersects;
	

	RAISE NOTICE 'num_object_intersects::::::::::::::::: %', num_edge_intersects;
	

	
	--------------------- Start: code to remove duplicate edges ---------------------
	-- Should be moved to a separate proc so we could reuse this code for other line 
	
	-- Find the edges that are used by the input line 
	command_string := topo_update.create_temp_tbl_as('ttt2_covered_by_input_line',
    'SELECT * FROM ' || quote_ident(border_topo_info.topology_name)
    || '.edge_data limit 0');
	EXECUTE command_string;
	-- TRUNCATE TABLE ttt2_covered_by_input_line;

  command_string := format('
	INSERT INTO ttt2_covered_by_input_line
	SELECT distinct ed.*  
    FROM 
	%I.relation re,
	ttt2_new_topo_rows_in_org_table ud, 
	%I.edge_data ed
	WHERE 
	(ud.%I).id = re.topogeo_id AND
	re.layer_id = %L AND 
	re.element_type = 2 AND  -- TODO use variable element_type_edge=2
	ed.edge_id = re.element_id',
  border_topo_info.topology_name,
  border_topo_info.topology_name,
  border_topo_info.layer_feature_column,
  border_layer_id
  );
  EXECUTE command_string;

	RAISE NOTICE 'Step::::::::::::::::: 4 ny';

	-- Find edges that are not used by the input line which needs to recreated.
	-- This only the case when ypu have direct overlap. Will only happen when part of the same line is added twice.
	-- Exlude the object createed now
	command_string := topo_update.create_temp_tbl_as('ttt2_not_covered_by_input_line',
    'SELECT * FROM ' || quote_ident(border_topo_info.topology_name)
    || '.edge_data limit 0');
	EXECUTE command_string;

	command_string := format('INSERT INTO ttt2_not_covered_by_input_line
	SELECT distinct ed.*  
    FROM 
	ttt2_new_topo_rows_in_org_table ud, 
	%I.relation re,
	%I.relation re2,
	%I.relation re3,
	%I.edge_data ed
	WHERE 
	(ud.%I).id = re.topogeo_id AND
	re.layer_id = %L AND 
	re.element_type = 2 AND  -- TODO use variable element_type_edge=2
	re2.layer_id = %L AND 
	re2.element_type = 2 AND  -- TODO use variable element_type_edge=2
	re2.element_id = re.element_id AND
	re3.topogeo_id = re2.topogeo_id AND
	re3.element_id = ed.edge_id AND NOT EXISTS
  (SELECT 1 FROM ttt2_covered_by_input_line where ed.edge_id = edge_id)',
  border_topo_info.topology_name,
  border_topo_info.topology_name,
  border_topo_info.topology_name,
  border_topo_info.topology_name,
	border_topo_info.layer_feature_column,
	border_layer_id,
	border_layer_id
  );
	EXECUTE command_string;


	RAISE NOTICE 'Step::::::::::::::::: 5 cb %' , (select count(*) from ttt2_not_covered_by_input_line);

	-- Find topo objects that needs to be adjusted because old topo object has edges that are used by this new topo object
	-- Exlude the object createed now
	command_string :=
topo_update.create_temp_tbl_as('ttt2_affected_objects_id','SELECT * FROM  ttt2_new_topo_rows_in_org_table limit 0');
	EXECUTE command_string;

  command_string := format('INSERT INTO ttt2_affected_objects_id
	SELECT distinct a.*  
    FROM 
	%I.relation re1,
	%I.relation re2,
	ttt2_new_topo_rows_in_org_table ud, 
	%I.%I a
	WHERE 
	(ud.%I).id = re1.topogeo_id AND
	re1.layer_id = %L AND 
	re1.element_type = 2 AND
	re1.element_id = re2.element_id AND 
	(a.%I).id = re2.topogeo_id AND
	re2.layer_id = %L AND 
	re2.element_type = 2 AND
	NOT EXISTS
  (SELECT 1 FROM ttt2_new_topo_rows_in_org_table nr where a.id = nr.id)',
  border_topo_info.topology_name,
  border_topo_info.topology_name,
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name,
  border_topo_info.layer_feature_column,
  border_layer_id,
  border_topo_info.layer_feature_column,
  border_layer_id
  );
	EXECUTE command_string;
	
	RAISE NOTICE 'Step::::::::::::::::: 6 af %' , (select count(*) from ttt2_affected_objects_id);


	-- Find topo objects thay can deleted because all their edges area covered by new input linje
	-- This is true this objects has no edges in the list of not used edges
	command_string :=
topo_update.create_temp_tbl_as('ttt2_objects_to_be_delted','SELECT * FROM  ttt2_new_topo_rows_in_org_table limit 0');
	EXECUTE command_string;

  command_string := format('
	INSERT INTO ttt2_objects_to_be_delted
	SELECT b.id FROM 
	ttt2_affected_objects_id b,
	ttt2_covered_by_input_line c,
	%I.relation re2
	WHERE b.id NOT IN
	(	
		SELECT distinct a.id 
		FROM 
		%I.relation re1,
		ttt2_affected_objects_id a,
		ttt2_not_covered_by_input_line ued1
		WHERE 
		(a.%I).id = re1.topogeo_id AND
		re1.layer_id = %L AND 
		re1.element_type = 2 AND
		ued1.edge_id = re1.element_id
	) AND
	b.id = re2.topogeo_id AND
	re2.layer_id = %L AND 
	re2.element_type = 2 AND
	c.edge_id = re2.element_id',
	border_topo_info.topology_name,
	border_topo_info.topology_name,
	border_topo_info.layer_feature_column,
  border_layer_id,
  border_layer_id
  );
	EXECUTE command_string;
		

	RAISE NOTICE 'Step::::::::::::::::: 7';

	-- Clear the topology elements objects that does not have edges left
	command_string = format('SELECT topology.clearTopoGeom(a.%I) 
	FROM %I.%I  a,
	ttt2_objects_to_be_delted b
	WHERE a.id = b.id', 
	border_topo_info.layer_feature_column,
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name
  );
  EXECUTE command_string;
	
	RAISE NOTICE 'Step::::::::::::::::: 8';

	-- Delete those topology elements objects that does not have edges left
  command_string := format('
	DELETE FROM %I.%I a
	USING ttt2_objects_to_be_delted b
	WHERE a.id = b.id',
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name
  );
  EXECUTE command_string;

	
	RAISE NOTICE 'Step::::::::::::::::: 94 af %, nc %',  (select count(*) from ttt2_affected_objects_id), (select count(*) from ttt2_not_covered_by_input_line);

	-- Find  lines that should be added again the because the objects which they belong to will be deleted
	command_string := topo_update.create_temp_tbl_def('ttt2_objects_to_be_updated','(id int, geom geometry)');
	EXECUTE command_string;

	command_string := format('INSERT INTO ttt2_objects_to_be_updated(id,geom)
	SELECT b.id, ST_union(ed.geom) AS geom
	FROM ttt2_affected_objects_id b,
	ttt2_not_covered_by_input_line ed,
	%I.relation re
	WHERE (b.%I).id = re.topogeo_id AND
	re.layer_id = %L AND 
	re.element_type = 2 AND  -- TODO use variable element_type_edge=2
	ed.edge_id != re.element_id
	GROUP BY b.id',
	border_topo_info.topology_name,
	border_topo_info.layer_feature_column,
	border_layer_id
  );
	EXECUTE command_string;

	RAISE NOTICE 'StepA::::::::::::::::: 1, rows %', (select count(*) from ttt2_objects_to_be_updated) ;

	-- Clear the old topology elements objects that should be updated
	command_string := format('SELECT topology.clearTopoGeom(a.%I) 
	FROM %I.%I  a,
	ttt2_objects_to_be_updated b
	WHERE a.id = b.id', 
	border_topo_info.layer_feature_column,
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name
  );
  EXECUTE command_string;
	
	
	RAISE NOTICE 'StepA::::::::::::::::: 2';

	-- Update the old topo objects with new values
  -- TODO: avoid another toTopoGeom call here
	command_string := format('UPDATE %I.%I AS a
	SET %I = topology.toTopoGeom(b.geom, %L, %L, %L)
	FROM ttt2_objects_to_be_updated b
	WHERE a.id = b.id',
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name,
	border_topo_info.layer_feature_column,
	border_topo_info.topology_name, border_layer_id, 
	border_topo_info.snap_tolerance
  );

	EXECUTE command_string;

	-- We have now removed duplicate ref to any edges, this means that each edge is only used once
	--------------------- Stop: code to remove duplicate edges ---------------------
	--==============================================================================
	--==============================================================================


	RAISE NOTICE 'StepA::::::::::::::::: 3';

	
	-- Find topto that intersects with the new line drawn by the end user
	-- This lines should be returned, together with the topo object created
	command_string :=
topo_update.create_temp_tbl_as('ttt2_intersection_id','SELECT * FROM ttt2_new_topo_rows_in_org_table limit 0');
	EXECUTE command_string;
	-- TRUNCATE TABLE ttt2_intersection_id;

  command_string := format('
	INSERT INTO ttt2_intersection_id
	SELECT distinct a.*  
	FROM 
	%I.%I a, 
	ttt2_new_attributes_values_c_l_e_d a2,
	%I.relation re, 
	topology.layer tl,
	%I.edge_data  ed
	WHERE ST_intersects(ed.geom,a2.geom)
	AND topo_rein.get_relation_id(a.%I) = re.topogeo_id AND
re.layer_id = tl.layer_id AND tl.schema_name = %L AND 
	tl.table_name = %L AND ed.edge_id=re.element_id
	AND NOT EXISTS (SELECT 1 FROM ttt2_new_topo_rows_in_org_table nr
where a.id = nr.id)',
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name,
  border_topo_info.topology_name,
  border_topo_info.topology_name,
  border_topo_info.layer_feature_column,
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name
  );
	EXECUTE command_string;

	RAISE NOTICE 'StepA::::::::::::::::: 4';

	
	-- create a empty table hold list og id's changed.
	-- TODO this should have moved to anothe place, but we need the result below
	command_string := topo_update.create_temp_tbl_as('ttt2_id_return_list','SELECT * FROM  ttt2_new_topo_rows_in_org_table limit 0');
	EXECUTE command_string;
	-- TRUNCATE TABLE ttt2_id_return_list;

	-- update the return table with intersected rows
	INSERT INTO ttt2_id_return_list(id)
	SELECT a.id FROM ttt2_new_topo_rows_in_org_table a ;

	-- update the return table with intersected rows
	INSERT INTO ttt2_id_return_list(id)
	SELECT a.id FROM ttt2_intersection_id a ;
	
	RAISE NOTICE 'StepA::::::::::::::::: 5';


	IF num_edge_intersects < 3 THEN -- {

		--------------------- Start: Find short eges to be removed  ---------------------
		-- Should be moved to a separate proc so we could reuse this code for other line 
		-- Find edges that are verry short and that are close to the edges that area drawn.
	
		
		-- Find the edges that intersects with the input line that are short and may be reomved
		command_string := topo_update.create_temp_tbl_def('ttt2_short_edge_list','(id int, edge_id int, geom geometry)');
		EXECUTE command_string;

    command_string := '
		INSERT INTO ttt2_short_edge_list(id,edge_id,geom)
		SELECT distinct a.id, ed.edge_id , ed.geom 
	    FROM 
		' || quote_ident(border_topo_info.topology_name) || '.relation re,
		ttt2_id_return_list ud, 
		' || quote_ident(border_topo_info.topology_name) || '.edge_data ed,
		' || quote_ident(border_topo_info.layer_schema_name) || '.' || quote_ident(border_topo_info.layer_table_name) || '  a,
		ttt2_new_topo_rows_in_org_table nr2,
		' || quote_ident(border_topo_info.topology_name) || '.relation re2,
		' || quote_ident(border_topo_info.topology_name) || '.edge_data ed2
		
		WHERE 
		ud.id = a.id AND
		(a.' || quote_ident(border_topo_info.layer_feature_column) || ').id = re.topogeo_id AND
		re.layer_id = ' || border_layer_id || ' AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		
		(nr2.' || quote_ident(border_topo_info.layer_feature_column) || ').id = re2.topogeo_id and
		re2.layer_id = ' || border_layer_id || ' and 
		re2.element_type = 2 and  -- todo use variable element_type_edge=2
		ed2.edge_id = re2.element_id and
		(ed2.start_node = ed.start_node or
		ed2.end_node = ed.end_node or
		ed2.start_node = ed.end_node or
		ed2.start_node = ed.end_node) AND
	
		NOT EXISTS -- dont remove small line pices that are connected to another edges
		( 
			SELECT 1 FROM 
				' || quote_ident(border_topo_info.topology_name) || '.edge_data AS ed3,
				' || quote_ident(border_topo_info.topology_name) || '.edge_data AS ed4
			--	' || quote_ident(border_topo_info.topology_name) || '.edge_data ed
				WHERE 
--				ed2.edge_id != ed.edge_id AND -- This role is applied to it self
				(ed3.edge_id != ed.edge_id AND  
				(ed3.start_node = ed.start_node OR
				ed3.end_node = ed.start_node))
				AND
				(ed4.edge_id != ed.edge_id AND  
				(ed4.start_node = ed.end_node OR
				ed4.end_node = ed.end_node))
		) AND
		
		-- don remove line that ara on line line and does
	--	NOT EXISTS 
	--	( 
	--		SELECT 1 FROM 
	--		' || quote_ident(border_topo_info.topology_name) || '.edge_data AS ed2
	--		WHERE 
	--		ed2.geom = ed.geom
	--	) 	AND
	
		EXISTS -- dont remove small pices if this has the same length as single topoobject 
		( 
			SELECT 1 FROM 
			(
				SELECT ST_Length(ST_Union(eda.geom)) AS topo_length FROM 
				' || quote_ident(border_topo_info.topology_name) || '.relation re3,
				' || quote_ident(border_topo_info.topology_name) || '.relation re4,
				' || quote_ident(border_topo_info.topology_name) || '.edge_data eda
				WHERE 
				re3.layer_id = ' || border_layer_id || ' AND 
				re3.element_type = 2 AND  -- TODO use variable element_type_edge=2
				ed.edge_id = re3.element_id AND
				re4.topogeo_id = re3.topogeo_id AND
				re4.element_id = eda.edge_id
				GROUP BY eda.edge_id
			) AS r2
			WHERE ST_Length(ed.geom) < topo_length -- TODO adde test the relative length of the topo object
		) AND
		
		(
			-- for the lines drwan by the user we dont need to check on min length 
			( 
				(a.' || quote_ident(border_topo_info.layer_feature_column) || ').id = (nr2.' || quote_ident(border_topo_info.layer_feature_column) || ').id AND
				ST_Length(ed.geom) < ST_Length($1) AND
				ST_Length($1)/ST_Length(ed.geom) > 9-- TODO find out what values to use here is this performance problem ?
			)
		OR
			(
				(a.' || quote_ident(border_topo_info.layer_feature_column) || ').id != (nr2.' || quote_ident(border_topo_info.layer_feature_column) || ').id AND
				ST_Length(ed.geom) < ST_Length($1) AND
				ST_Length($1)/ST_Length(ed.geom) > 9 AND -- TODO find out what values to use here is this performance problem ?
				ST_Length(ST_transform(ed.geom,32632)) < 500  -- TODO find out what values to use here is this performance problem ?
			)
		)';
		EXECUTE command_string USING input_geo;
		
		
		
		RAISE NOTICE 'StepA::::::::::::::::: 6 sl %', (select count(*) from ttt2_short_edge_list);
	
		-- Create the new geo with out the short edges, this is what the objects should look like
		command_string := topo_update.create_temp_tbl_def('ttt2_no_short_object_list','(id int, geom geometry)');
		EXECUTE command_string;

    command_string := format('
		INSERT INTO ttt2_no_short_object_list(id,geom)
		SELECT b.id, ST_union(ed.geom) AS geom
		FROM ttt2_short_edge_list b,
		%I.edge_data ed,
		%I.relation re,
		%I.%I  a
		WHERE a.id = b.id AND
		(a.%I).id = re.topogeo_id AND
		re.layer_id = %L AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		NOT EXISTS (SELECT 1 FROM ttt2_short_edge_list WHERE ed.edge_id = edge_id)
		GROUP BY b.id',
  border_topo_info.topology_name,
  border_topo_info.topology_name,
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name,
	border_topo_info.layer_feature_column,
	border_layer_id
    );
		EXECUTE command_string;
	
		RAISE NOTICE 'StepA::::::::::::::::: 7';
	
	--	IF (SELECT ST_AsText(ST_StartPoint(geom)) FROM ttt2_new_attributes_values_c_l_e_d)::text = 'POINT(5.69699 58.55152)' THEN
	--		return;
	--	END IF;
	
		
		-- Clear the topology elements objects that should be updated
    command_string = format('SELECT topology.clearTopoGeom(a.%I) 
    FROM %I.%I  a,
    ttt2_no_short_object_list b
    WHERE a.id = b.id', 
    border_topo_info.layer_feature_column,
    border_topo_info.layer_schema_name,
    border_topo_info.layer_table_name
    );
		EXECUTE command_string;
		
		-- Remove edges not used from the edge table
	 	command_string := FORMAT('
			SELECT ST_RemEdgeModFace(%1$L, ed.edge_id)
			FROM 
			ttt2_short_edge_list ued,
			%2$s ed
			WHERE 
			ed.edge_id = ued.edge_id 
			',
			border_topo_info.topology_name,
			border_topo_info.topology_name || '.edge_data'
		);
		
		RAISE NOTICE '%', command_string;
	
	    EXECUTE command_string;
	
	
		-- Update the topo objects with shared edges that stil hava 
    -- TODO: avoid another toTopoGeom call here
    command_string := format('UPDATE %I.%I AS a
    SET %I = topology.toTopoGeom(b.geom, %L, %L, %L)
    FROM ttt2_no_short_object_list b
    WHERE a.id = b.id',
    border_topo_info.layer_schema_name,
    border_topo_info.layer_table_name,
    border_topo_info.layer_feature_column,
    border_topo_info.topology_name, border_layer_id, 
    border_topo_info.snap_tolerance
    );
	
		
		EXECUTE command_string;
	
		--------------------- Stop: Find short eges to be removed  ---------------------
		--==============================================================================
		--==============================================================================
	
	
				
		-------------------- Start: split up edges when the input line intersects the line segment two times   ---------------------
		-- This makes is possible for the user remove the eges beetween two intersections
		-- Should be moved to a separate proc so we could reuse this code for other line 
		
		
		-- Test if there if both start and end point intersect with line a connected set of edges
		-- Connected means that they each edge is connnected
		
		-- find all edges covered by the input using ttt2_new_topo_rows_in_org_table a ;
		-- TODO this is already done above most times but in scases where the input line is not changed all we have to do it
		-- TDOO is this faster ? or should we just use to simple feature ???
		command_string := topo_update.create_temp_tbl_def('ttt2_final_edge_list_for_input_line','(id int, geom geometry)');
		EXECUTE command_string;
		-- TRUNCATE TABLE ttt2_final_edge_list_for_input_line;

    command_string := format('
		INSERT INTO ttt2_final_edge_list_for_input_line
		SELECT distinct ud.id, ST_Union(ed.geom) AS geom
	    FROM 
		%I.relation re,
		ttt2_new_topo_rows_in_org_table ud, 
		%I.edge_data ed,
		%I.%I a 
		WHERE 
		a.id = ud.id AND
		(a.%I).id = re.topogeo_id AND
		re.layer_id = %L AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id
		GROUP BY ud.id',
	border_topo_info.topology_name,
	border_topo_info.topology_name,
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name,
	border_topo_info.layer_feature_column,
  border_layer_id
    );
		EXECUTE command_string;


		-- find all edges intersected by input by but not input line it self by using ttt2_final_edge_list_for_intersect_line a ;
		-- TODO this is already done above most times but in scases where the input line is not changed all we have to do it
		-- TDOO is this faster ? or should we just use to simple feature ???
		
		--command_string := topo_update.create_temp_tbl_as('ttt2_final_edge_list_for_intersect_line','SELECT * FROM ttt2_new_topo_rows_in_org_table limit 0');
		command_string := topo_update.create_temp_tbl_def('ttt2_final_edge_list_for_intersect_line','(id int, edge_id int, geom geometry)');
		EXECUTE command_string;
		
	--	alter table ttt2_final_edge_list_for_intersect_line
--		add COLUMN edge_id int,
 --   	add COLUMN geom geometry;
    	
    	-- TRUNCATE TABLE ttt2_final_edge_list_for_intersect_line;
    command_string := '
		INSERT INTO ttt2_final_edge_list_for_intersect_line (id,edge_id,geom)
		SELECT distinct ud.id as id, ed.edge_id as edge_id, ed.geom AS geom
	    FROM 
		' || quote_ident(border_topo_info.topology_name) || '.relation re,
		ttt2_intersection_id ud, 
		' || quote_ident(border_topo_info.topology_name) || '.edge_data ed,
		' || quote_ident(border_topo_info.layer_schema_name) || '.' || quote_ident(border_topo_info.layer_table_name) || ' a,
		ttt2_final_edge_list_for_input_line fl
		WHERE 
		a.id = ud.id AND
		(a.' || quote_ident(border_topo_info.layer_feature_column) || ').id = re.topogeo_id AND
		re.layer_id = ' || border_layer_id || ' AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		ST_Intersects(fl.geom,ed.geom)
    ';
		EXECUTE command_string;
	
		
		-- find out eges in the touching objects that does not intesect withinput line and that also needs to be recreated
		command_string := topo_update.create_temp_tbl_def('ttt2_final_edge_left_list_intersect_line','(id int, edge_id int, geom geometry)');
		EXECUTE command_string;
		-- TRUNCATE TABLE ttt2_final_edge_left_list_intersect_line;

    command_string := '
		INSERT INTO ttt2_final_edge_left_list_intersect_line
		SELECT distinct ud.id, ed.edge_id, ed.geom AS geom
	    FROM 
		' || quote_ident(border_topo_info.topology_name) || '.relation re,
		ttt2_intersection_id ud, 
		' || quote_ident(border_topo_info.topology_name) || '.edge_data ed,
		' || quote_ident(border_topo_info.layer_schema_name) || '.' || quote_ident(border_topo_info.layer_table_name) || ' a
		WHERE 
		a.id = ud.id AND
		(a.' || quote_ident(border_topo_info.layer_feature_column) || ').id = re.topogeo_id AND
		re.layer_id = ' || border_layer_id || ' AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		NOT EXISTS (SELECT 1 FROM ttt2_final_edge_list_for_intersect_line WHERE ed.edge_id = edge_id);
    ';
		EXECUTE command_string;
	
		
	
	-- we are only interested in intersections with two or more edges are involved
	-- so remove this id with less than 2  
	-- Having this as rule is causeing other problems like it's difficult to recreate the problem.
	--	DELETE FROM ttt2_final_edge_list_for_intersect_line a
	--	USING 
	--	( 
	--		SELECT g.id FROM
	--		(SELECT e.id, count(*) AS num FROM  ttt2_final_edge_list_for_intersect_line AS e GROUP BY e.id) AS g
	--		WHERE num < 3
	--	) AS b
	--	WHERE a.id = b.id;
	
	
		-- for each of this edges create new separate topo objects so they are selectable for the user
		-- Update the topo objects with shared edges that stil hava 
		command_string := topo_update.create_temp_tbl_as('ttt2_new_intersected_split_objects','SELECT * FROM ttt2_new_topo_rows_in_org_table limit 0');
		EXECUTE command_string;
		-- TRUNCATE TABLE ttt2_new_intersected_split_objects;

		
		  SELECT
  	array_agg(quote_ident(update_column)) AS all_fields,
  	array_agg('a.'||quote_ident(update_column)) as all_fields_a
  INTO
  	all_fields,
  	all_fields_a
  FROM (
   SELECT distinct(key) AS update_column
   FROM ttt2_new_topo_rows_in_org_table t, json_each_text(to_json((t))) 
   WHERE key != 'id' and key != 'linje'  
  ) AS keys;
	    
  RAISE NOTICE 'Extract name of not-null all_fields_a: %', all_fields_a;
  RAISE NOTICE 'Extract name of not-null all_fields: %', all_fields;
	    
    command_string := format('
		WITH inserted AS (
			INSERT INTO %I.%I('
      || quote_ident(border_topo_info.layer_feature_column) || ','
      || array_to_string(array_remove(all_fields, border_topo_info.layer_feature_column::text),',')
      || ') SELECT topology.toTopoGeom(b.geom, %L, %L, %L), '
      || array_to_string(array_remove(all_fields_a, border_topo_info.layer_feature_column::text),',')
      || ' FROM 
			ttt2_final_edge_list_for_intersect_line b,
			%I.%I a
			WHERE a.id = b.id
			RETURNING *
		)
		INSERT INTO ttt2_new_intersected_split_objects
		SELECT * FROM inserted
    ',
    border_topo_info.layer_schema_name,
    border_topo_info.layer_table_name,
    border_topo_info.topology_name,
    border_layer_id, border_topo_info.snap_tolerance,
    border_topo_info.layer_schema_name,
    border_topo_info.layer_table_name
    );
    
    	RAISE NOTICE '%', command_string;
    	
		EXECUTE command_string;
	
	
		-- We have now added new topo objects for egdes that intersetcs no we need to modify the orignal topoobjects so we don't get any duplicates
	
		-- Clear the topology elements objects that should be updated
		command_string := format('SELECT  topology.clearTopoGeom( c.%I ) 
		FROM 
		( 
			SELECT distinct a.%I
			FROM %I.%I  a,
			ttt2_final_edge_list_for_intersect_line b
			WHERE a.id = b.id
		) AS c',
    border_topo_info.layer_feature_column,
    border_topo_info.layer_feature_column,
    border_topo_info.layer_schema_name,
    border_topo_info.layer_table_name
    );
    EXECUTE command_string;

		-- Update the topo objects with shared edges that stil hava 
    -- TODO: avoid another toTopoGeom call here
    command_string := format('UPDATE %I.%I AS a
    SET %I = topology.toTopoGeom(b.geom, %L, %L, %L)
    FROM ( 
			SELECT g.id, ST_Union(g.geom) as geom
			FROM ttt2_final_edge_left_list_intersect_line g
			GROUP BY g.id
    ) as b
    WHERE a.id = b.id',
    border_topo_info.layer_schema_name,
    border_topo_info.layer_table_name,
    border_topo_info.layer_feature_column,
    border_topo_info.topology_name, border_layer_id, 
    border_topo_info.snap_tolerance
    );
    EXECUTE command_string;
		
		-- Delete those with now egdes left both in return list
    command_string := format('
		WITH deleted AS (
			DELETE FROM %I.%I a
			USING 
			ttt2_final_edge_list_for_intersect_line b
			WHERE a.id = b.id AND
			NOT EXISTS (SELECT 1 FROM ttt2_final_edge_left_list_intersect_line c WHERE b.id = c.id)
			RETURNING a.id
		)
		DELETE FROM 
		ttt2_id_return_list a
		USING deleted
		WHERE a.id = deleted.id;
    ',
    border_topo_info.layer_schema_name,
    border_topo_info.layer_table_name
    );
    EXECUTE command_string;

		
		-- update return list
		INSERT INTO ttt2_id_return_list(id)
		SELECT a.id FROM ttt2_new_intersected_split_objects a 
		WHERE NOT EXISTS (SELECT 1 FROM ttt2_final_edge_left_list_intersect_line c WHERE a.id = c.id);

	END IF; -- }
	
	
	
	
	--------------------- Stop: split up edges when the input line intersects the line segment two times  ---------------------
	--==============================================================================
	--==============================================================================


	
	-- TODO should we also return lines that are close to or intersects and split them so it's possible to ??? 
	command_string := ' SELECT distinct tg.id AS id FROM ttt2_id_return_list tg';
	-- command_string := 'SELECT tg.id AS id FROM ' || border_topo_info.layer_schema_name || '.' || border_topo_info.layer_table_name || ' tg, new_rows_added_in_org_table new WHERE new.linje::geometry && tg.linje::geometry';
	RAISE NOTICE '%', command_string;
    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;
--}

--{ kept for backward compatility
--CREATE OR REPLACE FUNCTION topo_update.create_line_edge_domain_obj(json_feature text) 
--RETURNS TABLE(id integer) AS $$
--  SELECT topo_update.create_line_edge_domain_obj($1, 'topo_rein', 'reindrift_anlegg_linje', 'linje', 1e-10);
--$$ LANGUAGE 'sql';
--}


-- select topo_update.create_line_edge_domain_obj('{"type":"Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[23.6848135256,70.2941567505],[23.6861561246,70.2937237249],[23.6888489507,70.2928551851],[23.6896495555,70.2925466063],[23.6917889589,70.292156264],[23.6945956663,70.2918661088],[23.6965659512,70.2915742147],[23.6997477211,70.2913270875],[23.7033391524,70.2915039485],[23.7044653963,70.2916332891],[23.7071834727,70.2915684568],[23.7076455811,70.2914565778],[23.7081927635,70.2912602126],[23.7079468414,70.2907122103]]},"properties":{"reinbeitebruker_id":"YD","reindriftsanleggstype":1}}');

-- select topo_update.create_line_edge_domain_obj('{"type":"Feature","geometry":{"type":"LineString","coordinates":[[582408.943892817,7635222.4433961185],[621500.8918835252,7615523.766478926],[622417.1094145575,7630641.355740958]],"crs":{"type":"name","properties":{"name":"EPSG:32633"}}},"properties":{"Fellesegenskaper.Opphav":"Y","anleggstype":"12","reinbeitebruker_id ":"ZS","Fellesegenskaper.Kvalitet.Maalemetode":82}}');

-- This a function that will be called from the client when user is drawing a line
-- This line will be applied the data in the line layer

-- The result is a set of id's of the new line objects created

-- TODO set attributtes for the line


-- {
CREATE OR REPLACE FUNCTION
topo_update.create_nocutline_edge_domain_obj(json_feature text,
  layer_schema text, layer_table text, layer_column text,
  snap_tolerance float8,
  server_json_feature text default null)
RETURNS TABLE(id integer) AS $$
DECLARE

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this is the tolerance used for snap to 
-- TODO use as parameter put for testing we just have here for now
border_topo_info topo_update.input_meta_info ;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- the number times the input line intersects
num_edge_intersects int;

input_geo geometry;

-- holds the value for felles egenskaper from input
felles_egenskaper_linje topo_rein.sosi_felles_egenskaper;

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the target table
not_null_fields text[];

-- holde the computed value for json input reday to use
json_input_structure topo_update.json_input_structure;  

BEGIN
	
	-- TODO totally rewrite this code
	json_input_structure := topo_update.handle_input_json_props(json_feature::json,server_json_feature::json,4258);
	input_geo := json_input_structure.input_geo;

	
	
	-- get meta data the border line for the surface
	border_topo_info := topo_update.make_input_meta_info(layer_schema, layer_table , layer_column );
		-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);

	
	RAISE NOTICE 'The JSON input %',  json_feature;

	RAISE NOTICE 'border_layer_id %', border_layer_id;


	-- get the json values
	command_string := topo_update.create_temp_tbl_def('credo_ttt2_new_attributes_values','(geom geometry,properties json)');
	RAISE NOTICE 'command_string %', command_string;

	EXECUTE command_string;

	-- TRUNCATE TABLE credo_ttt2_new_attributes_values;
	INSERT INTO credo_ttt2_new_attributes_values(geom,properties)
	VALUES(json_input_structure.input_geo,json_input_structure.json_properties) ;

		-- check that it is only one row put that value into 
	-- TODO rewrite this to not use table in
	
	RAISE NOTICE 'Step::::::::::::::::: 1';

	-- TODO find another way to handle this

	felles_egenskaper_linje := json_input_structure.sosi_felles_egenskaper;
	

	RAISE NOTICE 'Step::::::::::::::::: 2';

	-- Create temporary table to receive the new record
	command_string := topo_update.create_temp_tbl_as(
	  'ttt2_new_topo_rows_in_org_table',
	  format('SELECT * FROM %I.%I LIMIT 0',
	         border_topo_info.layer_schema_name,
	         border_topo_info.layer_table_name));
	EXECUTE command_string;

  -- Insert all matching column names into temp table
	INSERT INTO ttt2_new_topo_rows_in_org_table
		SELECT r.* --, t2.geom
		FROM credo_ttt2_new_attributes_values t2,
         json_populate_record(
            null::ttt2_new_topo_rows_in_org_table,
            t2.properties) r;

  RAISE NOTICE 'Added all attributes to ttt2_new_topo_rows_in_org_table';

  -- Convert geometry to TopoGeometry, write it in the temp table
  command_string := format('UPDATE ttt2_new_topo_rows_in_org_table
    SET %I = topology.toTopoGeom(%L, %L, %L, %L)',
    border_topo_info.layer_feature_column, input_geo,
    border_topo_info.topology_name, border_layer_id,
    border_topo_info.snap_tolerance);
	EXECUTE command_string;

  RAISE NOTICE 'Converted to TopoGeometry';

  -- Add the common felles_egenskaper field
  command_string := format('UPDATE ttt2_new_topo_rows_in_org_table
    SET felles_egenskaper = %L', felles_egenskaper_linje);
	EXECUTE command_string;

  RAISE NOTICE 'Set felles_egenskaper field';

  -- Extract name of fields with not-null values:
  SELECT array_agg(quote_ident(key))
    FROM ttt2_new_topo_rows_in_org_table t, json_each_text(to_json((t)))
   WHERE value IS NOT NULL
    INTO not_null_fields;

  RAISE NOTICE 'Extract name of not-null fields: %', not_null_fields;

  -- Copy full record from temp table to actual table and
  -- update temp table with actual table values
  command_string := format(
    'WITH inserted AS ( INSERT INTO %I.%I (%s) SELECT %s FROM
ttt2_new_topo_rows_in_org_table RETURNING * ), deleted AS ( DELETE
FROM ttt2_new_topo_rows_in_org_table ) INSERT INTO
ttt2_new_topo_rows_in_org_table SELECT * FROM inserted ',
    border_topo_info.layer_schema_name,
    border_topo_info.layer_table_name,
    array_to_string(not_null_fields, ','),
    array_to_string(not_null_fields, ',')
    );
	EXECUTE command_string;

	RAISE NOTICE 'Step::::::::::::::::: 3';

	-- Find topto that intersects with the new line drawn by the end user
	-- This lines should be returned, together with the topo object created
	command_string :=
topo_update.create_temp_tbl_as('ttt2_intersection_id','SELECT * FROM ttt2_new_topo_rows_in_org_table limit 0');
	EXECUTE command_string;
	-- TRUNCATE TABLE ttt2_intersection_id;

  command_string := format('
	INSERT INTO ttt2_intersection_id
	SELECT distinct a.*  
	FROM 
	%I.%I a, 
	credo_ttt2_new_attributes_values a2,
	%I.relation re, 
	topology.layer tl,
	%I.edge_data  ed
	WHERE ST_intersects(ed.geom,a2.geom)
	AND topo_rein.get_relation_id(a.%I) = re.topogeo_id AND
re.layer_id = tl.layer_id AND tl.schema_name = %L AND 
	tl.table_name = %L AND ed.edge_id=re.element_id
	AND NOT EXISTS (SELECT 1 FROM ttt2_new_topo_rows_in_org_table nr
where a.id = nr.id)',
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name,
  border_topo_info.topology_name,
  border_topo_info.topology_name,
  border_topo_info.layer_feature_column,
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name
  );
	EXECUTE command_string;

	RAISE NOTICE 'StepA::::::::::::::::: 4';

	
	-- create a empty table hold list og id's changed.
	-- TODO this should have moved to anothe place, but we need the result below
	command_string := topo_update.create_temp_tbl_as('ttt2_id_return_list','SELECT * FROM  ttt2_new_topo_rows_in_org_table limit 0');
	EXECUTE command_string;
	-- TRUNCATE TABLE ttt2_id_return_list;

	-- update the return table with intersected rows
	INSERT INTO ttt2_id_return_list(id)
	SELECT a.id FROM ttt2_new_topo_rows_in_org_table a ;

	-- update the return table with intersected rows
	INSERT INTO ttt2_id_return_list(id)
	SELECT a.id FROM ttt2_intersection_id a ;
	
	RAISE NOTICE 'StepA::::::::::::::::: 5';

		
	
	-- TODO should we also return lines that are close to or intersects and split them so it's possible to ??? 
	command_string := ' SELECT distinct tg.id AS id FROM ttt2_id_return_list tg';
	-- command_string := 'SELECT tg.id AS id FROM ' || border_topo_info.layer_schema_name || '.' || border_topo_info.layer_table_name || ' tg, new_rows_added_in_org_table new WHERE new.linje::geometry && tg.linje::geometry';
	RAISE NOTICE '%', command_string;
    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;
--}

-- This a function that will be called from the client when user is drawing a point 
-- This line will be applied the data in the point layer

-- The result is a set of id's of the new line objects created

-- TODO set attributtes for the line


-- DROP FUNCTION FUNCTION topo_update.create_point_point_domain_obj(geo_in geometry) cascade;

--DROP FUNCTION topo_update.create_point_point_domain_obj(client_json_feature text,
--  layer_schema text, layer_table text, layer_column text,
--  snap_tolerance float8);


CREATE OR REPLACE FUNCTION topo_update.create_point_point_domain_obj(client_json_feature text,
  layer_schema text, layer_table text, layer_column text,
  snap_tolerance float8,
  server_json_feature text default null) 
RETURNS TABLE(id integer) AS $$
DECLARE

json_result text;

-- this border layer id will picked up by input parameters
point_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

-- TODO use as parameter put for testing we just have here for now
point_topo_info topo_update.input_meta_info ;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- used for logging
num_rows_affected int;

-- holde the computed value for json input reday to use
json_input_structure topo_update.json_input_structure;  

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the target table
not_null_fields text[];

BEGIN


	-- get meta data
	point_topo_info := topo_update.make_input_meta_info(layer_schema, layer_table , layer_column );
	
	-- find border layer id
	point_layer_id := topo_update.get_topo_layer_id(point_topo_info);
	
	-- parse the input values
	json_input_structure := topo_update.handle_input_json_props(client_json_feature::json,server_json_feature::json,4258);

	-- Create temporary table to receive the new record
	command_string := topo_update.create_temp_tbl_as(
	  'ttt2_new_topo_rows_in_org_table',
	  format('SELECT * FROM %I.%I LIMIT 0',point_topo_info.layer_schema_name,point_topo_info.layer_table_name));
	  
	EXECUTE command_string;
            
	-- Insert all matching column names into temp table are sent from the client
	-- This will create one row in the tmp table
	INSERT INTO ttt2_new_topo_rows_in_org_table
	SELECT * FROM json_populate_record(null::ttt2_new_topo_rows_in_org_table,json_input_structure.json_properties);
	
	RAISE NOTICE 'command_string,command_string,command_string  %',  ST_asText(json_input_structure.input_geo);

	-- update the topology with a value for this row
   	command_string := format('UPDATE ttt2_new_topo_rows_in_org_table
    SET %I = topology.toTopoGeom(%L, %L, %L, %L)',
    point_topo_info.layer_feature_column, json_input_structure.input_geo,
    point_topo_info.topology_name, point_layer_id,
    point_topo_info.snap_tolerance);
	EXECUTE command_string;

  	 -- Set felles_egenskaper column that is common for all tables
 	command_string := format('UPDATE ttt2_new_topo_rows_in_org_table
    SET felles_egenskaper = %L', json_input_structure.sosi_felles_egenskaper);
	EXECUTE command_string;

  	-- Extract name of fields with not-null values in tmp table
  	-- Only those columns will be update in the org table
  	-- To delete a value from a column you have have to set a space or create a delete command
  	-- In reindrift there is need for delete
	SELECT array_agg(quote_ident(key))
	FROM ttt2_new_topo_rows_in_org_table t, json_each_text(to_json((t)))
	WHERE value IS NOT NULL
	INTO not_null_fields;

  RAISE NOTICE 'Extract name of not-null fields: %', not_null_fields;

    -- Copy full record from temp table to actual table and
  -- update temp table with actual table values
  command_string := format(
    'WITH inserted AS ( INSERT INTO %I.%I (%s) SELECT %s FROM
ttt2_new_topo_rows_in_org_table RETURNING * ), deleted AS ( DELETE
FROM ttt2_new_topo_rows_in_org_table ) INSERT INTO
ttt2_new_topo_rows_in_org_table SELECT * FROM inserted ',
    point_topo_info.layer_schema_name,
    point_topo_info.layer_table_name,
    array_to_string(not_null_fields, ','),
    array_to_string(not_null_fields, ',')
    );
	EXECUTE command_string;

	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number num_rows_affected  %',  num_rows_affected;
	
	-- TODO should we also return lines that are close to or intersects and split them so it's possible to ??? 
	command_string := ' SELECT tg.id AS id FROM  ttt2_new_topo_rows_in_org_table tg';
	-- command_string := 'SELECT tg.id AS id FROM ' || border_topo_info.layer_schema_name || '.' || border_topo_info.layer_table_name || ' tg, new_rows_added_in_org_table new WHERE new.punkt::geometry && tg.punkt::geometry';
	RAISE NOTICE '%', command_string;
    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;

--{ kept for backward compatility
CREATE OR REPLACE FUNCTION topo_update.create_point_point_domain_obj(client_json_feature text) 
RETURNS TABLE(id integer) AS $$
  SELECT topo_update.create_point_point_domain_obj($1, 'topo_rein', 'reindrift_anlegg_punkt', 'punkt', 1e-10);
$$ LANGUAGE 'sql';
--}

--SELECT '22', topo_update.create_point_point_domain_obj('{"type": "Feature","properties":{"fellesegenskaper.forstedatafangsdato":null,"fellesegenskaper.verifiseringsdato":"2015-01-01","fellesegenskaper.oppdateringsdato":null,"fellesegenskaper.opphav":"Reindriftsforvaltningen"},"geometry":{"type":"Point","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[5.70182,58.55131]}}','topo_rein', 'reindrift_anlegg_punkt', 'punkt', 1e-10,'{"properties":{"saksbehandler":"user1","reinbeitebruker_id":null,"fellesegenskaper.opphav":"opphav ØÆÅøå"}}');
--SELECT '23', id, reinbeitebruker_id, punkt, (felles_egenskaper).opphav, saksbehandler   from topo_rein.reindrift_anlegg_punkt order by id desc limit 1;
--SELECT * from ttt_new_attributes_values;
-- This a function that will be called from the client when user is drawing a line
-- This line will be applied the data in the line layer first
-- After that will find the new surfaces created. 
-- new surfaces that was part old serface should inherit old values

-- The result is a set of id's of the new surface objects created

-- TODO set attributtes for the line
-- TODO set attributtes for the surface


-- DROP FUNCTION IF EXISTS topo_update.create_surface_edge_domain_obj(json_feature text) cascade;


CREATE OR REPLACE FUNCTION topo_update.create_surface_edge_domain_obj(client_json_feature text,
  layer_schema text, 
  surface_layer_table text, surface_layer_column text,
  border_layer_table text, border_layer_column text,
  snap_tolerance float8,
  server_json_feature text default null) 
RETURNS TABLE(result text) AS $$
DECLARE

json_result text;

new_border_data topogeometry;

-- TODO use as parameter put for testing we just have here for now
border_topo_info topo_update.input_meta_info ;
surface_topo_info topo_update.input_meta_info ;

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- used for logging
num_rows_affected int;

-- used for logging
add_debug_tables int = 0;

-- the number times the inlut line intersects
num_edge_intersects int;

-- the orignal geo that is from the user
org_geo_in geometry;

geo_in geometry;

line_intersection_result geometry;

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the target table
not_null_fields text[];

-- holde the computed value for json input reday to use
json_input_structure topo_update.json_input_structure;  

BEGIN
	
	-- get meta data the border line for the surface
	border_topo_info := topo_update.make_input_meta_info(layer_schema, border_layer_table , border_layer_column );

	-- get meta data the surface 
	surface_topo_info := topo_update.make_input_meta_info(layer_schema, surface_layer_table , surface_layer_column );
	
	-- parse the input values and find input geo and properties. 
	-- Equal properties found both in client_json_feature and server_json_feature, then the values in server_json_feature will be used.
	json_input_structure := topo_update.handle_input_json_props(client_json_feature::json,server_json_feature::json,4258);

	-- save a copy of the input geometry before modfied, used for logging later.
	org_geo_in := json_input_structure.input_geo;
	geo_in := json_input_structure.input_geo;
	
	RAISE NOTICE 'topo_update.create_surface_edge_domain_obj The input as it used before check/fixed %',  ST_AsText(geo_in);

	-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.create_surface_edge_domain_obj_t0; 
		CREATE TABLE topo_rein.create_surface_edge_domain_obj_t0(geo_in geometry, IsSimple boolean, IsClosed boolean);
		INSERT INTO topo_rein.create_surface_edge_domain_obj_t0(geo_in,IsSimple,IsClosed) VALUES(geo_in,St_IsSimple(geo_in),St_IsSimple(geo_in));
	END IF;
	
	-- modify the input if it's not simple.
	IF NOT ST_IsSimple(geo_in) THEN
		-- This is probably a crossing line so we try to build a surface
		BEGIN
			line_intersection_result := ST_BuildArea(ST_UnaryUnion(geo_in))::geometry;
			RAISE NOTICE 'topo_update.create_surface_edge_domain_obj Line intersection result is %', ST_AsText(line_intersection_result);
			geo_in := ST_ExteriorRing(line_intersection_result);
		EXCEPTION WHEN others THEN
		 	RAISE NOTICE 'topo_update.create_surface_edge_domain_obj Error code: %', SQLSTATE;
      		RAISE NOTICE 'topo_update.create_surface_edge_domain_obj Error message: %', SQLERRM;
			RAISE NOTICE 'topo_update.create_surface_edge_domain_obj Failed to to use line intersection result is %, try buffer', ST_AsText(line_intersection_result);
			geo_in := ST_ExteriorRing(ST_Buffer(line_intersection_result,0.00000000001));
		END;
		
		-- check the object after a fix
		RAISE NOTICE 'topo_update.create_surface_edge_domain_obj Fixed a non simple line to be valid simple line by using by buildArea %',  geo_in;
	ELSIF NOT ST_IsClosed(geo_in) THEN
		-- If this is not closed just check that it intersects two times with a exting border
		-- TODO make more precice check that only used edges that in varbeite surface
		-- TODO handle return of gemoerty collection
		-- thic code fails need to make a test on this 
		
		command_string := format('select ST_Union(ST_Intersection(%L,e.geom)) FROM %I.edge_data e WHERE ST_Intersects(%L,e.geom)',
  		geo_in,border_topo_info.topology_name,geo_in);
  		RAISE NOTICE 'topo_update.create_surface_edge_domain_obj command_string %', command_string;
  		EXECUTE command_string INTO line_intersection_result;

		RAISE NOTICE 'topo_update.create_surface_edge_domain_obj Line intersection result is %', ST_AsText(line_intersection_result);

		num_edge_intersects :=  (SELECT ST_NumGeometries(line_intersection_result))::int;
		
		RAISE NOTICE 'topo_update.create_surface_edge_domain_obj Found a non closed linestring does intersect % times, with any borders by using buildArea %', num_edge_intersects, geo_in;
		IF num_edge_intersects is null OR num_edge_intersects < 2 THEN
			geo_in := ST_ExteriorRing(ST_BuildArea(ST_UnaryUnion(ST_AddPoint(geo_in, ST_StartPoint(geo_in)))));
		ELSEIF num_edge_intersects > 2 THEN
			RAISE EXCEPTION 'Found a non valid linestring does intersect % times, with any borders by using buildArea %', num_edge_intersects, geo_in;
		END IF;
	END IF;

	-- check that is not null
	IF geo_in IS NULL THEN
		RAISE EXCEPTION 'The geo generated from geo_in is null %', org_geo_in;
	END IF;

	-- The geo_in is now modified and we know that it is a valid geo we can use it to create the new border. 

	IF add_debug_tables = 1 THEN
		INSERT INTO topo_rein.create_surface_edge_domain_obj_t0(geo_in,IsSimple,IsClosed) VALUES(geo_in,St_IsSimple(geo_in),St_IsClosed(geo_in));
	END IF;

	RAISE NOTICE 'topo_update.create_surface_edge_domain_obj The input as it used after check/fixed %',  ST_AsText(geo_in);
	
	-- Create the new topo object for the egde layer, this edges will be used by the new surface objects later
	new_border_data := topo_update.create_surface_edge(geo_in,border_topo_info);
	RAISE NOTICE 'topo_update.create_surface_edge_domain_obj The new topo object created for based on the input geo % in table %.%',  new_border_data, border_topo_info.layer_schema_name,border_topo_info.layer_table_name;
	
	-- Create temporary table to hold the new data for the border objects. We here use the same table structure as the restult table.
	command_string := topo_update.create_temp_tbl_as(
	  'ttt2_new_topo_rows_in_org_table',
	  format('SELECT * FROM %I.%I LIMIT 0',
	         border_topo_info.layer_schema_name,
	         border_topo_info.layer_table_name));
	EXECUTE command_string;

  	-- Insert a single row into border temp table using the columns from json input that match column names in the temp table craeted
	INSERT INTO ttt2_new_topo_rows_in_org_table
	SELECT * FROM json_populate_record(null::ttt2_new_topo_rows_in_org_table,json_input_structure.json_properties);
	
	-- TODO add a test to be sure that only a single row is inserted,

	RAISE NOTICE 'topo_update.create_surface_edge_domain_obj Added all attributes to ttt2_new_topo_rows_in_org_table';

	-- Update the single rows in border line temp table with TopoGeometry and felles egenskaper
	command_string := format('UPDATE ttt2_new_topo_rows_in_org_table
    SET %I = %L,
	 felles_egenskaper = %L',
  	border_topo_info.layer_feature_column, new_border_data,json_input_structure.sosi_felles_egenskaper);
  	EXECUTE command_string;

  	RAISE NOTICE 'topo_update.create_surface_edge_domain_obj Set felles_egenskaper field';

	-- Find name of columns with not-null values from the temp table
	-- We need this list of column names to crete a SQL to update the orignal row with new values.
	SELECT array_agg(quote_ident(key))
	  FROM ttt2_new_topo_rows_in_org_table t, json_each_text(to_json((t)))
	WHERE value IS NOT NULL
	  INTO not_null_fields;

	RAISE NOTICE 'topo_update.create_surface_edge_domain_obj Extract name of not-null fields: %', not_null_fields;

	-- Copy data from from temp table in to actual table and
	-- update temp table with actual data stored in actual table. 
	-- We will then get values for id's and default values back in to the temp table.
	command_string := format(
	    'WITH inserted AS ( INSERT INTO %I.%I (%s) SELECT %s FROM
		ttt2_new_topo_rows_in_org_table RETURNING * ), deleted AS ( DELETE
		FROM ttt2_new_topo_rows_in_org_table ) INSERT INTO
		ttt2_new_topo_rows_in_org_table SELECT * FROM inserted ',
	    border_topo_info.layer_schema_name,
	    border_topo_info.layer_table_name,
	    array_to_string(not_null_fields, ','),
	    array_to_string(not_null_fields, ',')
	);
	EXECUTE command_string;

	RAISE NOTICE 'topo_update.create_surface_edge_domain_obj Step::::::::::::::::: 3';
	
	-- Create table for the rows to be returned to the caller.
	-- The result contains list of line and surface id so the client knows alle row created. 
	DROP TABLE IF EXISTS create_surface_edge_domain_obj_r1_r; 
	CREATE TEMP TABLE create_surface_edge_domain_obj_r1_r(id int, id_type text) ;
	
	RAISE NOTICE 'topo_update.create_surface_edge_domain_obj Step::::::::::::::::: 2';

	-- Insert new line objects created
	INSERT INTO create_surface_edge_domain_obj_r1_r(id,id_type)
	SELECT id, 'L' as id_type FROM ttt2_new_topo_rows_in_org_table;
	
	-- ##############################################################
	-- We are now done with border line objects and we can start to work on the surface objects
	-- The new faces are already created so we new find them and relate our domain objects
	-- ##############################################################
	
	-- Create a new temp table to hold topo surface objects that has a relation to the edge added by the user .
	DROP TABLE IF EXISTS new_surface_data_for_edge; 
	-- find out if any old topo objects overlaps with this new objects using the relation table
	-- by using the surface objects owned by the both the new objects and the exting one
	CREATE TEMP TABLE new_surface_data_for_edge AS 
	(SELECT topo::topogeometry AS surface_topo, json_input_structure.sosi_felles_egenskaper_flate AS felles_egenskaper_flate 
	FROM topo_update.create_edge_surfaces(surface_topo_info,border_topo_info,new_border_data,geo_in,json_input_structure.sosi_felles_egenskaper_flate));
	-- We now have a list with all surfaces that intersect the line that is drwan by the user. 
	-- In this list there may areas that overlaps so we need to clean up some values
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'topo_update.create_surface_edge_domain_obj Number of topo surfaces added to table new_surface_data_for_edge   %',  num_rows_affected;
	
	-- Clean up old surface and return a list of the objects that should be returned to the user for further processing
	DROP TABLE IF EXISTS res_from_update_domain_surface_layer; 
	CREATE TEMP TABLE res_from_update_domain_surface_layer AS 
	(SELECT topo::topogeometry AS surface_topo FROM topo_update.update_domain_surface_layer(surface_topo_info,border_topo_info,geo_in,'new_surface_data_for_edge'));
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'topo_update.create_surface_edge_domain_obj Number_of_rows removed from topo_update.update_domain_surface_layer   %',  num_rows_affected;

	-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.create_surface_edge_domain_obj_t1; 
		CREATE TABLE topo_rein.create_surface_edge_domain_obj_t1 AS 
		(SELECT surface_topo::geometry AS geo , surface_topo::text AS topo FROM new_surface_data_for_edge);

		-- get the reslt from topo_update.update_domain_surface_layer
		DROP TABLE IF EXISTS topo_rein.create_surface_edge_domain_obj_t2; 
		CREATE TABLE topo_rein.create_surface_edge_domain_obj_t2 AS 
		(SELECT surface_topo::geometry AS geo , surface_topo::text AS topo FROM res_from_update_domain_surface_layer);
		
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.create_surface_edge_domain_obj_t1_p; 
		CREATE TABLE topo_rein.create_surface_edge_domain_obj_t1_p AS 
		(SELECT ST_PointOnSurface(surface_topo::geometry) AS geo , surface_topo::text AS topo FROM new_surface_data_for_edge);

	END IF;
  
	IF ST_IsClosed(geo_in) THEN 
		command_string := format('INSERT INTO create_surface_edge_domain_obj_r1_r(id,id_type) ' ||
		'SELECT tg.id AS id, ''S''::text AS id_type FROM ' || 
		surface_topo_info.layer_schema_name || '.' || surface_topo_info.layer_table_name || 
		' tg, new_surface_data_for_edge new ' || 
		'WHERE (new.surface_topo).id = (tg.omrade).id AND ' || 
		'ST_intersects(ST_PointOnSurface((new.surface_topo)::geometry), ST_MakePolygon(%1$L))'
		,geo_in);
    	RAISE NOTICE 'topo_update.create_surface_edge_domain_obj A closed objects only return objects in %', command_string;
  	ELSE	
		command_string := 'INSERT INTO create_surface_edge_domain_obj_r1_r(id,id_type) ' ||
		' SELECT tg.id AS id, ''S'' AS id_type FROM ' || 
		surface_topo_info.layer_schema_name || '.' || surface_topo_info.layer_table_name || ' tg, new_surface_data_for_edge new ' || 
		'WHERE (new.surface_topo).id = (tg.omrade).id ';
	END IF;

	EXECUTE command_string;

	command_string := 'SELECT json_agg(row_to_json(t.*))::text FROM create_surface_edge_domain_obj_r1_r AS t';

	
    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;



--{ kept for backward compatility
--CREATE OR REPLACE FUNCTION topo_update.create_surface_edge_domain_obj(json_feature text) 
--RETURNS TABLE(result text) AS $$
--  SELECT topo_update.create_surface_edge_domain_obj($1, 'topo_rein', 'arstidsbeite_var_flate', 'omrade', 'arstidsbeite_var_grense','grense',  1e-10);
--$$ LANGUAGE 'sql';
--}
-- delete line with given id from given layer

CREATE OR REPLACE FUNCTION topo_update.delete_topo_line(id_in int,layer_schema text, layer_table text, layer_column text) 
RETURNS int AS $$DECLARE

-- holds the num rows affected when needed
num_rows_affected int;

-- hold common needed in this proc
border_topo_info topo_update.input_meta_info ;

-- holds dynamic sql to be able to use the same code for different
command_string text;

BEGIN

	-- get meta data
	border_topo_info := topo_update.make_input_meta_info(layer_schema, layer_table , layer_column );

	-- %s interpolates the corresponding argument as a string; %I escapes its argument as an SQL identifier; %L escapes its argument as an SQL literal; %% outputs a literal %.
	
	-- Find linear objects related to his edges 
    command_string := FORMAT('
    DROP TABLE IF EXISTS ttt_edge_list;
    CREATE TEMP TABLE ttt_edge_list AS 
    (
		select distinct ed.edge_id
	    FROM 
		%1$I.relation re,
		%2$I.%3$I al, 
		%1$I.edge_data ed
		WHERE 
		al.id = %4$L AND
		(al.%5$I).id = re.topogeo_id AND
		re.layer_id =  %6$L AND 
		re.element_type = %7$L AND  
		ed.edge_id = re.element_id AND
		NOT EXISTS ( SELECT 1 FROM %1$I.relation re2 WHERE  ed.edge_id = re2.element_id AND re2.topogeo_id != re.topogeo_id) 
    )',
    border_topo_info.topology_name,
    border_topo_info.layer_schema_name,
	border_topo_info.layer_table_name,
	id_in,
	border_topo_info.layer_feature_column,
	border_topo_info.border_layer_id,
	border_topo_info.element_type
	);
	RAISE NOTICE 'command_string %', command_string;
  	EXECUTE command_string;

   
  	-- Clear the topogeom before delete
	command_string := FORMAT('SELECT topology.clearTopoGeom(a.%I) FROM %I.%I  a WHERE a.id = %L',
	border_topo_info.layer_feature_column,
 	border_topo_info.layer_schema_name,
  	border_topo_info.layer_table_name,
  	id_in
  	);
	RAISE NOTICE 'command_string %', command_string;
  	EXECUTE command_string;


	-- Delete the line from the org table
	command_string := FORMAT('DELETE FROM %I.%I a WHERE a.id = %L',
	border_topo_info.layer_schema_name,
  	border_topo_info.layer_table_name,
  	id_in
  	);
	RAISE NOTICE 'command_string %', command_string;
  	EXECUTE command_string;

	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Rows deleted  %',  num_rows_affected;
	
	

			-- Remove edges not used from the edge table
 	command_string := FORMAT('
			SELECT ST_RemEdgeModFace(%1$L, ed.edge_id)
			FROM 
			ttt_edge_list ued,
			%1$I.edge_data ed
			WHERE 
			ed.edge_id = ued.edge_id 
			',
			border_topo_info.topology_name
		);

	RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string;
	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;



--{ kept for backward compatility
CREATE OR REPLACE FUNCTION topo_update.delete_topo_line(id_in int) 
RETURNS TABLE(id integer) AS $$
  SELECT topo_update.delete_topo_line($1, 'topo_rein', 'reindrift_anlegg_linje', 'linje');
$$ LANGUAGE 'sql';
--}



-- delete line that intersects with given point

CREATE OR REPLACE FUNCTION topo_update.delete_topo_point(id_in int,layer_schema text, layer_table text, layer_column text)  
RETURNS int AS $$DECLARE


-- holds the num rows affected when needed
num_rows_affected int;

-- holds dynamic sql to be able to use the same code for different
command_string text;

BEGIN

	command_string := format('SELECT topology.clearTopoGeom(%s) FROM  %I.%I r WHERE id = %s',
	layer_column,
    layer_schema,
    layer_table,
    id_in);

	RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string;

    command_string := format('DELETE FROM %I.%I r
	WHERE id = %s',
    layer_schema,
    layer_table,
    id_in);

    RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Rows deleted  %',  num_rows_affected;
	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;

--{ kept for backward compatility
CREATE OR REPLACE FUNCTION topo_update.delete_topo_point(id_in int) 
RETURNS TABLE(id integer) AS $$
  SELECT topo_update.delete_topo_point($1, 'topo_rein', 'reindrift_anlegg_punkt', 'punkt');
$$ LANGUAGE 'sql';
--}
-- delete surface that intersects with given point

CREATE OR REPLACE FUNCTION topo_update.delete_topo_surface(id_in int,  layer_schema text, 
  surface_layer_table text, surface_layer_column text,
  border_layer_table text, border_layer_column text
) 
RETURNS int AS $$DECLARE

num_rows int;


-- TODO use as parameter put for testing we just have here for now
border_topo_info topo_update.input_meta_info ;
surface_topo_info topo_update.input_meta_info ;

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- holds the num rows affected when needed
num_rows_affected int;

-- number of rows to delete from org table
num_rows_to_delete int;

-- Geometry
delete_surface geometry;


BEGIN
	
	-- get meta data
	border_topo_info := topo_update.make_input_meta_info(layer_schema, border_layer_table , border_layer_column );
	surface_topo_info := topo_update.make_input_meta_info(layer_schema, surface_layer_table , surface_layer_column );

	command_string := FORMAT('SELECT %I::geometry FROM %I.%I r WHERE id = %L',
	surface_topo_info.layer_feature_column,
	surface_topo_info.layer_schema_name,
	surface_topo_info.layer_table_name,
	id_in
	);
	-- RAISE NOTICE '%', command_string;
    EXECUTE command_string INTO delete_surface;
        

    command_string := FORMAT('SELECT topology.clearTopoGeom(%I) FROM %I.%I r
    WHERE id = %L',
	surface_topo_info.layer_feature_column,
	surface_topo_info.layer_schema_name,
	surface_topo_info.layer_table_name,
	id_in
    );

    EXECUTE command_string;

    command_string := FORMAT('DELETE FROM %I.%I r
    WHERE id = %L',
	surface_topo_info.layer_schema_name,
	surface_topo_info.layer_table_name,
	id_in
    );

    RAISE NOTICE '%', command_string;

    EXECUTE command_string;

    GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

    RAISE NOTICE 'Rows deleted  %',  num_rows_affected;

    -- Find unused edges 
    DROP TABLE IF EXISTS ttt_unused_edge_ids;
    CREATE TEMP TABLE ttt_unused_edge_ids AS 
    (
		SELECT topo_rein.get_edges_within_faces(array_agg(x),border_topo_info) AS id from  topo_rein.get_unused_faces(surface_topo_info) x
    );
    
    -- Find linear objects related to his edges 
    DROP TABLE IF EXISTS ttt_affected_border_objects;
    command_string := FORMAT('CREATE TEMP TABLE ttt_affected_border_objects AS 
    (
		select distinct ud.id
	    FROM 
		%I.relation re,
		%I.%I ud, 
		%I.edge_data ed,
		ttt_unused_edge_ids ued
		WHERE 
		(ud.%I).id = re.topogeo_id AND
		re.layer_id =  %L AND 
		re.element_type = %L AND
		ed.edge_id = re.element_id AND
		ed.edge_id = ANY(ued.id)
    )',
    border_topo_info.topology_name,
    border_topo_info.layer_schema_name,
	border_topo_info.layer_table_name,
    border_topo_info.topology_name,
   	border_topo_info.layer_feature_column,
   	border_topo_info.border_layer_id,
    border_topo_info.element_type
	);
	-- RAISE NOTICE '%', command_string;
    EXECUTE command_string;
    
    -- Create geoms for for linal objects with out edges that will be deleted
    DROP TABLE IF EXISTS ttt_new_border_objects;
    command_string := FORMAT('CREATE TEMP TABLE ttt_new_border_objects AS 
    (
		SELECT ud.id, ST_Union(ed.geom) AS geom 
	    FROM 
		%I.relation re,
		%I.%I ud, 
		%I.edge_data ed,
		ttt_unused_edge_ids ued,
		ttt_affected_border_objects ab
		WHERE 
		ab.id = ud.id AND
		(ud.%I).id = re.topogeo_id AND
		re.layer_id =  %L AND 
		re.element_type = %L AND
		ed.edge_id = re.element_id AND
		NOT (ed.edge_id = ANY(ued.id))
		GROUP BY ud.id
    )',
    border_topo_info.topology_name,
    border_topo_info.layer_schema_name,
	border_topo_info.layer_table_name,
    border_topo_info.topology_name,
    border_topo_info.layer_feature_column,
    border_topo_info.border_layer_id,
    border_topo_info.element_type
    
	);
	-- RAISE NOTICE '%', command_string;
    EXECUTE command_string;

	
    -- Delete border topo objects
    command_string := FORMAT('SELECT topology.clearTopoGeom(a.%I) 
	FROM %I.%I  a,
    ttt_affected_border_objects b
	WHERE a.id = b.id', 
	border_topo_info.layer_feature_column,
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name
	);
	-- RAISE NOTICE '%', command_string;
    EXECUTE command_string;

	
	
 	-- Remove edges not used from the edge table
 	command_string := FORMAT('
		SELECT ST_RemEdgeModFace(%1$L, ed.edge_id)
		FROM 
		ttt_unused_edge_ids ued,
		%2$s ed
		WHERE 
		ed.edge_id = ANY(ued.id) 
		',
		border_topo_info.topology_name,
		border_topo_info.topology_name || '.edge_data'
	);
	-- RAISE NOTICE '%', command_string;
    EXECUTE command_string;
	
	-- Delete those rows don't have any geoms left
	command_string := FORMAT('DELETE FROM %I.%I  a
	USING ttt_new_border_objects b
	WHERE a.id = b.id AND b.geom IS NULL',
  border_topo_info.layer_schema_name,
  border_topo_info.layer_table_name
	);
	-- RAISE NOTICE '%', command_string;
    EXECUTE command_string;

	

	
		command_string := format('UPDATE %I.%I AS a
	SET %I = topology.toTopoGeom(b.geom, %L, %L, %L)
	FROM ttt_new_border_objects b
	WHERE a.id = b.id AND b.geom IS NOT NULL',
  	border_topo_info.layer_schema_name,
  	border_topo_info.layer_table_name,
	border_topo_info.layer_feature_column,
	border_topo_info.topology_name, 
	border_topo_info.border_layer_id, 
	border_topo_info.snap_tolerance
  );

	-- RAISE NOTICE '%', command_string;
    EXECUTE command_string;

    
	
	
    RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;


--{ kept for backward compatility
CREATE OR REPLACE FUNCTION topo_update.delete_topo_surface(id_in int) 
RETURNS int AS $$
 SELECT topo_update.delete_topo_surface($1, 'topo_rein', 'arstidsbeite_var_flate', 'omrade', 'arstidsbeite_var_grense','grense');
$$ LANGUAGE 'sql';
--}
-- This is a function that is used to build surface based on the border objects that alreday exits
-- topoelementarray_data is reffrerance to the egdes in this layer

--DROP FUNCTION IF EXISTS topo_update.build_surface_domain_obj(json_feature text,topoelementarray_data topoelementarray, 
--  layer_schema text, surface_layer_table text, surface_layer_column text,snap_tolerance float8) cascade;


CREATE OR REPLACE FUNCTION topo_update.build_surface_domain_obj(
json_feature text,
topoelementarray_data topoelementarray, 
  layer_schema text, 
  surface_layer_table text, surface_layer_column text,
  snap_tolerance float8) 
RETURNS TABLE(id integer) AS $$
DECLARE

json_result text;

surface_topo_info topo_update.input_meta_info ;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- used for logging
num_rows_affected int;

-- the number times the inlut line intersects
num_edge_intersects int;

-- holds the value for felles egenskaper from input
simple_sosi_felles_egenskaper_flate topo_rein.simple_sosi_felles_egenskaper;
felles_egenskaper_flate topo_rein.sosi_felles_egenskaper;

surface_topogeometry topogeometry;

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the target table
update_fields text[];

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the temp table
update_fields_t text[];


BEGIN
	
	-- get meta data the surface 
	surface_topo_info := topo_update.make_input_meta_info(layer_schema, surface_layer_table , surface_layer_column );
	
	CREATE TEMP TABLE IF NOT EXISTS ttt2_new_attributes_values(properties json, felles_egenskaper topo_rein.sosi_felles_egenskaper);
	TRUNCATE TABLE ttt2_new_attributes_values;
	
	-- parse the json data to get properties and the new geometry
	INSERT INTO ttt2_new_attributes_values(properties)
	SELECT 
	properties
	FROM (
		SELECT 
			to_json(feat->'properties')::json  AS properties
		FROM (
		  	SELECT json_feature::json AS feat
		) AS f
	) AS e;

	-- check that it is only one row put that value into 
	-- TODO rewrite this to not use table in
	IF (SELECT count(*) FROM ttt2_new_attributes_values) != 1 THEN
		RAISE EXCEPTION 'Not valid json_feature %', json_feature;
	ELSE 
		-- get the felles egenskaper
		SELECT * INTO simple_sosi_felles_egenskaper_flate 
		FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
		(select properties from ttt2_new_attributes_values) );

	END IF;

	
	-- Create a temp table tha will hodl the row will be inserted at the end
	command_string := topo_update.create_temp_tbl_as(
	  'bsdo_ttt2_new_topo_rows_in_org_table',
	  format('SELECT * FROM %I.%I LIMIT 0',
	  surface_topo_info.layer_schema_name,
	         surface_topo_info.layer_table_name));
	EXECUTE command_string;

	 -- insert one row to be able create update field
	insert into bsdo_ttt2_new_topo_rows_in_org_table(id) values(1); 
	
-- Extract name of fields with not-null values:
  -- Extract name of fields with not-null values and append the table prefix n.:
  -- Only update json value that exits 
  SELECT
  	array_agg(quote_ident(update_column)) AS update_fields,
  	array_agg('n.'||quote_ident(update_column)) as update_fields_t
  INTO
  	update_fields,
  	update_fields_t
  FROM (
   SELECT distinct(key) AS update_column
   FROM bsdo_ttt2_new_topo_rows_in_org_table t, json_each_text(to_json((t)))  ,
   (SELECT json_object_keys(t2.properties) as res FROM ttt2_new_attributes_values t2 ) as key_list
   WHERE key != 'id' AND 
   key = key_list.res 
  ) AS keys;

    
  RAISE NOTICE 'Extract name of not-null fields: %', update_fields_t;
  RAISE NOTICE 'Extract name of not-null fields: %', update_fields;

  -- we have got the update filds so we don'n need this row any more
  truncate bsdo_ttt2_new_topo_rows_in_org_table;
  
	-- get the felles egeskaper flate object
	felles_egenskaper_flate := topo_rein.get_rein_felles_egenskaper_flate(simple_sosi_felles_egenskaper_flate);

	-- create the topo object 
	surface_topogeometry := topology.CreateTopoGeom( surface_topo_info.topology_name,surface_topo_info.element_type,surface_topo_info.border_layer_id,topoelementarray_data); 

  	-- Insert all matching column names into temp table bsdo_ttt2_new_topo_rows_in_org_table 
  	command_string := format('INSERT INTO bsdo_ttt2_new_topo_rows_in_org_table(%s,felles_egenskaper,%s)
		SELECT 
		%s,
		$1 as felles_egenskaper,
		$2 AS %s
		FROM ttt2_new_attributes_values t2,
         json_populate_record(
            null::bsdo_ttt2_new_topo_rows_in_org_table,
            t2.properties) r',
    array_to_string(update_fields, ','),
    surface_topo_info.layer_feature_column,
    array_to_string(update_fields, ','),
	surface_topo_info.layer_feature_column);

	RAISE NOTICE 'command_string %' , command_string;

	EXECUTE command_string USING felles_egenskaper_flate, surface_topogeometry;
	
	-- Insert the rows in to master table 

	command_string := format('
	WITH inserted AS ( 
	INSERT INTO %I.%I(%s,felles_egenskaper,%s)
	SELECT %s,felles_egenskaper,%s FROM bsdo_ttt2_new_topo_rows_in_org_table RETURNING * ), 
	deleted AS ( DELETE FROM bsdo_ttt2_new_topo_rows_in_org_table ) 
	INSERT INTO bsdo_ttt2_new_topo_rows_in_org_table SELECT * FROM inserted ',
	surface_topo_info.layer_schema_name,
	surface_topo_info.layer_table_name,
    array_to_string(update_fields, ','),
    surface_topo_info.layer_feature_column,
    array_to_string(update_fields, ','),
	surface_topo_info.layer_feature_column);

	RAISE NOTICE 'command_string %' , command_string;

	EXECUTE command_string USING felles_egenskaper_flate, surface_topogeometry;


	command_string := 'SELECT t.id FROM bsdo_ttt2_new_topo_rows_in_org_table t';

    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;



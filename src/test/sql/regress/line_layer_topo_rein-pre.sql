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
	"felles_egenskaper.forstedatafangsdato" date , 
	"felles_egenskaper.verifiseringsdato" date ,
	"felles_egenskaper.oppdateringsdato" date ,
	"felles_egenskaper.opphav" varchar, 
	"felles_egenskaper.kvalitet.maalemetode" int 
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
felles_egenskaper topo_rein.sosi_felles_egenskaper NOT NULL


);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata', 'topo_rein', 'arstidsbeite_var_grense', 'grense', 'LINESTRING') As new_layer_id;

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

-- added because of performance, used by wms and sp on
-- update in the same transaction as the topo objekt
simple_geo geometry(MultiPolygon,4258) 



);

-- add a topogeometry column that is a ref to polygpn surface
-- should this be called område/omrade or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata', 'topo_rein', 'arstidsbeite_var_flate', 'omrade', 'POLYGON'
	-- get parrentid
	--,(SELECT layer_id FROM topology.layer l, topology.topology t 
	--WHERE t.name = 'topo_rein_sysdata' AND t.id = l. topology_id AND l.schema_name = 'topo_rein' AND l.table_name = 'arstidsbeite_var_grense' AND l.feature_column = 'grense')::int
) As new_layer_id;




COMMENT ON TABLE topo_rein.arstidsbeite_var_flate IS 'Contains attributtes for rein and ref. to topo surface data. For more info see http://www.statkart.no/Documents/Standard/SOSI kap3 Produktspesifikasjoner/FKB 4.5/4-rein-2014-03-01.pdf';

COMMENT ON COLUMN topo_rein.arstidsbeite_var_flate.id IS 'Unique identifier of a surface';

COMMENT ON COLUMN topo_rein.arstidsbeite_var_flate.felles_egenskaper IS 'Sosi common meta attribute part of kvaliet TODO create user defined type ?';

-- COMMENT ON COLUMN topo_rein.arstidsbeite_var_flate.geo IS 'This holds the ref to topo_rein_sysdata.relation table, where we find pointers needed top build the the topo surface';

-- create function basded index to get performance
CREATE INDEX topo_rein_arstidsbeite_var_flate_geo_relation_id_idx ON topo_rein.arstidsbeite_var_flate(topo_rein.get_relation_id(omrade));	

COMMENT ON INDEX topo_rein.topo_rein_arstidsbeite_var_flate_geo_relation_id_idx IS 'A function based index to faster find the topo rows for in the relation table';


-- create index on topo_rein_sysdata.edge
CREATE INDEX topo_rein_sysdata_edge_simple_geo_idx ON topo_rein.arstidsbeite_var_flate USING GIST (simple_geo); 


--COMMENT ON INDEX topo_rein.topo_rein_sysdata_edge_simple_geo_idx IS 'A index created to avoid building topo when the data is used for wms like mapserver which do no use the topo geometry';

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

-- angir hvilket reinbeitedistrikt som bruker beiteområdet 
-- Definition -- indicates which reindeer pasture district uses the pasture area
-- TODO add not null
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')), 

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmarksbeite 
-- TODO add not null
reindriftsanleggstype int CHECK ( (reindriftsanleggstype > 0 AND reindriftsanleggstype < 8) or (reindriftsanleggstype=12)) 


);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata', 'topo_rein', 'reindrift_anlegg_linje', 'linje', 'LINESTRING') As new_layer_id;


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

-- angir hvilket reinbeitedistrikt som bruker beiteområdet 
-- Definition -- indicates which reindeer pasture district uses the pasture area
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA')), 

-- spesifikasjon av type teknisk anlegg som er etablert i forbindelse med utmarksbeite 
reindriftsanleggstype int CHECK (reindriftsanleggstype > 9 AND reindriftsanleggstype < 21) 


);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata', 'topo_rein', 'reindrift_anlegg_punkt', 'punkt', 'POINT') As new_layer_id;


-- create function basded index to get performance
CREATE INDEX topo_rein_reindrift_anlegg_punkt_geo_relation_id_idx ON topo_rein.reindrift_anlegg_punkt(topo_rein.get_relation_id(punkt));	

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

-- angir hvilket reinbeitedistrikt som bruker beiteområdet 
-- Definition -- indicates which reindeer pasture district uses the pasture area
-- TODO add not null
reinbeitebruker_id varchar(3) CHECK (reinbeitebruker_id IN ('XI','ZA','ZB','ZC','ZD','ZE','ZF','ØG','UW','UX','UY','UZ','ØA','ØB','ØC','ØE','ØF','ZG','ZH','ZJ','ZS','ZL','ZÅ','YA','YB','YC','YD','YE','YF','YG','XM','XR','XT','YH','YI','YJ','YK','YL','YM','YN','YP','YX','YR','YS','YT','YU','YV','YW','YY','XA','XD','XE','XG','XH','XJ','XK','XL','XM','XR','XS','XT','XN','XØ','XP','XU','XV','XW','XZ','XX','XY','WA','WB','WD','WF','WK','WL','WN','WP','WR','WS','WX','WZ','VA','VF','VG','VJ','VM','VR','YQA','YQB','YQC','ZZ','RR','ZQA'))

);

-- add a topogeometry column to get a ref to the borders
-- should this be called grense or geo ?
SELECT topology.AddTopoGeometryColumn('topo_rein_sysdata', 'topo_rein', 'rein_trekklei_linje', 'linje', 'LINESTRING') As new_layer_id;


-- create function basded index to get performance
CREATE INDEX topo_rein_rein_trekklei_linje_geo_relation_id_idx ON topo_rein.rein_trekklei_linje(topo_rein.get_relation_id(linje));	
-- DROP VIEW topo_rein.arstidsbeite_var_flate_v cascade ;


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

-- DROP VIEW IF EXISTS topo_rein.arstidsbeite_var_topojson_flate_v cascade ;


CREATE OR REPLACE VIEW topo_rein.arstidsbeite_var_topojson_flate_v 
AS
select 
id,
reindrift_sesongomrade_kode,
reinbeitebruker_id,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangsdato", 
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav", 
omrade 
from topo_rein.arstidsbeite_var_flate al;

--select * from topo_rein.arstidsbeite_var_topojson_flate_v-- DROP VIEW topo_rein.reindrift_anlegg_linje_v cascade ;


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
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangsdato", 
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav", 
((al.felles_egenskaper).kvalitet).maalemetode AS "fellesegenskaper.maalemetode",
linje
from topo_rein.reindrift_anlegg_linje al;

-- select * from topo_rein.reindrift_anlegg_topojson_linje_v ;


DROP VIEW IF EXISTS topo_rein.reindrift_anlegg_topojson_punkt_v cascade ;


CREATE OR REPLACE VIEW topo_rein.reindrift_anlegg_topojson_punkt_v 
AS
select 
id,
reinbeitebruker_id,
reindriftsanleggstype,
(al.felles_egenskaper).forstedatafangstdato AS "fellesegenskaper.forstedatafangsdato", 
(al.felles_egenskaper).verifiseringsdato AS "fellesegenskaper.verifiseringsdato",
(al.felles_egenskaper).oppdateringsdato AS "fellesegenskaper.oppdateringsdato",
(al.felles_egenskaper).opphav AS "fellesegenskaper.opphav", 
((al.felles_egenskaper).kvalitet).maalemetode AS "fellesegenskaper.maalemetode",
punkt
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

CREATE OR REPLACE FUNCTION topo_rein.findExtent(schema_name text, table_name text , geocolumn_name text )
RETURNS geometry AS $$
DECLARE
bb geometry = null;
command_string text;
BEGIN
	IF (EXISTS 
			( SELECT * FROM topo_rein_sysdata.edge_data  limit 1)
	) THEN
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
CREATE OR REPLACE FUNCTION topo_rein.get_edges_within_faces(faces int[], layer_id_in int )
RETURNS int[] AS
$$
  SELECT array_agg(e.edge_id)
  FROM topo_rein_sysdata.edge_data e,
  topo_rein_sysdata.relation re
  WHERE e.left_face = ANY ( faces )
    AND e.right_face = ANY ( faces )
    AND e.edge_id = re.element_id 
    AND re.layer_id =  layer_id_in;
		
$$ LANGUAGE 'sql' VOLATILE;
-- Return a set of identifiers for edges within a surface TopoGeometry
--
--{
CREATE OR REPLACE FUNCTION topo_rein.get_edges_within_toposurface(tg TopoGeometry)
RETURNS int[] AS
$$
  WITH tgdata as (
    select array_agg(r.element_id) as faces
    from topo_rein_sysdata.relation r
    where topogeo_id = id($1)
      and layer_id = layer_id($1)
      and element_type = 3 -- a face
  )
  SELECT array_agg(e.edge_id)
  FROM topo_rein_sysdata.edge_data e, tgdata t
  WHERE e.left_face = ANY ( t.faces )
    AND e.right_face = ANY ( t.faces );
$$ LANGUAGE 'sql' VOLATILE;


-- used to get felles egenskaper for with all values
-- including måle metode

CREATE OR REPLACE FUNCTION topo_rein.get_rein_felles_egenskaper(felles topo_rein.simple_sosi_felles_egenskaper ) 
RETURNS topo_rein.sosi_felles_egenskaper AS $$DECLARE

DECLARE 

res topo_rein.sosi_felles_egenskaper ;
res_kvalitet topo_rein.sosi_kvalitet;


BEGIN

res := topo_rein.get_rein_felles_egenskaper_flate(felles);
	

res_kvalitet.maalemetode := (felles)."felles_egenskaper.kvalitet.maalemetode";
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
res.verifiseringsdato :=  (felles)."felles_egenskaper.verifiseringsdato";
IF res.verifiseringsdato is null THEN
	res.verifiseringsdato :=  current_date;
END IF;

-- if we have a value for felles_egenskaper.forstedatafangstdato or else use verifiseringsdato
res.forstedatafangstdato :=  (felles)."felles_egenskaper.forstedatafangsdato";
IF res.forstedatafangstdato is null THEN
	res.forstedatafangstdato :=  res.verifiseringsdato;
END IF;

-- if we have a value for oppdateringsdato or else use current date
-- The only time will have values for oppdateringsdato is when we transfer data from simple feature.
-- From the client this should always be null
-- TODO Or should er here always use current_date
--res.oppdateringsdato :=  (felles)."felles_egenskaper.oppdateringsdato";
--IF res.oppdateringsdato is null THEN
	res.oppdateringsdato :=  current_date;
--END IF;

-- TODO verufy that we always should reset oppdaterings dato
-- If this is the case we may remove oppdateringsdato

-- TODO that will be a input from the user
-- How to handle lines that crosses municipality
res.opphav :=  (felles)."felles_egenskaper.opphav";

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
felles topo_rein.simple_sosi_felles_egenskaper ) 
RETURNS topo_rein.sosi_felles_egenskaper AS $$DECLARE

DECLARE 

BEGIN

	
-- if we have a value for felles_egenskaper.verifiseringsdato or else use current date
res.verifiseringsdato :=  (felles)."felles_egenskaper.verifiseringsdato";
IF res.verifiseringsdato is null THEN
	res.verifiseringsdato :=  current_date;
END IF;

res.oppdateringsdato :=  current_date;

res.opphav :=  (felles)."felles_egenskaper.opphav";


return res;

END;
$$ LANGUAGE plpgsql IMMUTABLE ;


-- test the function with goven structure
-- (2015-01-01,,"(,,)",2015-11-04,Reindriftsforvaltningen,2015-01-01,,"(,)")
-- select * from json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,'{"reinbeitebruker_id":"XI","felles_egenskaper.forstedatafangsdato":null,"felles_egenskaper.verifiseringsdato":"2015-01-01","felles_egenskaper.oppdateringsdato":null,"felles_egenskaper.opphav":"Reindriftsforvaltningen"}');
--DO $$
--DECLARE 
--fe2 topo_rein.sosi_felles_egenskaper;
--fe topo_rein.simple_sosi_felles_egenskaper;
--BEGIN
--	SELECT * INTO fe FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
--	(select properties from topo_rein.ttt_new_attributes_values) 
--	);
--	
--	fe2 := topo_rein.get_rein_felles_egenskaper(fe);
--	RAISE NOTICE 'topo_rein.get_rein_felles_egenskapers %',  fe2;
--	RAISE NOTICE 'forstedatafangstdato %',  (fe2).forstedatafangstdato;
--	RAISE NOTICE 'verifiseringsdato %',  (fe2).verifiseringsdato;
--	RAISE NOTICE 'oppdateringsdato %',  (fe2).oppdateringsdato;
--END $$;






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

-- test the function with goven structure
--DO $$
--DECLARE 
--topo_info topo_update.input_meta_info;
--BEGIN
--	topo_info.topology_name := 'topo_rein_sysdata';
--	topo_info.layer_schema_name := 'topo_rein';
--	topo_info.layer_table_name := 'arstidsbeite_var_grense';
--	topo_info.layer_feature_column := 'grense';
--	topo_info.element_type := 2;
--	RAISE NOTICE 'topo_update.get_linestring_no_loose_ends returns %',  topo_update.get_linestring_no_loose_ends(topo_info, 
-- 	(SELECT grense FROM topo_rein.arstidsbeite_var_grense limit 1 )::topogeometry);
--END $$;

-- Find topology layer_id info for given input structure

-- DROP FUNCTION topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info);

-- Find topology layer_id info for the structure topo_update.input_meta_info

CREATE OR REPLACE FUNCTION topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info) 
RETURNS int AS $$DECLARE
DECLARE 
layer_id_res int;
BEGIN

	SELECT layer_id 
	FROM topology.layer l, topology.topology t 
	WHERE t.name = topo_info.topology_name AND
	t.id = l.topology_id AND
	l.schema_name = topo_info.layer_schema_name AND
	l.table_name = topo_info.layer_table_name AND
	l.feature_column = topo_info.layer_feature_column
	INTO layer_id_res;
	
	return layer_id_res;

END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info)  IS ' Find topology layer_id info for the structure topo_update.input_meta_info';

-- test the function with goven structure
-- DO $$
-- DECLARE 
-- topo_info topo_update.input_meta_info;
-- BEGIN
-- 	topo_info.topology_name := 'topo_rein_sysdata';
-- 	topo_info.layer_schema_name := 'topo_rein';
-- 	topo_info.layer_table_name := 'arstidsbeite_var_grense';
-- 	topo_info.layer_feature_column := 'grense';
-- 	RAISE NOTICE 'topo_update.get_topo_layer_id returns %',  topo_update.get_topo_layer_id(topo_info);
-- END $$;

-- Return the faces that are not used by any TopoGeometry
CREATE OR REPLACE FUNCTION topo_rein.get_unused_faces(layer_id_in int)
RETURNS setof int AS
$$
    SELECT f.face_id as faces
    FROM
      topo_rein_sysdata.face f
    EXCEPT
    SELECT r.element_id
    FROM
      topo_rein_sysdata.relation r,
      topology.layer l
    WHERE r.layer_id = l.layer_id 
      and l.layer_id = layer_id_in
      and l.level = 0 -- non hierarchical
      and r.element_type = 3 -- a face
$$ LANGUAGE 'sql' VOLATILE;

-- Return a set of identifiers for edges that are not covered
-- by any surface TopoGeometry
-- DROP FUNCTION topo_update.has_linestring_loose_ends(topo_info topo_update.input_meta_info, _tbl regclass) 

-- Return 1 if this line has no loose ends or the lines are not part of any surface
-- test the function with goven structure
-- DO $$
-- DECLARE 
-- topo_info topo_update.input_meta_info;
-- BEGIN
-- 	topo_info.topology_name := 'topo_rein_sysdata';
-- 	topo_info.layer_schema_name := 'topo_rein';
-- 	topo_info.layer_table_name := 'arstidsbeite_var_grense';
-- 	topo_info.layer_feature_column := 'grense';
-- 	topo_info.element_type := 2;
-- 	RAISE NOTICE 'topo_update.has_linestring_loose_ends returns %',  topo_update.has_linestring_loose_ends(topo_info, 'topo_rein.arstidsbeite_var_grense');
-- END $$;


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

-- test the function with goven structure
--DO $$
-- DECLARE 
-- topo_info topo_update.input_meta_info;
-- BEGIN
-- 	topo_info.topology_name := 'topo_rein_sysdata';
-- 	topo_info.layer_schema_name := 'topo_rein';
-- 	topo_info.layer_table_name := 'arstidsbeite_var_grense';
-- 	topo_info.layer_feature_column := 'grense';
-- 	topo_info.element_type := 2;
-- 	RAISE NOTICE 'topo_update.has_linestring_loose_ends returns %',  topo_update.has_linestring_loose_ends(topo_info, 
-- 	(SELECT grense FROM topo_rein.arstidsbeite_var_grense limit 1 )::topogeometry);
-- END $$;

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
$$ LANGUAGE plpgsql STABLE;;

-- find one row that intersecst
-- TODO find teh one with loongts egde

-- DROP FUNCTION IF EXISTS topo_update.touches(_new_topo_objects regclass,id_to_check int) ;

CREATE OR REPLACE FUNCTION topo_update.touches(_new_topo_objects regclass, id_to_check int) 
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
	    SELECT (GetTopoGeomElements(omrade))[1] face_id, id AS object_id FROM (
	      SELECT omrade, id from  %1$s 
	    ) foo
	  ),
	  ary AS ( 
	    SELECT array_agg(face_id) ids, face_id, object_id FROM faces
	    GROUP BY face_id, object_id
	  )
	  SELECT object_id, face_id, e.edge_id 
	  FROM topo_rein_sysdata.edge e, ary f
	  WHERE ( left_face = any (f.ids) and not right_face = any (f.ids) )
	     OR ( right_face = any (f.ids) and not left_face = any (f.ids) )
	  ) AS t
	  GROUP BY edge_id
  	) AS r
WHERE antall > 1
AND id_list[1] != id_list[2]
AND (id_list[1] = %2$L OR id_list[2] = %2$L)
ORDER BY id_t', _new_topo_objects, id_to_check);

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
CREATE OR REPLACE FUNCTION topo_rein.query_to_topojson(query text, srid_out int, maxdecimaldigits int)
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
      'ST_transform(e.geom,$1),$2' ||
      ')::json->>''coordinates'' ' ||
      'ORDER BY m.arc_id) FROM topo_rein_topojson_edgemap m ' ||
      'INNER JOIN ' || quote_ident(toponame) || '.edge e ' ||
      'ON (e.edge_id = m.edge_id)';
  --RAISE DEBUG '%', sql;
  EXECUTE sql USING srid_out,maxdecimaldigits INTO objary;

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

-- Create new new surface object after after the new valid intersect line is dranw

-- DROP FUNCTION topo_update.create_edge_surfaces(topo topogeometry) cascade;


CREATE OR REPLACE FUNCTION topo_update.create_edge_surfaces(new_border_data topogeometry, valid_user_geometry geometry, felles_egenskaper_flate topo_rein.sosi_felles_egenskaper) 
RETURNS SETOF topo_update.topogeometry_def AS $$
DECLARE

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this surface layer id will picked up by input parameters
surface_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

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

-- used for logging
add_debug_tables int = 0;

-- used for looping
rec RECORD;

-- used for creating new topo objects
new_surface_topo topogeometry;

BEGIN
	
	-- TODO to be moved is justed for testing now
	border_topo_info.topology_name := 'topo_rein_sysdata';
	border_topo_info.layer_schema_name := 'topo_rein';
	border_topo_info.layer_table_name := 'arstidsbeite_var_grense';
	border_topo_info.layer_feature_column := 'grense';
	border_topo_info.snap_tolerance := 0.0000000001;
	border_topo_info.element_type = 2;
	
	
	surface_topo_info.topology_name := 'topo_rein_sysdata';
	surface_topo_info.layer_schema_name := 'topo_rein';
	surface_topo_info.layer_table_name := 'arstidsbeite_var_flate';
	surface_topo_info.layer_feature_column := 'omrade';
	surface_topo_info.snap_tolerance := 0.0000000001;
	
	-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);
	RAISE NOTICE 'border_layer_id   %',  border_layer_id ;
	
	-- find surface layer id
	surface_layer_id := topo_update.get_topo_layer_id(surface_topo_info);
	RAISE NOTICE 'surface_layer_id   %',  surface_layer_id ;

	RAISE NOTICE 'The topo objected added  %',  new_border_data;
	
	-------------------- Surface ---------------------------------

	-- find new facec that needs to be creted
	DROP TABLE IF EXISTS new_faces; 
	CREATE TEMP TABLE new_faces(face_id int);

	-- find left faces
	INSERT INTO new_faces(face_id) 
	SELECT DISTINCT(fa.face_id) as face_id
	FROM 
	topo_rein_sysdata.relation re,
	topo_rein_sysdata.edge_data ed,
	topo_rein_sysdata.face fa
	WHERE 
	(new_border_data).id = re.topogeo_id AND
    re.layer_id =  border_layer_id AND 
    re.element_type = 2 AND  -- TODO use variable element_type_edge=2
    ed.edge_id = re.element_id AND
    fa.face_id=ed.left_face AND -- How do I know if a should use left or right ?? 
    fa.mbr IS NOT NULL;
    GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of face objects found on the left side  % ',  num_rows_affected;

    -- find right faces
	INSERT INTO new_faces(face_id) 
	SELECT DISTINCT(fa.face_id) as face_id
	FROM 
	topo_rein_sysdata.relation re,
	topo_rein_sysdata.edge_data ed,
	topo_rein_sysdata.face fa
	WHERE 
	(new_border_data).id = re.topogeo_id AND
    re.layer_id =  border_layer_id AND 
    re.element_type = 2 AND  -- TODO use variable element_type_edge=2
    ed.edge_id = re.element_id AND
    fa.face_id=ed.right_face AND -- How do I know if a should use left or right ?? 
    fa.mbr IS NOT NULL;
    GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of face objects found on the right side  % ',  num_rows_affected;

	DROP TABLE IF EXISTS new_surface_data; 
	-- Create a temp table to hold new surface data
	CREATE TEMP TABLE new_surface_data(surface_topo topogeometry, felles_egenskaper_flate topo_rein.sosi_felles_egenskaper);
	-- create surface geometry if a surface exits for the left side

	-- if input is a closed ring only geneate objects for faces

	-- find faces used by exting topo objects to avoid duplicates
--	DROP TABLE IF EXISTS used_topo_faces; 
--	CREATE TEMP TABLE used_topo_faces AS (
--		SELECT used_faces.face_id 
--		FROM 
--		(SELECT (GetTopoGeomElements(v.omrade))[1] AS face_id 
--		FROM topo_rein.arstidsbeite_var_flate v) as used_faces,
--		topo_rein_sysdata.face f
--		WHERE f.face_id = used_faces.face_id AND
--		f.mbr && valid_user_geometry
--	);

	-- dont't create objects faces 
--	DROP TABLE IF EXISTS valid_topo_faces; 
--	CREATE TEMP TABLE  valid_topo_faces AS (
--		SELECT f.face_id FROM
--		topo_rein_sysdata.face f
--		WHERE ST_Covers(ST_Envelope(ST_buffer(valid_user_geometry,0.0000002)),f.mbr)
--	);


	FOR rec IN SELECT distinct face_id FROM new_faces
	LOOP
		--IF  NOT EXISTS(SELECT 1 FROM used_topo_faces WHERE face_id = rec.face_id) AND
		--EXISTS(SELECT 1 FROM valid_topo_faces WHERE face_id = rec.face_id) THEN 
		-- Test if this surface already used by another topo object
			new_surface_topo := topology.CreateTopoGeom('topo_rein_sysdata',3,surface_layer_id,topology.TopoElementArray_Agg(ARRAY[rec.face_id,3])  );
			-- if not null
			IF new_surface_topo IS NOT NULL THEN
				-- check if this topo already exist
				-- TODO find out this chck is needed then we can only check on id 
	--			IF NOT EXISTS(SELECT 1 FROM topo_rein.arstidsbeite_var_flate WHERE (omrade).id = (new_surface_topo).id) AND
	--			   NOT EXISTS(SELECT 1 FROM new_surface_data WHERE (surface_topo).id = (new_surface_topo).id)
	--			THEN
					INSERT INTO new_surface_data(surface_topo,felles_egenskaper_flate) VALUES(new_surface_topo,felles_egenskaper_flate);
					RAISE NOTICE 'Use new topo object % for face % created from user input %',  new_surface_topo, rec.face_id, new_border_data;
	--			ELSE
	--				RAISE NOTICE 'Not Use new topo object % for face %',  new_surface_topo, rec.face_id;
	--			END IF;
			END IF;
		--END IF;
    END LOOP;

    
	
	-- Only used for debug
	IF add_debug_tables = 1 THEN
	
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.create_edge_surfaces_t1; 
		CREATE TABLE topo_rein.create_edge_surfaces_t1 AS 
		(SELECT * FROM topo_rein_sysdata.relation where element_type = 2 and (new_border_data).id = topogeo_id);

		DROP TABLE IF EXISTS topo_rein.create_edge_surfaces_t2; 
		CREATE TABLE topo_rein.create_edge_surfaces_t2 AS 
		(SELECT * FROM topo_rein_sysdata.edge_data);

		DROP TABLE IF EXISTS topo_rein.create_edge_surfaces_t3; 
		CREATE TABLE topo_rein.create_edge_surfaces_t3 AS 
		(SELECT * FROM topo_rein_sysdata.face);
		
		DROP TABLE IF EXISTS topo_rein.create_edge_surfaces_t4; 
		CREATE TABLE topo_rein.create_edge_surfaces_t4 AS 
		(SELECT * FROM new_faces);

			
	END IF;

	
	
	-- We now objects that are missing attribute values that should be inheretaded from mother object.

		
	RETURN QUERY SELECT a.surface_topo::topogeometry as t FROM new_surface_data a;
	
END;
$$ LANGUAGE plpgsql;



-- SELECT * FROM topo_update.create_edge_surfaces((select topo_update.create_surface_edge('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.55375, 5.70152 58.55373, 5.70182 58.55131)'))::topogeometry)
		
-- this creates a valid edge based on the surface that alreday exits
-- the geometry in must be in the same coord system as the exting edge layer
-- return a set valid edges that may used be used by topo object later
-- the egdes may be old ones or new ones

CREATE OR REPLACE FUNCTION topo_update.create_surface_edge(geo_in geometry) 
RETURNS topogeometry   AS $$DECLARE

-- result 
new_border_data topogeometry;

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this surface layer id will picked up by input parameters
surface_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

-- TODO use as parameter put for testing we just have here for now
border_topo_info topo_update.input_meta_info ;
surface_topo_info topo_update.input_meta_info ;

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;


BEGIN
	
	-- TODO to be moved is justed for testing now
	border_topo_info.topology_name := 'topo_rein_sysdata';
	border_topo_info.layer_schema_name := 'topo_rein';
	border_topo_info.layer_table_name := 'arstidsbeite_var_grense';
	border_topo_info.layer_feature_column := 'grense';
	border_topo_info.snap_tolerance := 0.0000000001;
	border_topo_info.element_type = 2;
	
	
	surface_topo_info.topology_name := 'topo_rein_sysdata';
	surface_topo_info.layer_schema_name := 'topo_rein';
	surface_topo_info.layer_table_name := 'arstidsbeite_var_flate';
	surface_topo_info.layer_feature_column := 'omrade';
	surface_topo_info.snap_tolerance := 0.0000000001;
	
	-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);
	
	-- find surface layer id
	surface_layer_id := topo_update.get_topo_layer_id(surface_topo_info);

	-- Holds of the id of rows inserted, we need this to keep track rows added to the main table
	CREATE TEMP TABLE IF NOT EXISTS ids_added_border_layer ( id integer );

	-- get new topo border data.
	new_border_data := topology.toTopoGeom(geo_in, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance); 

	-- Test if there are any loose ends	
	-- TODO use topo object as input and not a object, since will bee one single topo object,
	-- TOTO add a test if this is a linestring or not
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
			border_layer_id,
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
			border_layer_id,
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

		IF (EXISTS 
			(
			SELECT 1  
			FROM 
			topo_rein_sysdata.relation re1,
			topo_rein_sysdata.relation re2,
			topo_rein_sysdata.edge_data ed1,
			topo_rein_sysdata.edge_data ed2
			WHERE 
		    re1.layer_id =  border_layer_id AND 
		    re1.element_type = 2 AND  -- TODO use variable element_type_edge=2
		    ed1.edge_id = re1.element_id AND
		    ST_touches(ed1.geom,  ST_StartPoint(edge_with_out_loose_ends)) AND
		    --ST_DWithin(ed1.geom,  ST_StartPoint(edge_with_out_loose_ends), border_topo_info.snap_tolerance) AND 

		   	re2.layer_id =  border_layer_id AND 
		    re2.element_type = 2 AND  -- TODO use variable element_type_edge=2
		    ed2.edge_id = re2.element_id AND
		    ST_touches(ed2.geom,  ST_EndPoint(edge_with_out_loose_ends))
		    --ST_DWithin(ed2.geom,  ST_EndPoint(edge_with_out_loose_ends), border_topo_info.snap_tolerance)		    
		    )
		 ) THEN

	 	RAISE NOTICE 'Ok surface cutting line to add ----------------------';

		-- create new topo object with noe loose into temp table.
		new_border_data := topology.toTopoGeom(edge_with_out_loose_ends, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance);
		
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
				border_layer_id,
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


-- apply the list of new surfaces to the exting list
-- return the id's of the rows affected

-- DROP FUNCTION topo_update.update_domain_surface_layer(_new_topo_objects regclass) cascade;


CREATE OR REPLACE FUNCTION topo_update.update_domain_surface_layer(_new_topo_objects regclass) 
RETURNS SETOF topo_update.topogeometry_def AS $$
DECLARE

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this surface layer id will picked up by input parameters
surface_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

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

-- The border topology
new_border_data topogeometry;

-- used for logging
add_debug_tables int = 0;

BEGIN
	
	-- TODO to be moved is justed for testing now
	border_topo_info.topology_name := 'topo_rein_sysdata';
	border_topo_info.layer_schema_name := 'topo_rein';
	border_topo_info.layer_table_name := 'arstidsbeite_var_grense';
	border_topo_info.layer_feature_column := 'grense';
	border_topo_info.snap_tolerance := 0.0000000001;
	border_topo_info.element_type = 2;
	
	
	surface_topo_info.topology_name := 'topo_rein_sysdata';
	surface_topo_info.layer_schema_name := 'topo_rein';
	surface_topo_info.layer_table_name := 'arstidsbeite_var_flate';
	surface_topo_info.layer_feature_column := 'omrade';
	surface_topo_info.snap_tolerance := 0.0000000001;
	
	-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);
	RAISE NOTICE 'border_layer_id   %',  border_layer_id ;
	
	-- find surface layer id
	surface_layer_id := topo_update.get_topo_layer_id(surface_topo_info);
	RAISE NOTICE 'surface_layer_id   %',  surface_layer_id ;

	-- get the data into a new tmp table
	DROP TABLE IF EXISTS new_surface_data; 

	
	EXECUTE format('CREATE TEMP TABLE new_surface_data AS (SELECT * FROM %s)', _new_topo_objects);
	ALTER TABLE new_surface_data ADD COLUMN id_foo SERIAL PRIMARY KEY;
	
	DROP TABLE IF EXISTS old_surface_data; 
	-- find out if any old topo objects overlaps with this new objects using the relation table
	-- by using the surface objects owned by the both the new objects and the exting one
	CREATE TEMP TABLE old_surface_data AS 
	(SELECT 
	re.* 
	FROM 
	topo_rein_sysdata.relation re,
	topo_rein_sysdata.relation re_tmp,
	new_surface_data new_sd
	WHERE 
	re.layer_id = surface_layer_id AND
	re.element_type = 3 AND
	re.element_id = re_tmp.element_id AND
	re_tmp.layer_id = surface_layer_id AND
	re_tmp.element_type = 3 AND
	(new_sd.surface_topo).id = re_tmp.topogeo_id AND
	(new_sd.surface_topo).id != re.topogeo_id);
	
	
	DROP TABLE IF EXISTS old_surface_data_not_in_new; 
	-- find any old objects that are not covered totaly by 
	-- this objets should not be deleted, but the geometry should only decrease in size.
	-- TODO add a test case for this
	CREATE TEMP TABLE old_surface_data_not_in_new AS 
	(SELECT 
	re.* 
	FROM 
	topo_rein_sysdata.relation re,
	old_surface_data re_tmp
	WHERE 
	re.layer_id = surface_layer_id AND
	re.element_type = 3 AND
	re.topogeo_id = re_tmp.topogeo_id AND
	re.element_id NOT IN (SELECT element_id FROM old_surface_data));
	
	
	DROP TABLE IF EXISTS old_rows_be_reused;
	-- IF old_surface_data_not_in_new is empty we know that all areas are coverbed by the new objects
	-- and we can delete/resuse this objects for the new rows
	-- Get a list of old row id's used
	CREATE TEMP TABLE old_rows_be_reused AS 
	-- we can have distinct here 
	(SELECT distinct(old_data_row.id) FROM 
	topo_rein.arstidsbeite_var_flate old_data_row,
	old_surface_data sf 
	WHERE (old_data_row.omrade).id = sf.topogeo_id);  
	
	
	-- Take a copy of old attribute values because they will be needed when you add new rows.
	-- The new surfaces should pick up old values from the old row attributtes that overlaps the new rows
	-- We also take copy of the geometry we need that to overlaps when we pick up old values
	-- TODO this should have been solved by using topology relation table, but I do that later 
	DROP TABLE IF EXISTS old_rows_attributes;
	CREATE TEMP TABLE old_rows_attributes AS 
	(SELECT old_data_row.*, old_data_row.omrade::geometry as foo_geo FROM 
	topo_rein.arstidsbeite_var_flate old_data_row,
	old_surface_data sf 
	WHERE (old_data_row.omrade).id = sf.topogeo_id);  

		
	-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- list topo objects to be reused
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.update_domain_surface_layer_t1;
		CREATE TABLE topo_rein.update_domain_surface_layer_t1 AS 
		( SELECT r.id, r.omrade::geometry AS geo, 'reuse topo objcts' || r.omrade::text AS topo
			FROM topo_rein.arstidsbeite_var_flate r, old_rows_be_reused reuse WHERE reuse.id = r.id) ;
	END IF;

	
	-- We now know which rows we can reuse clear out old data rom the realation table
	UPDATE topo_rein.arstidsbeite_var_flate r
	SET omrade = clearTopoGeom(omrade)
	FROM old_rows_be_reused reuse
	WHERE reuse.id = r.id;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number rows to be reused in org table %',  num_rows_affected;

	SELECT (num_rows_affected - (SELECT count(*) FROM new_surface_data)) INTO num_rows_to_delete;

	RAISE NOTICE 'Number rows to be added in org table  %',  count(*) FROM new_surface_data;

	RAISE NOTICE 'Number rows to be deleted in org table  %',  num_rows_to_delete;

	-- When overwrite we may have more rows in the org table so we may need do delete the rows not needed 
	-- from  topo_rein.arstidsbeite_var_flate, we the just delete the left overs 
	DELETE FROM topo_rein.arstidsbeite_var_flate
	WHERE ctid IN (
	SELECT r.ctid FROM
	topo_rein.arstidsbeite_var_flate r,
	old_rows_be_reused reuse
	WHERE reuse.id = r.id 
	LIMIT  greatest(num_rows_to_delete, 0));
	

	
	-- Also rows that could be reused, since I was not able to update those.
	DROP TABLE IF EXISTS new_rows_updated_in_org_table;
	CREATE TEMP TABLE new_rows_updated_in_org_table AS (SELECT * FROM topo_rein.arstidsbeite_var_flate limit 0);
	WITH updated AS (
		DELETE FROM topo_rein.arstidsbeite_var_flate old
		USING old_rows_be_reused reuse
		WHERE old.id = reuse.id
		returning *
	)
	INSERT INTO new_rows_updated_in_org_table(omrade)
	SELECT omrade FROM updated;
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number old rows to deleted table %',  num_rows_affected;


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
	CREATE TEMP TABLE new_rows_added_in_org_table AS (SELECT * FROM topo_rein.arstidsbeite_var_flate limit 0);
	WITH inserted AS (
	INSERT INTO  topo_rein.arstidsbeite_var_flate(omrade,felles_egenskaper)
	SELECT new.surface_topo, new.felles_egenskaper_flate as felles_egenskaper
	FROM new_surface_data new
	WHERE NOT EXISTS ( SELECT f.id FROM topo_rein.arstidsbeite_var_flate f WHERE (new.surface_topo).id = (f.omrade).id )
	returning *
	)
	INSERT INTO new_rows_added_in_org_table(id,omrade)
	SELECT inserted.id, omrade FROM inserted;

		-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- list new objects added reused
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.update_domain_surface_layer_t3;
		CREATE TABLE topo_rein.update_domain_surface_layer_t3 AS 
		( SELECT r.id, r.omrade::geometry AS geo, 'new topo objcts' || r.omrade::text AS topo
			FROM new_rows_added_in_org_table r) ;
	END IF;


	-- update the newly inserted rows with attribute values based from old_rows_table
	UPDATE topo_rein.arstidsbeite_var_flate a
	SET 
	reinbeitebruker_id  = c.reinbeitebruker_id, 
	reindrift_sesongomrade_kode = c.reindrift_sesongomrade_kode,
	felles_egenskaper = c.felles_egenskaper
	FROM new_rows_added_in_org_table b, 
	old_rows_attributes c
	WHERE 
    a.id = b.id AND                           
    ST_Intersects(c.foo_geo,ST_pointOnSurface(a.omrade::geometry));
    -- ST_overlaps does not work

   	-- update the newly inserted rows with attribute values based from old_rows_table

    -- find the rows toubching
  	DROP TABLE IF EXISTS touching_surface;
	CREATE TEMP TABLE touching_surface AS (SELECT topo_update.touches('topo_rein.arstidsbeite_var_flate',a.id) as id FROM new_rows_added_in_org_table a);

	UPDATE topo_rein.arstidsbeite_var_flate a
	SET reinbeitebruker_id  = d.reinbeitebruker_id, 
	reindrift_sesongomrade_kode = d.reindrift_sesongomrade_kode,
	felles_egenskaper = d.felles_egenskaper
	FROM 
	topo_rein.arstidsbeite_var_flate d,
	touching_surface b
	WHERE 
	a.reinbeitebruker_id is null AND
	d.id = b.id ;
    
	
	RETURN QUERY SELECT a.surface_topo::topogeometry as t FROM new_surface_data a;

	
END;
$$ LANGUAGE plpgsql;





-- update attribute values for given topo object
CREATE OR REPLACE FUNCTION topo_update.apply_attr_on_topo_line(json_feature text) 
RETURNS int AS $$DECLARE

num_rows int;


-- this line layer id will picked up by input parameters
line_layer_id int;


-- TODO use as parameter put for testing we just have here for now
line_topo_info topo_update.input_meta_info ;

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- holds the num rows affected when needed
num_rows_affected int;

-- used to hold values
felles_egenskaper_flate topo_rein.sosi_felles_egenskaper;
simple_sosi_felles_egenskaper_linje topo_rein.simple_sosi_felles_egenskaper;

BEGIN
	
	-- TODO to be moved is justed for testing now
	line_topo_info.topology_name := 'topo_rein_sysdata';
	line_topo_info.layer_schema_name := 'topo_rein';
	line_topo_info.layer_table_name := 'reindrift_anlegg_linje';
	line_topo_info.layer_feature_column := 'linje';
	line_topo_info.snap_tolerance := 0.0000000001;
	line_topo_info.element_type = 2;
	-- find line layer id
	line_layer_id := topo_update.get_topo_layer_id(line_topo_info);
	
	DROP TABLE IF EXISTS ttt_new_attributes_values;

	CREATE TEMP TABLE ttt_new_attributes_values(geom geometry,properties json);
	
	-- get json data
	INSERT INTO ttt_new_attributes_values(properties)
	SELECT 
--		topo_rein.get_geom_from_json(feat,4258) as geom,
		to_json(feat->'properties')::json  as properties
	FROM (
	  	SELECT json_feature::json AS feat
	) AS f;

	--  
	
	IF (SELECT count(*) FROM ttt_new_attributes_values) != 1 THEN
		RAISE EXCEPTION 'Not valid json_feature %', json_feature;
	ELSE 

		-- TODO find another way to handle this
		SELECT * INTO simple_sosi_felles_egenskaper_linje 
		FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
		(select properties from ttt_new_attributes_values) );

	END IF;

	
	-- We now know which rows we can reuse clear out old data rom the realation table
	UPDATE topo_rein.reindrift_anlegg_linje r
	SET 
		reindriftsanleggstype = (t2.properties->>'reindriftsanleggstype')::int,
		reinbeitebruker_id = (t2.properties->>'reinbeitebruker_id')::text,
		felles_egenskaper = topo_rein.get_rein_felles_egenskaper_update(felles_egenskaper, simple_sosi_felles_egenskaper_linje)
	FROM ttt_new_attributes_values t2
	-- WHERE ST_Intersects(r.omrade::geometry,t2.geom);
	WHERE id = (t2.properties->>'id')::int;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Number num_rows_affected  %',  num_rows_affected;
	

	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;





-- update attribute values for given topo object
CREATE OR REPLACE FUNCTION topo_update.apply_attr_on_topo_point(json_feature text) 
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

-- used to hold values
felles_egenskaper_flate topo_rein.sosi_felles_egenskaper;
simple_sosi_felles_egenskaper_linje topo_rein.simple_sosi_felles_egenskaper;

geo_point geometry;



BEGIN
	
	-- TODO to be moved is justed for testing now
	point_topo_info.topology_name := 'topo_rein_sysdata';
	point_topo_info.layer_schema_name := 'topo_rein';
	point_topo_info.layer_table_name := 'reindrift_anlegg_punkt';
	point_topo_info.layer_feature_column := 'punkt';
	point_topo_info.snap_tolerance := 0.0000000001;
	point_topo_info.element_type = 1;
	-- find point layer id
	point_layer_id := topo_update.get_topo_layer_id(point_topo_info);
	
	DROP TABLE IF EXISTS ttt_new_attributes_values;

	CREATE TEMP TABLE ttt_new_attributes_values(geom geometry,properties json);
	
	-- get json data
	INSERT INTO ttt_new_attributes_values(geom,properties)
	SELECT 
		topo_rein.get_geom_from_json(feat,4258) as geom,
		to_json(feat->'properties')::json  as properties
	FROM (
	  	SELECT json_feature::json AS feat
	) AS f;

			-- check that it is only one row put that value into 
	-- TODO rewrite this to not use table in
	
	IF (SELECT count(*) FROM ttt_new_attributes_values) != 1 THEN
		RAISE EXCEPTION 'Not valid json_feature %', json_feature;
	ELSE 

		SELECT geom FROM ttt_new_attributes_values INTO geo_point;
		
		-- TODO find another way to handle this
		SELECT * INTO simple_sosi_felles_egenskaper_linje 
		FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
		(select properties from ttt_new_attributes_values) );

	END IF;

	--  
	
	-- We now know which rows we can reuse clear out old data rom the realation table
	UPDATE topo_rein.reindrift_anlegg_punkt r
	SET 
		reindriftsanleggstype = (t2.properties->>'reindriftsanleggstype')::int,
		reinbeitebruker_id = (t2.properties->>'reinbeitebruker_id')::text,
		felles_egenskaper = topo_rein.get_rein_felles_egenskaper_update(felles_egenskaper, simple_sosi_felles_egenskaper_linje)
	FROM ttt_new_attributes_values t2
	WHERE id = (t2.properties->>'id')::int;
	

	-- if move point
	IF geo_point is not NULL THEN
		PERFORM topology.clearTopoGeom(punkt) 
		FROM topo_rein.reindrift_anlegg_punkt r, 
		ttt_new_attributes_values t2
		WHERE id = (t2.properties->>'id')::int;

		UPDATE topo_rein.reindrift_anlegg_punkt r
		SET 
			punkt = topology.toTopoGeom(geo_point, point_topo_info.topology_name, point_layer_id, point_topo_info.snap_tolerance)
		FROM ttt_new_attributes_values t2
		WHERE id = (t2.properties->>'id')::int;
	
	END IF;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Number num_rows_affected  %',  num_rows_affected;
	

	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;







-- update attribute values for given topo object
CREATE OR REPLACE FUNCTION topo_update.apply_attr_on_topo_surface(json_feature text) 
RETURNS int AS $$DECLARE

num_rows int;


-- this border layer id will picked up by input parameters
border_layer_id int;

-- this surface layer id will picked up by input parameters
surface_layer_id int;

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

-- used to hold values
felles_egenskaper_flate topo_rein.sosi_felles_egenskaper;
simple_sosi_felles_egenskaper_linje topo_rein.simple_sosi_felles_egenskaper;


BEGIN
	
	-- TODO to be moved is justed for testing now
	border_topo_info.topology_name := 'topo_rein_sysdata';
	border_topo_info.layer_schema_name := 'topo_rein';
	border_topo_info.layer_table_name := 'arstidsbeite_var_grense';
	border_topo_info.layer_feature_column := 'grense';
	border_topo_info.snap_tolerance := 0.0000000001;
	border_topo_info.element_type = 2;
	
	
	surface_topo_info.topology_name := 'topo_rein_sysdata';
	surface_topo_info.layer_schema_name := 'topo_rein';
	surface_topo_info.layer_table_name := 'arstidsbeite_var_flate';
	surface_topo_info.layer_feature_column := 'omrade';
	surface_topo_info.snap_tolerance := 0.0000000001;
	
	-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);
	
	-- find surface layer id
	surface_layer_id := topo_update.get_topo_layer_id(surface_topo_info);

	DROP TABLE IF EXISTS ttt_new_attributes_values;

	CREATE TEMP TABLE ttt_new_attributes_values(geom geometry,properties json);
	
	-- get json data
	INSERT INTO ttt_new_attributes_values(properties)
	SELECT 
		to_json(feat->'properties')::json  as properties
	FROM (
	  	SELECT json_feature::json AS feat
	) AS f;

	--  
	IF (SELECT count(*) FROM ttt_new_attributes_values) != 1 THEN
		RAISE EXCEPTION 'Not valid json_feature %', json_feature;
	ELSE 

		-- TODO find another way to handle this
		SELECT * INTO simple_sosi_felles_egenskaper_linje 
		FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
		(select properties from ttt_new_attributes_values) );

		felles_egenskaper_flate := topo_rein.get_rein_felles_egenskaper_flate(simple_sosi_felles_egenskaper_linje);


	END IF;
	
	-- We now know which rows we can reuse clear out old data rom the realation table
	UPDATE topo_rein.arstidsbeite_var_flate r
	SET 
		reindrift_sesongomrade_kode = (t2.properties->>'reindrift_sesongomrade_kode')::int,
		reinbeitebruker_id = (t2.properties->>'reinbeitebruker_id')::text,
		felles_egenskaper = topo_rein.get_rein_felles_egenskaper_update(felles_egenskaper, simple_sosi_felles_egenskaper_linje)
	FROM ttt_new_attributes_values t2
	WHERE id = (t2.properties->>'id')::int;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Number num_rows_affected  %',  num_rows_affected;
	

	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;


--UPDATE topo_rein.arstidsbeite_var_flate r
--SET reindrift_sesongomrade_kode = null;

-- select * from topo_update.apply_attr_on_topo_surface('{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[-39993,6527853],[-39980,6527867],[-39955,6527864],[-39973,6527837],[-40005,6527840],[-39993,6527853]]],"crs":{"type":"name","properties":{"name":"EPSG:32632"}}},"properties":{"reinbeitebruker_id":null,"reindrift_sesongomrade_kode":2}}');

--select * from topo_update.apply_attr_on_topo_surface('{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[-40034,6527765],[-39904,6527747],[-39938,6527591],[-40046,6527603],[-40034,6527765]]]},"properties":{"reinbeitebruker_id":null,"reindrift_sesongomrade_kode":null}}');


-- SELECT * FROM topo_rein.arstidsbeite_var_flate;


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


--DO $$
--DECLARE 
--command_string text;
--BEGIN
--	command_string := topo_update.create_temp_tbl_def('ttt2_new_attributes_values','(geom geometry,properties json)');
--	RAISE NOTICE 'command_string %',  command_string;
--	EXECUTE command_string;
--END $$;

-- This a function that will be called from the client when user is drawing a line
-- This line will be applied the data in the line layer

-- The result is a set of id's of the new line objects created

-- TODO set attributtes for the line


-- {
CREATE OR REPLACE FUNCTION
topo_update.create_line_edge_domain_obj(json_feature text,
  layer_schema text, layer_table text, layer_column text,
  snap_tolerance float8)
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
simple_sosi_felles_egenskaper_linje topo_rein.simple_sosi_felles_egenskaper;

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the target table
not_null_fields text[];

BEGIN
	
	
	-- Read parameters
	border_topo_info.layer_schema_name := layer_schema;
	border_topo_info.layer_table_name := layer_table;
	border_topo_info.layer_feature_column := layer_column;
	border_topo_info.snap_tolerance := snap_tolerance;

	-- Find out topology name and element_type from layer identifier
  BEGIN
    SELECT t.name, l.feature_type
    FROM topology.topology t, topology.layer l
    WHERE l.level = 0 -- need be primitive
      AND l.schema_name = border_topo_info.layer_schema_name
      AND l.table_name = border_topo_info.layer_table_name
      AND l.feature_column = border_topo_info.layer_feature_column
      AND t.id = l.topology_id
    INTO STRICT border_topo_info.topology_name,
                border_topo_info.element_type;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE EXCEPTION 'Cannot find info for primitive layer %.%.%',
        border_topo_info.layer_schema_name,
        border_topo_info.layer_table_name,
        border_topo_info.layer_feature_column;
  END;

		-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);

	
	RAISE NOTICE 'The JSON input %',  json_feature;

	RAISE NOTICE 'border_layer_id %', border_layer_id;


	-- get the json values
	command_string := topo_update.create_temp_tbl_def('ttt2_new_attributes_values','(geom geometry,properties json)');
	RAISE NOTICE 'command_string %', command_string;

	EXECUTE command_string;

	-- TRUNCATE TABLE ttt2_new_attributes_values;
	INSERT INTO ttt2_new_attributes_values(geom,properties)
	SELECT 
		topo_rein.get_geom_from_json(feat,4258) as geom,
		to_json(feat->'properties')  as properties
	FROM (
	  	SELECT json_feature::json AS feat
	) AS f;

		-- check that it is only one row put that value into 
	-- TODO rewrite this to not use table in
	
	RAISE NOTICE 'Step::::::::::::::::: 1';

	IF (SELECT count(*) FROM ttt2_new_attributes_values) != 1 THEN
		RAISE EXCEPTION 'Not valid json_feature %', json_feature;
	END IF;

	-- TODO find another way to handle this
	SELECT * INTO simple_sosi_felles_egenskaper_linje
	FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
	(select properties from ttt2_new_attributes_values) );

	felles_egenskaper_linje := topo_rein.get_rein_felles_egenskaper(simple_sosi_felles_egenskaper_linje);

	SELECT geom INTO input_geo FROM ttt2_new_attributes_values;
	

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
		FROM ttt2_new_attributes_values t2,
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
	ttt2_new_attributes_values a2,
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
	
	--	IF (SELECT ST_AsText(ST_StartPoint(geom)) FROM ttt2_new_attributes_values)::text = 'POINT(5.69699 58.55152)' THEN
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
		command_string := topo_update.create_temp_tbl_def('ttt2_final_edge_list_for_intersect_line','(id int, edge_id int, geom geometry)');
		EXECUTE command_string;
		-- TRUNCATE TABLE ttt2_final_edge_list_for_intersect_line;
    command_string := '
		INSERT INTO ttt2_final_edge_list_for_intersect_line
		SELECT distinct ud.id, ed.edge_id, ed.geom AS geom
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

    command_string := format('
		WITH inserted AS (
			INSERT INTO %I.%I('
      || quote_ident(border_topo_info.layer_feature_column) || ','
      || array_to_string(array_remove(not_null_fields, border_topo_info.layer_feature_column::text),',')
      || ') SELECT topology.toTopoGeom(b.geom, %L, %L, %L), '
      || array_to_string(array_remove(not_null_fields, border_topo_info.layer_feature_column::text),',')
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

-- This a function that will be called from the client when user is drawing a point 
-- This line will be applied the data in the point layer

-- The result is a set of id's of the new line objects created

-- TODO set attributtes for the line


-- DROP FUNCTION FUNCTION topo_update.create_point_point_domain_obj(geo_in geometry) cascade;


CREATE OR REPLACE FUNCTION topo_update.create_point_point_domain_obj(json_feature text) 
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

-- holds the value for felles egenskaper from input
felles_egenskaper_linje topo_rein.sosi_felles_egenskaper;
simple_sosi_felles_egenskaper_linje topo_rein.simple_sosi_felles_egenskaper;

BEGIN
	
	
	-- TODO to be moved is justed for testing now
	point_topo_info.topology_name := 'topo_rein_sysdata';
	point_topo_info.layer_schema_name := 'topo_rein';
	point_topo_info.layer_table_name := 'reindrift_anlegg_punkt';
	point_topo_info.layer_feature_column := 'punkt';
	point_topo_info.snap_tolerance := 0.0000000001;
	point_topo_info.element_type = 1;
	
		-- find point layer id
	point_layer_id := topo_update.get_topo_layer_id(point_topo_info);

	DROP TABLE IF EXISTS ttt_new_attributes_values;

	CREATE TEMP TABLE ttt_new_attributes_values(geom geometry,properties json);
	
	-- get json data
	INSERT INTO ttt_new_attributes_values(geom,properties)
	SELECT 
		topo_rein.get_geom_from_json(feat,4258) as geom,
		to_json(feat->'properties')::json  as properties
	FROM (
	  	SELECT json_feature::json AS feat
	) AS f;

		-- check that it is only one row put that value into 
	-- TODO rewrite this to not use table in
	
	IF (SELECT count(*) FROM ttt_new_attributes_values) != 1 THEN
		RAISE EXCEPTION 'Not valid json_feature %', json_feature;
	ELSE 
		-- TODO find another way to handle this
		SELECT * INTO simple_sosi_felles_egenskaper_linje 
		FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
		(select properties from ttt_new_attributes_values) );

		felles_egenskaper_linje := topo_rein.get_rein_felles_egenskaper(simple_sosi_felles_egenskaper_linje);
	END IF;

	-- insert the data in the org table and keep a copy of the data
	DROP TABLE IF EXISTS new_rows_added_in_org_table;
	CREATE TEMP TABLE new_rows_added_in_org_table AS (SELECT * FROM  topo_rein.reindrift_anlegg_punkt limit 0);
	WITH inserted AS (
		INSERT INTO topo_rein.reindrift_anlegg_punkt(punkt, felles_egenskaper, reindriftsanleggstype,reinbeitebruker_id)
		SELECT  
			topology.toTopoGeom(t2.geom, point_topo_info.topology_name, point_layer_id, point_topo_info.snap_tolerance) AS punkt,
			felles_egenskaper_linje AS felles_egenskaper,
			(t2.properties->>'reindriftsanleggstype')::int AS reindriftsanleggstype,
			(t2.properties->>'reinbeitebruker_id')::text AS reinbeitebruker_id
		FROM ttt_new_attributes_values t2
		RETURNING *
	)
	INSERT INTO new_rows_added_in_org_table
	SELECT * FROM inserted;

	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number num_rows_affected  %',  num_rows_affected;
	
	-- TODO should we also return lines that are close to or intersects and split them so it's possible to ??? 
	command_string := ' SELECT tg.id AS id FROM  new_rows_added_in_org_table tg';
	-- command_string := 'SELECT tg.id AS id FROM ' || border_topo_info.layer_schema_name || '.' || border_topo_info.layer_table_name || ' tg, new_rows_added_in_org_table new WHERE new.punkt::geometry && tg.punkt::geometry';
	RAISE NOTICE '%', command_string;
    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;

--select topo_update.create_point_point_domain_obj('{"type": "Feature","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"geometry":{"type":"Point","coordinates":[17.4122416312598,68.6013397740665]},"properties":{"reinbeitebruker_id":"XG","reindriftsanleggstype":18}}');

-- This a function that will be called from the client when user is drawing a line
-- This line will be applied the data in the line layer first
-- After that will find the new surfaces created. 
-- new surfaces that was part old serface should inherit old values

-- The result is a set of id's of the new surface objects created

-- TODO set attributtes for the line
-- TODO set attributtes for the surface


-- DROP FUNCTION IF EXISTS topo_update.create_surface_edge_domain_obj(json_feature text) cascade;


CREATE OR REPLACE FUNCTION topo_update.create_surface_edge_domain_obj(json_feature text) 
RETURNS TABLE(result text) AS $$
DECLARE

json_result text;

new_border_data topogeometry;

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this surface layer id will picked up by input parameters
surface_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

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

-- holds the value for felles egenskaper from input
felles_egenskaper_linje topo_rein.sosi_felles_egenskaper;
felles_egenskaper_flate topo_rein.sosi_felles_egenskaper;
simple_sosi_felles_egenskaper_linje topo_rein.simple_sosi_felles_egenskaper;


BEGIN
	
	
	-- TODO to be moved is justed for testing now
	border_topo_info.topology_name := 'topo_rein_sysdata';
	border_topo_info.layer_schema_name := 'topo_rein';
	border_topo_info.layer_table_name := 'arstidsbeite_var_grense';
	border_topo_info.layer_feature_column := 'grense';
	border_topo_info.snap_tolerance := 0.0000000001;
	border_topo_info.element_type = 2;
	
	
	surface_topo_info.topology_name := 'topo_rein_sysdata';
	surface_topo_info.layer_schema_name := 'topo_rein';
	surface_topo_info.layer_table_name := 'arstidsbeite_var_flate';
	surface_topo_info.layer_feature_column := 'omrade';
	surface_topo_info.snap_tolerance := 0.0000000001;

	
	CREATE TEMP TABLE IF NOT EXISTS ttt_new_attributes_values(geom geometry,properties json, felles_egenskaper topo_rein.sosi_felles_egenskaper);
	TRUNCATE TABLE ttt_new_attributes_values;
	
	-- parse the json data
	INSERT INTO ttt_new_attributes_values(geom,properties)
	SELECT 
	geom,
	properties
	FROM (
		SELECT 
			topo_rein.get_geom_from_json(feat,4258) AS geom,
			to_json(feat->'properties')::json  AS properties
		FROM (
		  	SELECT json_feature::json AS feat
		) AS f
	) AS e;

	-- check that it is only one row put that value into 
	-- TODO rewrite this to not use table in
	
	IF (SELECT count(*) FROM ttt_new_attributes_values) != 1 THEN
		RAISE EXCEPTION 'Not valid json_feature %', json_feature;
	ELSE 
		SELECT geom FROM ttt_new_attributes_values INTO geo_in;

		-- TODO find another way to handle this
		SELECT * INTO simple_sosi_felles_egenskaper_linje 
		FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
		(select properties from ttt_new_attributes_values) );

		felles_egenskaper_linje := topo_rein.get_rein_felles_egenskaper(simple_sosi_felles_egenskaper_linje);
		felles_egenskaper_flate := topo_rein.get_rein_felles_egenskaper_flate(simple_sosi_felles_egenskaper_linje);


	END IF;


	org_geo_in := geo_in;
	

	
	RAISE NOTICE 'The input as it used before check/fixed %',  ST_AsText(geo_in);

		-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.create_surface_edge_domain_obj_t0; 
		CREATE TABLE topo_rein.create_surface_edge_domain_obj_t0(geo_in geometry, IsSimple boolean, IsClosed boolean);
		INSERT INTO topo_rein.create_surface_edge_domain_obj_t0(geo_in,IsSimple,IsClosed) VALUES(geo_in,St_IsSimple(geo_in),St_IsSimple(geo_in));
	END IF;
	
	IF NOT ST_IsSimple(geo_in) THEN
		-- This is probably a crossing line so we try to build a surface
		BEGIN
			line_intersection_result := ST_BuildArea(ST_UnaryUnion(geo_in))::geometry;
			RAISE NOTICE 'Line intersection result is %', ST_AsText(line_intersection_result);
			geo_in := ST_ExteriorRing(line_intersection_result);
		EXCEPTION WHEN others THEN
		 	RAISE NOTICE 'Error code: %', SQLSTATE;
      		RAISE NOTICE 'Error message: %', SQLERRM;
			RAISE NOTICE 'Failed to to use line intersection result is %, try buffer', ST_AsText(line_intersection_result);
			geo_in := ST_ExteriorRing(ST_Buffer(line_intersection_result,0.00000000001));
		END;
		
		-- check the object after a fix
		RAISE NOTICE 'Fixed a non simple line to be valid simple line by using by buildArea %',  geo_in;
	ELSIF NOT ST_IsClosed(geo_in) THEN
		-- If this is not closed just check that it intersects two times with a exting border
		-- TODO make more precice check that only used edges that in varbeite surface
		-- TODO handle return of gemoerty collection
		-- thic code fails need to make a test on this 
		-- num_edge_intersects :=  (SELECT ST_NumGeometries(ST_Intersection(geo_in,e.geom)) FROM topo_rein_sysdata.edge_data e WHERE ST_Intersects(geo_in,e.geom))::int;
		line_intersection_result := (select ST_Union(ST_Intersection(geo_in,e.geom)) FROM topo_rein_sysdata.edge_data e WHERE ST_Intersects(geo_in,e.geom))::geometry;

		RAISE NOTICE 'Line intersection result is %', ST_AsText(line_intersection_result);

		num_edge_intersects :=  (SELECT ST_NumGeometries(line_intersection_result))::int;
		
		RAISE NOTICE 'Found a non closed linestring does intersect % times, with any borders by using buildArea %', num_edge_intersects, geo_in;
		IF num_edge_intersects is null OR num_edge_intersects < 2 THEN
			geo_in := ST_ExteriorRing(ST_BuildArea(ST_UnaryUnion(ST_AddPoint(geo_in, ST_StartPoint(geo_in)))));
		ELSEIF num_edge_intersects > 2 THEN
			RAISE EXCEPTION 'Found a non valid linestring does intersect % times, with any borders by using buildArea %', num_edge_intersects, geo_in;
		END IF;
	END IF;

	IF add_debug_tables = 1 THEN
		INSERT INTO topo_rein.create_surface_edge_domain_obj_t0(geo_in,IsSimple,IsClosed) VALUES(geo_in,St_IsSimple(geo_in),St_IsSimple(geo_in));
	END IF;

	RAISE NOTICE 'The input as it used after check/fixed %',  ST_AsText(geo_in);
	
	IF geo_in IS NULL THEN
		RAISE EXCEPTION 'The geo generated from geo_in is null %', org_geo_in;
	END IF;
	

	-- create the new topo object for the egde layer
	new_border_data := topo_update.create_surface_edge(geo_in);
	RAISE NOTICE 'The new topo object created for based on the input geo  %',  new_border_data;

	
	-- perpare result 
	DROP TABLE IF EXISTS create_surface_edge_domain_obj_r1_r; 
	CREATE TEMP TABLE create_surface_edge_domain_obj_r1_r(id int, id_type text) ;
	
	-- TODO insert some correct value for attributes
	WITH inserted AS (
		INSERT INTO topo_rein.arstidsbeite_var_grense(grense, felles_egenskaper)
		SELECT new_border_data, felles_egenskaper_linje
		RETURNING *

	)
	INSERT INTO create_surface_edge_domain_obj_r1_r(id,id_type)
	SELECT id, 'L' as id_type FROM inserted;

	
	

	
	-- create the new topo object for the surfaces
	DROP TABLE IF EXISTS new_surface_data_for_edge; 
	-- find out if any old topo objects overlaps with this new objects using the relation table
	-- by using the surface objects owned by the both the new objects and the exting one
	CREATE TEMP TABLE new_surface_data_for_edge AS 
	(SELECT topo::topogeometry AS surface_topo, felles_egenskaper_flate FROM topo_update.create_edge_surfaces(new_border_data,geo_in,felles_egenskaper_flate));
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of topo surfaces added to table new_surface_data_for_edge   %',  num_rows_affected;
	
	-- clean up old surface and return a list of the objects
	DROP TABLE IF EXISTS res_from_update_domain_surface_layer; 
	CREATE TEMP TABLE res_from_update_domain_surface_layer AS 
	(SELECT topo::topogeometry AS surface_topo FROM topo_update.update_domain_surface_layer('new_surface_data_for_edge'));
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number_of_rows removed from topo_update.update_domain_surface_layer   %',  num_rows_affected;

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
    	RAISE NOTICE 'A closed objects only return objects in %', command_string;
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
		(al.linje).id = re.topogeo_id AND
		re.layer_id =  %5$L AND 
		re.element_type = %6$L AND  
		ed.edge_id = re.element_id AND
		NOT EXISTS ( SELECT 1 FROM %1$I.relation re2 WHERE  ed.edge_id = re2.element_id AND re2.topogeo_id != re.topogeo_id) 
    )',
    border_topo_info.topology_name,
    border_topo_info.layer_schema_name,
	border_topo_info.layer_table_name,
	id_in,
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

CREATE OR REPLACE FUNCTION topo_update.delete_topo_point(id_in int) 
RETURNS int AS $$DECLARE


-- holds the num rows affected when needed
num_rows_affected int;


BEGIN

	PERFORM topology.clearTopoGeom(punkt) FROM topo_rein.reindrift_anlegg_punkt r
	WHERE id = id_in;


	DELETE FROM topo_rein.reindrift_anlegg_punkt r
	WHERE id = id_in;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Rows deleted  %',  num_rows_affected;
	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;

-- delete surface that intersects with given point

CREATE OR REPLACE FUNCTION topo_update.delete_topo_surface(id_in int) 
RETURNS int AS $$DECLARE

num_rows int;


-- this border layer id will picked up by input parameters
border_layer_id int;

-- this surface layer id will picked up by input parameters
surface_layer_id int;

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
	
	-- TODO to be moved is justed for testing now
	border_topo_info.topology_name := 'topo_rein_sysdata';
	border_topo_info.layer_schema_name := 'topo_rein';
	border_topo_info.layer_table_name := 'arstidsbeite_var_grense';
	border_topo_info.layer_feature_column := 'grense';
	border_topo_info.snap_tolerance := 0.0000000001;
	border_topo_info.element_type = 2;
	
	
	surface_topo_info.topology_name := 'topo_rein_sysdata';
	surface_topo_info.layer_schema_name := 'topo_rein';
	surface_topo_info.layer_table_name := 'arstidsbeite_var_flate';
	surface_topo_info.layer_feature_column := 'omrade';
	surface_topo_info.snap_tolerance := 0.0000000001;
	
	-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);
	
	-- find surface layer id
	surface_layer_id := topo_update.get_topo_layer_id(surface_topo_info);

	SELECT omrade::geometry FROM topo_rein.arstidsbeite_var_flate r WHERE id = id_in INTO delete_surface;
        

    PERFORM topology.clearTopoGeom(omrade) FROM topo_rein.arstidsbeite_var_flate r
    WHERE id = id_in;
    
    DELETE FROM topo_rein.arstidsbeite_var_flate r
    WHERE id = id_in;
    
    
    GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

    RAISE NOTICE 'Rows deleted  %',  num_rows_affected;

    -- Find unused edges 
    DROP TABLE IF EXISTS ttt_unused_edge_ids;
    CREATE TEMP TABLE ttt_unused_edge_ids AS 
    (
		SELECT topo_rein.get_edges_within_faces(array_agg(x),border_layer_id) AS id from  topo_rein.get_unused_faces(surface_layer_id) x
    );
    
    -- Used for debug
    DROP TABLE IF EXISTS ttt_unused_edge_geos;
    CREATE TEMP TABLE ttt_unused_edge_geos AS 
    (
		SELECT ed.geom, ed.edge_id FROM
		topo_rein_sysdata.edge_data ed,
		ttt_unused_edge_ids ued
		WHERE ed.edge_id = ANY(ued.id)
    );


    -- Find linear objects related to his edges 
    DROP TABLE IF EXISTS ttt_affected_border_objects;
    CREATE TEMP TABLE ttt_affected_border_objects AS 
    (
		select distinct ud.id
	    FROM 
		topo_rein_sysdata.relation re,
		topo_rein.arstidsbeite_var_grense ud, 
		topo_rein_sysdata.edge_data ed,
		ttt_unused_edge_ids ued
		WHERE 
		(ud.grense).id = re.topogeo_id AND
		re.layer_id =  border_layer_id AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		ed.edge_id = ANY(ued.id)
    );
    
    -- Create geoms for for linal objects with out edges that will be deleted
    DROP TABLE IF EXISTS ttt_new_border_objects;
    CREATE TEMP TABLE ttt_new_border_objects AS 
    (
		SELECT ud.id, ST_Union(ed.geom) AS geom 
	    FROM 
		topo_rein_sysdata.relation re,
		topo_rein.arstidsbeite_var_grense ud, 
		topo_rein_sysdata.edge_data ed,
		ttt_unused_edge_ids ued,
		ttt_affected_border_objects ab
		WHERE 
		ab.id = ud.id AND
		(ud.grense).id = re.topogeo_id AND
		re.layer_id =  border_layer_id AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		NOT (ed.edge_id = ANY(ued.id))
		GROUP BY ud.id
    );
	
    -- Delete border topo objects
    PERFORM topology.clearTopoGeom(a.grense) 
    FROM topo_rein.arstidsbeite_var_grense a,
    ttt_affected_border_objects b
	WHERE a.id = b.id;
	
	
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
	DELETE FROM topo_rein.arstidsbeite_var_grense a
	USING ttt_new_border_objects b
	WHERE a.id = b.id AND b.geom IS NULL;
	

    -- update new topo objects topo values
	UPDATE topo_rein.arstidsbeite_var_grense AS a
	SET grense =  topology.toTopoGeom(b.geom, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance)
	FROM ttt_new_border_objects b
	WHERE a.id = b.id AND b.geom IS NOT NULL;
	
	
    RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;


--UPDATE topo_rein.arstidsbeite_var_flate r
--SET reindrift_sesongomrade_kode = null;

-- select * from topo_update.delete_topo_surface('{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[-39993,6527853],[-39980,6527867],[-39955,6527864],[-39973,6527837],[-40005,6527840],[-39993,6527853]]],"crs":{"type":"name","properties":{"name":"EPSG:32632"}}},"properties":{"reinbeitebruker_id":null,"reindrift_sesongomrade_kode":2}}');

--select * from topo_update.delete_topo_surface('{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[-40034,6527765],[-39904,6527747],[-39938,6527591],[-40046,6527603],[-40034,6527765]]]},"properties":{"reinbeitebruker_id":null,"reindrift_sesongomrade_kode":null}}');


-- SELECT * FROM topo_rein.arstidsbeite_var_flate;


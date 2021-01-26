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


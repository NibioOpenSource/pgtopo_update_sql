
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
felles topo_rein.simple_sosi_felles_egenskaper ) 
RETURNS topo_rein.sosi_felles_egenskaper AS $$DECLARE

DECLARE 

BEGIN

	
-- if we have a value for felles_egenskaper.verifiseringsdato or else use current date
res.verifiseringsdato :=  (felles)."fellesegenskaper.verifiseringsdato";
IF res.verifiseringsdato is null THEN
	res.verifiseringsdato :=  current_date;
END IF;

res.oppdateringsdato :=  current_date;

res.opphav :=  (felles)."fellesegenskaper.opphav";


return res;

END;
$$ LANGUAGE plpgsql IMMUTABLE ;








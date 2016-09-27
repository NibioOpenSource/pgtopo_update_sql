
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
res_kvalitet.noyaktighet := (felles)."fellesegenskaper.kvalitet.noyaktighet";
res_kvalitet.synbarhet := (felles)."fellesegenskaper.kvalitet.synbarhet";
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

-- res.identifikasjon := 'NO_LDIR_REINDRIFT_VAARBEITE 0 ' |ß| localid_in;
-- set default to null if not set
res.forstedatafangstdato := now();
	
-- if we have a value for felles_egenskaper.forstedatafangstdato 
IF (felles)."fellesegenskaper.forstedatafangstdato" is NOT null THEN
	res.forstedatafangstdato :=  (felles)."fellesegenskaper.forstedatafangstdato";
END IF;

-- if we have a value for felles_egenskaper.verifiseringsdato is null use forstedatafangstdato
IF (felles)."fellesegenskaper.verifiseringsdato" is null THEN
	res.verifiseringsdato := res.forstedatafangstdato;
ELSE
	res.verifiseringsdato := (felles)."fellesegenskaper.verifiseringsdato";
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
-- res is the old record
-- felles is the new value from server

CREATE OR REPLACE FUNCTION topo_rein.get_rein_felles_egenskaper_update(
curent_value topo_rein.sosi_felles_egenskaper, 
new_value_from_client topo_rein.sosi_felles_egenskaper) 
RETURNS topo_rein.sosi_felles_egenskaper AS $$DECLARE

DECLARE 

BEGIN

	

-- if we don't hava a value for forstedatafangstdato is null use forstedatafangstdato sendt in.
--IF (new_value_from_client)."forstedatafangstdato" is not null THEN
	curent_value.forstedatafangstdato :=  (new_value_from_client)."forstedatafangstdato";
--END IF;

curent_value.verifiseringsdato :=  (new_value_from_client)."verifiseringsdato";

curent_value.oppdateringsdato :=  current_date;

curent_value.opphav :=  (new_value_from_client)."opphav";

curent_value.kvalitet = (new_value_from_client)."kvalitet";


return curent_value;

END;
$$ LANGUAGE plpgsql IMMUTABLE ;








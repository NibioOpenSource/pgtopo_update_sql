-- used to get felles egenskaper for with all values
-- including måle metode

CREATE OR REPLACE FUNCTION topo_rein.get_rein_felles_egenskaper(felles topo_rein.simple_sosi_felles_egenskaper) 
RETURNS topo_rein.sosi_felles_egenskaper AS $$DECLARE
DECLARE 
use_default_dates boolean = true;
BEGIN
return topo_rein.get_rein_felles_egenskaper(felles, use_default_dates ) ;
END;
$$ LANGUAGE plpgsql IMMUTABLE ;


CREATE OR REPLACE FUNCTION topo_rein.get_rein_felles_egenskaper(felles topo_rein.simple_sosi_felles_egenskaper, use_default_dates boolean ) 
RETURNS topo_rein.sosi_felles_egenskaper AS $$DECLARE

DECLARE 

res topo_rein.sosi_felles_egenskaper ;
res_kvalitet topo_rein.sosi_kvalitet;


BEGIN

res := topo_rein.get_rein_felles_egenskaper_flate(felles,use_default_dates);

-- add målemetode
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
use_default_dates boolean = true;
DECLARE 
BEGIN
	return topo_rein.get_rein_felles_egenskaper_flate(felles,use_default_dates);
END;
$$ LANGUAGE plpgsql IMMUTABLE ;


-- used to get felles egenskaper for where we don't use målemetode
CREATE OR REPLACE FUNCTION topo_rein.get_rein_felles_egenskaper_flate(felles topo_rein.simple_sosi_felles_egenskaper,use_default_dates boolean) 
RETURNS topo_rein.sosi_felles_egenskaper AS $$DECLARE

DECLARE 

res topo_rein.sosi_felles_egenskaper;
res_kvalitet topo_rein.sosi_kvalitet;
res_sosi_registreringsversjon topo_rein.sosi_registreringsversjon;


BEGIN

	
res.opphav :=  (felles)."fellesegenskaper.opphav";
res.oppdateringsdato :=  current_date;
	

IF use_default_dates = true THEN	
	RAISE NOTICE '------------------------------------Use default date values ';

	res.forstedatafangstdato := current_date;
	
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

ELSE
	RAISE NOTICE '------------------------------------Do not default date values ';
	IF (felles)."fellesegenskaper.forstedatafangstdato" is NOT null THEN
		res.forstedatafangstdato :=  (felles)."fellesegenskaper.forstedatafangstdato";
    END IF;
    
	IF (felles)."fellesegenskaper.verifiseringsdato" is NOT null THEN
		res.verifiseringsdato := (felles)."fellesegenskaper.verifiseringsdato";
	ELSIF (felles)."fellesegenskaper.forstedatafangstdato" is NOT null THEN
		-- if verifiseringsdato is null use forstedatafangstdato if not null
		res.verifiseringsdato := (felles)."fellesegenskaper.forstedatafangstdato";
    END IF;
END IF;


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
	current_res_kvalitet topo_rein.sosi_kvalitet;
	new_res_kvalitet topo_rein.sosi_kvalitet;

BEGIN

current_res_kvalitet := (curent_value)."kvalitet";
new_res_kvalitet := (new_value_from_client)."kvalitet";
	

-- if vo value fr the client don't use it.
IF (new_value_from_client)."forstedatafangstdato" is not null THEN
	curent_value.forstedatafangstdato :=  (new_value_from_client)."forstedatafangstdato";
END IF;

-- if vo value fr the client don't use it.
IF (new_value_from_client)."verifiseringsdato" is not null THEN
	curent_value.verifiseringsdato :=  (new_value_from_client)."verifiseringsdato";
END IF;

curent_value.oppdateringsdato :=  current_date;


-- if vo value fr the client don't use it.
IF (new_value_from_client)."opphav" is not null THEN
	curent_value.opphav :=  (new_value_from_client)."opphav";
END IF;

-- if vo value fr the client don't use it.
IF (new_res_kvalitet)."maalemetode" is not null THEN
	current_res_kvalitet.maalemetode :=  (new_res_kvalitet)."maalemetode";
END IF;

-- if vo value fr the client don't use it.
IF (new_res_kvalitet)."noyaktighet" is not null THEN
	current_res_kvalitet.noyaktighet :=  (new_res_kvalitet)."noyaktighet";
END IF;

-- if vo value fr the client don't use it.
IF (new_res_kvalitet)."synbarhet" is not null THEN
	current_res_kvalitet.synbarhet :=  (new_res_kvalitet)."synbarhet";
END IF;

curent_value.kvalitet = current_res_kvalitet;

return curent_value;

END;
$$ LANGUAGE plpgsql IMMUTABLE ;








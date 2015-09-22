
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
 

-- then read from korr, the layer thats is updated
SELECT 
topo_update.create_line_edge_domain_obj(f.a) 
--f.a, f.objectid 
FROM (
 	SELECT 
 	'{"type": "Feature",' || 
 	'"geometry":' || ST_AsGeoJSON(ST_setSrid(ST_transform(geo,4258),4258),10,2)::json || ',' ||
 	'"properties":' || row_to_json((SELECT l FROM (SELECT reinbeitebruker_id, reindriftsanleggstype, "felles_egenskaper.forstedatafangsdato", "felles_egenskaper.verifiseringsdato", "felles_egenskaper.oppdateringsdato","felles_egenskaper.opphav","felles_egenskaper.kvalitet.maalemetode") As l )) || '}' as a,
 	ST_setSrid(ST_transform(geo,4258),4258) as geo,
 	objectid
FROM 
	( 
		SELECT 
		objectid,
		beitebrukerid AS reinbeitebruker_id, 
		reindriftanltyp AS reindriftsanleggstype, 
		forstedatafangstdato as "felles_egenskaper.forstedatafangsdato",
		verifiseringsdato as "felles_egenskaper.verifiseringsdato",
		oppdateringsdato as "felles_egenskaper.oppdateringsdato",
		opphav as "felles_egenskaper.opphav",
		82 as "felles_egenskaper.kvalitet.maalemetode",
		geo 
		FROM org_rein_korr.rein_korr_drift_anlegg_linje
		where reindriftanltyp in (4,5,6,7)
		ORDER BY objectid
	) AS lg
) As f;




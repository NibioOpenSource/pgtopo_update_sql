
-- then read from korr, the layer thats is updated
SELECT 
topo_update.create_line_edge_domain_obj(f.a) 
--f.a, f.objectid 
FROM (
 	SELECT 
 	'{"type": "Feature",' || 
 	'"geometry":' || ST_AsGeoJSON(ST_setSrid(ST_transform(geo,4258),4258),10,2)::json || ',' ||
 	'"properties":' || row_to_json((SELECT l FROM (SELECT reinbeitebruker_id, reindriftsanleggstype, "fellesegenskaper.forstedatafangstdato", "fellesegenskaper.verifiseringsdato", "fellesegenskaper.oppdateringsdato","fellesegenskaper.opphav","fellesegenskaper.kvalitet.maalemetode") As l )) || '}' as a,
 	ST_setSrid(ST_transform(geo,4258),4258) as geo,
 	objectid
FROM 
	( 
		SELECT 
		objectid,
		beitebrukerid AS reinbeitebruker_id, 
		reindriftanltyp AS reindriftsanleggstype, 
		forstedatafangstdato as "fellesegenskaper.forstedatafangstdato",
		verifiseringsdato as "fellesegenskaper.verifiseringsdato",
		oppdateringsdato as "fellesegenskaper.oppdateringsdato",
		opphav as "fellesegenskaper.opphav",
		82 as "fellesegenskaper.kvalitet.maalemetode",
		geo 
		FROM org_rein_korr.rein_korr_drift_anlegg_linje
		where reindriftanltyp in (4,5,6,7)
		ORDER BY objectid
	) AS lg
) As f;




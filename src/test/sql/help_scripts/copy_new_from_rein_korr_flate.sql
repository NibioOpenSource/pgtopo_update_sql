------- Handle Årstidsbeiter - Vårbeite
-- from: org_rein_korr.rein_korr_arstidsbeite_var_flate 
-- to: topo_rein.arstidsbeite_var_grense and topo_rein.arstidsbeite_var_flate



-- Add Exterior rings first for prom koor layer -----------------------------
SELECT topo_update.create_surface_edge_domain_obj(f.a) 
--SELECT f.a
FROM (
 	SELECT 
 	'{"type": "Feature",' || 
 	'"geometry":' || ST_AsGeoJSON(geo,10,2)::json || 
 	',"properties":' || row_to_json((SELECT l FROM 
 	(SELECT "felles_egenskaper.forstedatafangsdato", "felles_egenskaper.verifiseringsdato", "felles_egenskaper.oppdateringsdato","felles_egenskaper.opphav","felles_egenskaper.kvalitet.maalemetode") as l
 	)) || 
 	'}' as a
	FROM 
	( 
	SELECT 
			ST_setSrid(ST_transform(ST_ExteriorRing(geo),4258),4258) as geo,
			forstedatafangstdato as "felles_egenskaper.forstedatafangsdato",
			verifiseringsdato as "felles_egenskaper.verifiseringsdato",
			oppdateringsdato as "felles_egenskaper.oppdateringsdato",
			opphav as "felles_egenskaper.opphav",
			82 as "felles_egenskaper.kvalitet.maalemetode"
		FROM org_rein_korr.rein_korr_arstidsbeite_var_flate b 
		WHERE ST_NumInteriorRings(geo) > 0
	) AS e
) AS f;

-- Remove holes
SELECT topo_update.delete_topo_surface(delete_id)
FROM (
	SELECT topo_update.create_surface_edge_domain_obj(f.a) delete_id, geo 
	FROM (
	 	SELECT 
	 	'{"type": "Feature",' || 
	 	'"geometry":' || ST_AsGeoJSON(r.geo,10,2)::json || 
	 	',"properties":' || row_to_json((SELECT l FROM 
	 	(SELECT "felles_egenskaper.forstedatafangsdato", "felles_egenskaper.verifiseringsdato", "felles_egenskaper.oppdateringsdato","felles_egenskaper.opphav","felles_egenskaper.kvalitet.maalemetode") as l
	 	)) || 
	 	'}' as a,
	 	r.geo
	 	
		FROM ( 
			SELECT ST_setSrid(ST_transform(geo,4258),4258) as geo,
			"felles_egenskaper.forstedatafangsdato", "felles_egenskaper.verifiseringsdato", "felles_egenskaper.oppdateringsdato","felles_egenskaper.opphav","felles_egenskaper.kvalitet.maalemetode"
			
			FROM 
			( 
				SELECT ST_InteriorRingN(c.geo,generate_series(1,ST_NumInteriorRings(c.geo))) as geo,
				forstedatafangstdato as "felles_egenskaper.forstedatafangsdato",
				verifiseringsdato as "felles_egenskaper.verifiseringsdato",
				oppdateringsdato as "felles_egenskaper.oppdateringsdato",
				opphav as "felles_egenskaper.opphav",
				82 as "felles_egenskaper.kvalitet.maalemetode"
				FROM org_rein_korr.rein_korr_arstidsbeite_var_flate c
				WHERE ST_NumInteriorRings(c.geo) > 0
			) AS d
		) AS r 
	) AS f
) AS d; 

-- Add surfaces with no holesd
SELECT topo_update.create_surface_edge_domain_obj(f.a) 
--SELECT f.a
FROM (
 	SELECT 
 	'{"type": "Feature",' || 
 	'"geometry":' || ST_AsGeoJSON(geo,10,2)::json || 
 	',"properties":' || row_to_json((SELECT l FROM 
 	(SELECT "felles_egenskaper.forstedatafangsdato", "felles_egenskaper.verifiseringsdato", "felles_egenskaper.oppdateringsdato","felles_egenskaper.opphav","felles_egenskaper.kvalitet.maalemetode") as l
 	)) || 
 	'}' as a
	FROM 
	( 
	SELECT 
			ST_setSrid(ST_transform(ST_ExteriorRing(geo),4258),4258) as geo,
			forstedatafangstdato as "felles_egenskaper.forstedatafangsdato",
			verifiseringsdato as "felles_egenskaper.verifiseringsdato",
			oppdateringsdato as "felles_egenskaper.oppdateringsdato",
			opphav as "felles_egenskaper.opphav",
			82 as "felles_egenskaper.kvalitet.maalemetode"
		FROM org_rein_korr.rein_korr_arstidsbeite_var_flate b 
		WHERE ST_NumInteriorRings(geo) = 0
	) AS e
) AS f;


-- Pick up surface attributtes  and set them by using json
SELECT topo_update.apply_attr_on_topo_surface(f.a) 
--SELECT f.a
FROM (
 	SELECT 
 	'{"type": "Feature",' || 
-- 	'"geometry":' || ST_AsGeoJSON(geo,10,2)::json || ',' ||
 	'"properties":' || row_to_json((SELECT l FROM (SELECT id,reinbeitebruker_id, reindrift_sesongomrade_kode, verifiseringsdato) As l )) || 
 	'}' as a
FROM ( 
	SELECT
	r.id,
	k.beitebrukerid AS reinbeitebruker_id, 
	k.sesomr AS reindrift_sesongomrade_kode, 
	k.verifiseringsdato,
	ST_setSrid(ST_transform(ST_PointOnSurface(k.geo),4258),4258) AS geo 
	FROM 
	org_rein_korr.rein_korr_arstidsbeite_var_flate k , 
	topo_rein.arstidsbeite_var_flate r
	WHERE ST_Intersects(r.omrade::geometry,ST_setSrid(ST_transform(ST_PointOnSurface(k.geo),4258),4258)) 
	) as lg
) as f;

-- delete holes
delete from topo_rein.arstidsbeite_var_flate where reinbeitebruker_id is null;

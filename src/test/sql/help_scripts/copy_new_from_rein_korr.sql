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
 	(SELECT "fellesegenskaper.forstedatafangstdato", "fellesegenskaper.verifiseringsdato", "fellesegenskaper.oppdateringsdato","fellesegenskaper.opphav","fellesegenskaper.kvalitet.maalemetode") as l
 	)) || 
 	'}' as a
	FROM 
	( 
	SELECT 
			ST_setSrid(ST_transform(ST_ExteriorRing(geo),4258),4258) as geo,
			forstedatafangstdato as "fellesegenskaper.forstedatafangstdato",
			verifiseringsdato as "fellesegenskaper.verifiseringsdato",
			oppdateringsdato as "fellesegenskaper.oppdateringsdato",
			opphav as "fellesegenskaper.opphav",
			82 as "fellesegenskaper.kvalitet.maalemetode"
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
	 	(SELECT "fellesegenskaper.forstedatafangstdato", "fellesegenskaper.verifiseringsdato", "fellesegenskaper.oppdateringsdato","fellesegenskaper.opphav","fellesegenskaper.kvalitet.maalemetode") as l
	 	)) || 
	 	'}' as a,
	 	r.geo
	 	
		FROM ( 
			SELECT ST_setSrid(ST_transform(geo,4258),4258) as geo,
			"fellesegenskaper.forstedatafangstdato", "fellesegenskaper.verifiseringsdato", "fellesegenskaper.oppdateringsdato","fellesegenskaper.opphav","fellesegenskaper.kvalitet.maalemetode"
			
			FROM 
			( 
				SELECT ST_InteriorRingN(c.geo,generate_series(1,ST_NumInteriorRings(c.geo))) as geo,
				forstedatafangstdato as "fellesegenskaper.forstedatafangstdato",
				verifiseringsdato as "fellesegenskaper.verifiseringsdato",
				oppdateringsdato as "fellesegenskaper.oppdateringsdato",
				opphav as "fellesegenskaper.opphav",
				82 as "fellesegenskaper.kvalitet.maalemetode"
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
 	(SELECT "fellesegenskaper.forstedatafangstdato", "fellesegenskaper.verifiseringsdato", "fellesegenskaper.oppdateringsdato","fellesegenskaper.opphav","fellesegenskaper.kvalitet.maalemetode") as l
 	)) || 
 	'}' as a
	FROM 
	( 
	SELECT 
			ST_setSrid(ST_transform(ST_ExteriorRing(geo),4258),4258) as geo,
			forstedatafangstdato as "fellesegenskaper.forstedatafangstdato",
			verifiseringsdato as "fellesegenskaper.verifiseringsdato",
			oppdateringsdato as "fellesegenskaper.oppdateringsdato",
			opphav as "fellesegenskaper.opphav",
			82 as "fellesegenskaper.kvalitet.maalemetode"
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

ANALYZE verbose;

-- then read from korr, the layer thats is updated
SELECT 
 topo_update.create_line_edge_domain_obj(f.a) 
 -- SELECT f.a, f.objectid 
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

ANALYZE verbose;


-- then read from korr, the layer thats is updated

SELECT topo_update.create_point_point_domain_obj(f.a) 
FROM (
 	SELECT 
 	'{"type": "Feature",' || 
 	'"geometry":' || ST_AsGeoJSON(ST_setSrid(ST_transform(geo,4258),4258),10,2)::json || ',' ||
 	'"properties":' || row_to_json((SELECT l FROM (SELECT reinbeitebruker_id, reindriftsanleggstype, "fellesegenskaper.forstedatafangstdato", "fellesegenskaper.verifiseringsdato", "fellesegenskaper.oppdateringsdato","fellesegenskaper.opphav","fellesegenskaper.kvalitet.maalemetode") As l )) || '}' as a,
 	ST_setSrid(ST_transform(geo,4258),4258) as geo
FROM 
	( 
		SELECT 
		beitebrukerid AS reinbeitebruker_id, 
		reindriftanltyp AS reindriftsanleggstype, 
		forstedatafangstdato as "fellesegenskaper.forstedatafangstdato",
		verifiseringsdato as "fellesegenskaper.verifiseringsdato",
		oppdateringsdato as "fellesegenskaper.oppdateringsdato",
		opphav as "fellesegenskaper.opphav",
		82 as "fellesegenskaper.kvalitet.maalemetode",
		geo 
		FROM org_rein_korr.rein_korr_drift_anlegg_punkt
		WHERE reindriftanltyp in (10,11,12,13,14,15,16,17,18,19) and length(beitebrukerid) < 4
		ORDER BY objectid
	) AS lg
) As f;



select count(*) FROM topo_rein.ttt_new_attributes_values;
select count(*) FROM topo_rein.ttt_new_topo_rows_in_org_table;
select count(*) FROM topo_rein.ttt_covered_by_input_line;
select count(*) FROM topo_rein.ttt_not_covered_by_input_line;
select count(*) FROM topo_rein.ttt_affected_objects_id;
select count(*) FROM topo_rein.ttt_objects_to_be_delted;
select count(*) FROM topo_rein.ttt_objects_to_be_updated;
select count(*) FROM topo_rein.ttt_intersection_id;
select count(*) FROM topo_rein.ttt_id_return_list;
select count(*) FROM topo_rein.ttt_short_edge_list;
select count(*) FROM topo_rein.ttt_short_object_list;
select count(*) FROM topo_rein.ttt_final_edge_list_for_input_line;
select count(*) FROM topo_rein.ttt_final_edge_list_for_intersect_line;
select count(*) FROM topo_rein.ttt_final_edge_left_list_intersect_line;
select count(*) FROM topo_rein.ttt_new_intersected_split_objects;
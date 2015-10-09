-- Add surface with no attributtes
SELECT topo_update.create_surface_edge_domain_obj(ST_setSrid(ST_transform(geo,4258),4258))  FROM 
( 
SELECT ST_ExteriorRing(b.geo) AS geo 
FROM org_rein_korr.rein_korr_arstidsbeite_var_flate b
UNION
SELECT ST_InteriorRingN(c.geo,generate_series(1,ST_NumInteriorRings(c.geo))) as geo
FROM org_rein_korr.rein_korr_arstidsbeite_var_flate c
) as r;

-- Pick up surface attributtes  and set them by using json
SELECT topo_update.apply_attr_on_topo_surface(f.a) 
 FROM (
 	SELECT 
 	'{"type": "Feature",' || 
 	'"geometry":' || ST_AsGeoJSON(ST_setSrid(ST_transform(ST_PointOnSurface(geo),4258),4258))::json || ',' ||
-- 	'"geometry":' || ST_AsGeoJSON(ST_setSrid(ST_transform(ST_PointOnSurface(ST_transform(geo,4258)),32633),32633))::json || ',' ||
-- 	'"geometry":' || ST_AsGeoJSON(ST_setSrid(ST_PointOnSurface(geo),32633))::json || ',' ||  
 	'"properties":' || row_to_json((SELECT l FROM (SELECT reinbeitebruker_id, reindrift_sesongomrade_kode) As l )) || '}' as a
FROM 
( SELECT beitebrukerid AS reinbeitebruker_id, sesomr AS reindrift_sesongomrade_kode, geo FROM org_rein_korr.rein_korr_arstidsbeite_var_flate   ) as lg) As f;




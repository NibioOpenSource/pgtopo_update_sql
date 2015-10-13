-- Add surface with no attributtes
SELECT topo_update.create_surface_edge_domain_obj(ST_setSrid(ST_transform(geo,4258),4258))  FROM 
--SELECT ST_AsText(ST_setSrid(ST_transform(geo,4258),4258))  FROM 
( 
	SELECT ST_ExteriorRing(b.geo) AS geo, objectid, 1 as type_geo 
	FROM org_rein_korr.rein_korr_arstidsbeite_var_flate b
--	WHERE ST_NumInteriorRings(b.geo) > 1
	UNION
	SELECT ST_InteriorRingN(c.geo,generate_series(1,ST_NumInteriorRings(c.geo))) as geo, objectid, 2 as type_geo
	FROM org_rein_korr.rein_korr_arstidsbeite_var_flate c
--	WHERE ST_NumInteriorRings(c.geo) > 1
) as r 
--where objectid = 964;
ORDER BY objectid, type_geo;

-- Pick up surface attributtes  and set them by using json
SELECT topo_update.apply_attr_on_topo_surface(f.a) 
 FROM (
 	SELECT 
 	'{"type": "Feature",' || 
 	'"crs":{"type":"name","properties":{"name":"EPSG:4258"}},' ||
 	'"geometry":' || ST_AsGeoJSON(ST_setSrid(ST_transform(ST_PointOnSurface(geo),4258),4258))::json || ',' ||
-- 	'"geometry":' || ST_AsGeoJSON(ST_setSrid(ST_transform(ST_PointOnSurface(ST_transform(geo,4258)),32633),32633))::json || ',' ||
-- 	'"geometry":' || ST_AsGeoJSON(ST_setSrid(ST_PointOnSurface(geo),32633))::json || ',' ||  
 	'"properties":' || row_to_json((SELECT l FROM (SELECT reinbeitebruker_id, reindrift_sesongomrade_kode) As l )) || '}' as a
FROM 
( 
SELECT beitebrukerid AS reinbeitebruker_id, sesomr AS reindrift_sesongomrade_kode, geo 
FROM org_rein_korr.rein_korr_arstidsbeite_var_flate   
--WHERE ST_NumInteriorRings(geo) > 1
--and objectid = 964
ORDER BY objectid
) 
AS lg
) As f 





--added a closed linestring
select topo_update.create_surface_edge_domain_obj('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.55375, 5.70152 58.55373, 5.70182 58.55131)',32632,0);

-- and I get this
--    ,---E3--.
--    |       |     
--    |       |
--    |       |
--    |       |
--    |       |
--    `-------'


-- added linstring that does not split this polygon in two pieces because it does not through surface
select topo_update.create_surface_edge_domain_obj('SRID=4258;LINESTRING (5.700389 58.553441, 5.703302 58.551901)',32632,0);

--
--    ,---E3--.
--    |       |     
--    |       |
------------  |
--    |       |
--    |       |
--    `-------'
--

-- And we end up with this where I have no loose ends

--
--    ,---E3--.
--    |       |     
--    |       |
--    |       |
--    |       |
--    |       |
--    `---E4--'
--


-- added linstring that splits this polygon in two pices, this line is the same as the line abouve with one extra point
select topo_update.create_surface_edge_domain_obj('SRID=4258;LINESTRING (5.700389 58.553441, 5.703302 58.551901, 5.704804 58.553154)',32632,0);

--
--    ,---E3--.
--    |       |     
--    |       |
--*------E---------------*
--    |       |
--    |       |
--    `-------'
--

-- And we end up with this where I have no loose ends

--
--    ,---E3--.
--    |       |     
--    |       |
--    *---E5--*
--    |       |
--    |       |
--    `---E4--'
--


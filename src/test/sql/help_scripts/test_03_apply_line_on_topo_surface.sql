
--added a closed linestring
select topo_update.apply_line_on_topo_surface('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.55375, 5.70152 58.55373, 5.70182 58.55131)',32632,0);

-- and I get this
--    ,---E3--.
--    |       |     
--    |       |
--    |       |
--    |       |
--    |       |
--    `-------'

-- added linstring that splits this polygon in two pices
select topo_update.apply_line_on_topo_surface('SRID=4258;LINESTRING (5.699969 58.553169, 5.705346 58.553333)',32632,0);

--
--    ,---E3--.
--    |       |     
--*------E---------------*
--    |       |
--    |       |
--    |       |
--    `-------'
--

-- And we end up with this where I have no loose ends

--
--    ,---E3--.
--    |       |     
--    *---E5--*
--    |       |
--    |       |
--    |       |
--    `---E4--'
--


-- added linstring that splits this polygon in two pices
select topo_update.apply_line_on_topo_surface('SRID=4258;LINESTRING (5.700015 58.551848, 5.705353 58.552162)',32632,0);

--
--    ,---E3--.
--    |       |     
--    *---E5--*
--    |       |
--*------E6---------------*
--    |       |
--    `-------'
--

-- And we end up with this where I have no loose ends

--
--    ,---E3--.
--    |       |     
--    *---E5--*
--    |       |
--    *---E6--*
--    |       |
--    `---E4--'
--
--
-- added linstring that splits this polygon in two pices
select topo_update.apply_line_on_topo_surface('SRID=4258;LINESTRING (5.702548 58.553697, 5.702477 58.551549)',32632,0);


-- And we end up with this where I have no loose ends

--
--    ,---E3--.
--    | |     |     
--    *-|-E5--*
--    | |     |
--    *-|-E6--*
--    | |     |
--    `---E4--'
--
-- And we end up with this where I have no loose ends

--
--    ,---E3--.
--    |       |     
--    *-|-E5--*
--    | |     |
--    *-|-E6--*
--    |       |
--    `---E4--'
--
--



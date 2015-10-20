

--added a simplelinestring
select topo_update.create_line_edge_domain_obj('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.55375)');

-- and I get this
--    ,---E3--.
--    |       |     
--    |       |
--    |       |
--    |       |
--    |       |
--    `

-- added linstring that splits this polygon in two pices
-- select topo_update.create_line_edge_domain_obj('SRID=4258;LINESTRING (5.701298 58.551259, 5.702758 58.552522, 5.704312 58.553801)');

--
--    ,---E3--.
--    |       |     
--    |       |
--*------E---------------*
--    |       |
--    |       |
--    `
--

-- And we end up with this where I have no loose ends

--
--    ,---E3--.
--    |       |     
--    |       |
--*------E---------------*
--    |       |
--    |       |
--    `---E4--'
--



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
select topo_update.apply_line_on_topo_surface('SRID=4258;LINESTRING (5.701298 58.551259, 5.702758 58.552522, 5.704312 58.553801)',32632,0);

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

--added a bigger closed linestring than E3
select topo_update.apply_line_on_topo_surface('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.704899 58.554966, 5.70152 58.55373, 5.70182 58.55131)',32632,0);

--    
--    ,-------E4--.
--    |           |
--    |---E3--.   |
--    |       |   |     
--    |       |   |
--    |       |   /
--    |       | /
--    |       |
--    `-------'
--
-- and we get this
--    
--    ,-------E4--.
--    |           |
--    |           |
--    |           |     
--    |           |
--    |          /
--    |        /
--    |       |
--    `-------'


-- added linstring that splits this mergde polygon in two picese again
select topo_update.apply_line_on_topo_surface('SRID=4258;LINESTRING (5.701298 58.551259, 5.702758 58.552522, 5.704312 58.553801, 5.705144 58.554435)',32632,0);
--
--               /
--    ,-------E4/-.
--    |        /  |
--    |       /   |
--    |      /    |     
--    |     /     |
--    |    /    /
--    |   /    /
--    |  /    |
--    `-/-----'
--     /
--
--
-- and we get this
--    
--               
--    ,-------E4/-.
--    |        /  |
--    |       /   |
--    |      /    |     
--    |     /     |
--    |    /    /
--    |   /    /
--    |  /    |
--    `-/-----'
--     


--select count(*) from topo_rein.arstidsbeite_var_grense;
--select * from topo_rein.arstidsbeite_var_grense;
--select * from topo_rein.arstidsbeite_var_flate;
--select * from topo_rein_sysdata.relation ;
--select edge_id,start_node,end_node,next_left_edge,abs_next_left_edge,next_right_edge,abs_next_right_edge,left_face,right_face from topo_rein_sysdata.edge_data;
--select face_id from topo_rein_sysdata.face;

-- Adjust the input edge based on given simplify_patteren

-- 1-9 point
-- 10-20 linestring
-- 20-30 surface

CREATE OR REPLACE FUNCTION topo_update.get_adjusted_edge(edge geometry, simplify_patteren int) 
RETURNS geometry AS $$
DECLARE
-- used for creating new topo objects
new_edge geometry := edge;
num_points int;
divide_by int;
point_array_line geometry[2];
BEGIN
	-- linstrings
	IF simplify_patteren = 10 THEN 
		num_points := ST_NumPoints(edge);
		IF ST_NumPoints(edge) > 4 THEN
			point_array_line[0] := ST_StartPoint(edge) ;
			point_array_line[1] := ST_EndPoint(edge) ;
			new_edge := ST_MakeLine(point_array_line);	
		END IF;
	-- linestring
	ELSIF simplify_patteren = 11 THEN 
		num_points := ST_NumPoints(edge);
		IF ST_NumPoints(edge) > 4 THEN
			new_edge := ST_SimplifyPreserveTopology(edge,0.01);
	 	END IF;
	ELSIF simplify_patteren = 20 THEN 
		num_points := ST_NumPoints(edge);
		IF ST_NumPoints(edge) > 4 THEN
			new_edge := ST_SimplifyPreserveTopology(edge,0.01);
	 	END IF;
	END IF;

	RETURN new_edge;

END;
$$ LANGUAGE plpgsql IMMUTABLE;


		

-- Adjust the input edge based on given simplify_patteren

CREATE OR REPLACE FUNCTION topo_update.get_adjusted_edge(edge geometry, simplify_patteren int) 
RETURNS geometry AS $$
DECLARE
-- used for creating new topo objects
new_edge geometry := edge;
num_points int;
divide_by int;
point_array_line geometry[2];
BEGIN
	IF simplify_patteren = 1 THEN 
		num_points := ST_NumPoints(edge);
		IF ST_NumPoints(edge) > 4 THEN
			new_edge := ST_SimplifyPreserveTopology(edge,0.05);
	 	END IF;
	ELSIF simplify_patteren = 2 THEN 
		num_points := ST_NumPoints(edge);
		IF ST_NumPoints(edge) > 4 THEN
			point_array_line[0] := ST_StartPoint(edge) ;
			point_array_line[1] := ST_EndPoint(edge) ;
			new_edge := ST_MakeLine(point_array_line);	
		END IF;
	END IF;

	RETURN new_edge;

END;
$$ LANGUAGE plpgsql IMMUTABLE;


		

CREATE OR REPLACE FUNCTION topo_rein.findExtent(schema_name text, table_name text , geocolumn_name text )
RETURNS geometry AS $$
DECLARE
bb geometry = null;
command_string text;
BEGIN
	IF (EXISTS 
			( SELECT * FROM topo_rein_sysdata.edge_data  limit 1)
	) THEN
		BEGIN
			SELECT ST_EstimatedExtent(schema_name,table_name, geocolumn_name)::geometry into bb;
        EXCEPTION WHEN internal_error THEN
        -- ERROR:  XX000: stats for "edge_data.geom" do not exist
        -- Catch error and return a return null ant let application decide what to do
        END;
	END IF;
	
	RETURN bb;
END;
$$ LANGUAGE 'plpgsql' VOLATILE;

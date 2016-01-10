
CREATE OR REPLACE FUNCTION topo_rein.findExtent(schema_name text, table_name text , geocolumn_name text )
RETURNS geometry AS $$
DECLARE
bb geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

command_result text;

BEGIN

	RAISE NOTICE 'schema_name is %',  schema_name;

	command_string := FORMAT('SELECT 1 FROM %I.edge_data limit 1',
                        schema_name);

    RAISE NOTICE 'command_string eeee is %',  command_string;

    EXECUTE command_string into command_result;
		
        
	IF command_result IS NOT NULL THEN
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

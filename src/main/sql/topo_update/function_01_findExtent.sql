
CREATE OR REPLACE FUNCTION topo_rein.findExtent(schema_name text, table_name text , geocolumn_name text )
RETURNS text AS $$
DECLARE
bb geometry;
command_string text;
BEGIN
	--	TODO fix function
	IF (EXISTS 
			( SELECT * FROM topo_rein_sysdata.edge_data  limit 1)
	) THEN
		BEGIN
			SELECT ST_EstimatedExtent(schema_name,table_name, geocolumn_name)::geometry into bb;
        EXCEPTION WHEN internal_error THEN
        -- ERROR:  XX000: stats for "edge_data.geom" do not exist
        	-- Catch error and return a empty polygon ant he let application decide what to do
   			SELECT ST_GeomFromText('POLYGON EMPTY') into bb;

        END;
	ELSE
		SELECT ST_GeomFromText('POLYGON EMPTY') into bb;
	END IF;
	
    RAISE NOTICE '%', St_AsText(bb);
	
    -- This is hack needed by the cleint
	RETURN St_AsText(bb);
END;
$$ LANGUAGE 'plpgsql' VOLATILE;

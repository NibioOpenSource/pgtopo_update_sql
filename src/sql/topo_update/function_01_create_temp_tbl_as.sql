
-- TODO move this function to it's file

-- DROP function topo_update.create_temp_tbl_as(tblname text,qry text);
-- {
CREATE OR replace function topo_update.create_temp_tbl_as(tblname text,qry text)
returns text as
$$ 
BEGIN
$1 = trim($1);
IF NOT EXISTS (SELECT relname FROM pg_catalog.pg_class where relname =$1) THEN
	return 'CREATE TEMP TABLE '||$1||' ON COMMIT DROP AS '||$2||'';
--IF NOT EXISTS (SELECT 1 FROM pg_tables where tablename = substr($1,strpos($1,'.')+1) AND schemaname = substr($1,0,strpos($1,'.')) ) THEN
--	return 'CREATE TABLE '||$1||' AS '||$2||'';
else
	return 'TRUNCATE TABLE '||$1||'';
END IF;
END
$$
language plpgsql;
--}

-- TODO move this function to it's file

-- DROP function topo_update.create_temp_tbl_def(tblname text,def text);
-- {
CREATE OR replace function topo_update.create_temp_tbl_def(tblname text,def text)
returns text as
$$ 
BEGIN
$1 = trim($1);
IF NOT EXISTS (SELECT relname FROM pg_catalog.pg_class where relname =$1) THEN
	return 'CREATE TEMP TABLE '||$1||''||$2||' ON COMMIT DROP';
--IF NOT EXISTS (SELECT 1 FROM pg_tables where tablename = substr($1,strpos($1,'.')+1) AND schemaname=substr($1,0,strpos($1,'.')) ) THEN
--	return 'CREATE TABLE '||$1||''||$2||'';
else
	return 'TRUNCATE TABLE '||$1||'';
END IF;
END
$$
language plpgsql;
--}


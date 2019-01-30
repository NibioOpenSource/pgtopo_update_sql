

-- set status to 10 for givene object
CREATE OR REPLACE FUNCTION topo_update.layer_accept_update(_data_update_log_id_after int, _row_id int, _saksbehandler varchar ) 
RETURNS int AS $$DECLARE

num_rows_affected int;

-- holds dynamic sql to be able to use the same code for different
command_string text;

this_schema_name text;

this_table_name text;

BEGIN

	-- get schema name and table nam,e value
	select s.schema_name, s.table_name into this_schema_name, this_table_name 
	from topo_rein.data_update_log s
	where row_id = _row_id and change_confirmed_by_admin = false;

	command_string := format('update %I.%I set status = 1, saksbehandler = %L where id = %L',
	this_schema_name, this_table_name, _saksbehandler, _row_id);

	RAISE NOTICE 'command_string %' , command_string;

	EXECUTE command_string;

	update topo_rein.data_update_log s
	set change_confirmed_by_admin = true
	where row_id = _row_id and change_confirmed_by_admin = false;

	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of meta rows affected  %',  num_rows_affected;
	

	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;


--select topo_update.layer_accept_update(0,0,'eee');




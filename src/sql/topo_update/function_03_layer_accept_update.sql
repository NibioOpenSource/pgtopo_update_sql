

-- set status to 10 for givene object
CREATE OR REPLACE FUNCTION topo_update.layer_accept_update(_data_update_log_id_after int, _saksbehandler varchar )
RETURNS int AS $$DECLARE

num_rows_affected int;

-- holds dynamic sql to be able to use the same code for different
command_string text;

this_schema_name text;

this_table_name text;

this_data_row_id int;

BEGIN


	-- get schema name and table nam,e value
	select s.schema_name, s.table_name, s.row_id
	into this_schema_name, this_table_name, this_data_row_id
	from topo_rein.data_update_log s
	where s.id = _data_update_log_id_after and s.change_confirmed_by_admin = false;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'topo_update.layer_accept_update: no unconfirmed change found in data_update_log with id=%', _data_update_log_id_after;
	END IF;

	command_string := format('update %I.%I set status = 1, saksbehandler = %L where id = %L',
	this_schema_name, this_table_name, _saksbehandler, this_data_row_id);
	RAISE NOTICE 'command_string %' , command_string;
	EXECUTE command_string;

	update topo_rein.data_update_log s
	set change_confirmed_by_admin = true
	where s.row_id = this_data_row_id and s.schema_name = this_schema_name and s.table_name = this_table_name and s.change_confirmed_by_admin = false;
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of meta rows affected  %',  num_rows_affected;


	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;


--select topo_update.layer_accept_update(0,0,'eee');




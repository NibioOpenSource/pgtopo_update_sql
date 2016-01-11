--DROP OWNED BY topo_rein cascade;
--DROP OWNED BY topo_update cascade;

drop schema topo_rein cascade;
select topology.droptopology('topo_rein_sysdata');
select topology.droptopology('topo_rein_sysdata_rvr');
drop schema topo_update cascade;


drop schema topo_rein cascade;
select topology.droptopology('topo_rein_sysdata');
drop schema topo_update cascade;

DROP OWNED BY topo_rein cascade;
DROP OWNED BY topo_update cascade;

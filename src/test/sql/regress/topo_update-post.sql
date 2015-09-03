drop schema topo_rein cascade;
select topology.droptopology('topo_rein_sysdata');
drop schema topo_update cascade;

DROP OWNED BY topo_rein cascade;
DROP OWNED BY topo_update_crud1 cascade;
DROP OWNED BY topo_update cascade;

DROP role topo_rein;
DROP role topo_update_crud1;
DROP role topo_update;

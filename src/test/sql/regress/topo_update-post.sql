--DROP OWNED BY topo_rein cascade;
--DROP OWNED BY topo_update cascade;

drop schema topo_rein cascade;
select topology.droptopology('topo_rein_sysdata');
select topology.droptopology('topo_rein_sysdata_rvr');
select topology.droptopology('topo_rein_sysdata_rso');
select topology.droptopology('topo_rein_sysdata_rhs');
select topology.droptopology('topo_rein_sysdata_rhv');
select topology.droptopology('topo_rein_sysdata_rvi');

select topology.droptopology('topo_rein_sysdata_rbh');
select topology.droptopology('topo_rein_sysdata_rop');
select topology.droptopology('topo_rein_sysdata_ran');
select topology.droptopology('topo_rein_sysdata_rtr');

drop schema topo_update cascade;

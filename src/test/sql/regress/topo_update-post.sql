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

select topology.droptopology('topo_rein_sysdata_rav');
select topology.droptopology('topo_rein_sysdata_reo');
select topology.droptopology('topo_rein_sysdata_rks');
select topology.droptopology('topo_rein_sysdata_rko');
select topology.droptopology('topo_rein_sysdata_rdg');
select topology.droptopology('topo_rein_sysdata_reb');
select topology.droptopology('topo_rein_sysdata_rro');
select topology.droptopology('topo_rein_sysdata_rsi');

select topology.droptopology('topo_rein_sysdata_rdr');

drop schema topo_update cascade;

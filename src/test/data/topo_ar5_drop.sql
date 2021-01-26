-- Drop AR5 web client data
drop schema topo_ar5 cascade;
select topology.droptopology('topo_ar5_sysdata_webclient');

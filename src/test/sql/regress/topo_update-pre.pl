#!/usr/bin/perl
use File::Copy;
use File::Spec::Functions;

$REIN_TABLES_DEF='topo_update_rein_table_def-pre.sql';

if ( -e '/Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/schema_topo_rein.sql' ) 
{


	print "Source file for rein data exist so we can create a new $REIN_TABLES_DEF \n";
	# We need the spatial ref. for this tests 
	open($fh_out, ">", $REIN_TABLES_DEF);

	print $fh_out "CREATE ROLE topo_update; \n";
	print $fh_out "CREATE ROLE topo_update_crud1; \n";

	# This tables are not in any public repo so we only generate when they are available 
	for my $file (glob '/Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/schema*.sql') {
		copy_file_into($file,$fh_out);
	}

	copy_file_into('/Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/tables_01_kode_topo_rein.sql',$fh_out);
	copy_file_into('/Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_arstidsbeite_var.sql',$fh_out);
	copy_file_into('/Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/view_01_arstidsbeite_var.sql',$fh_out);
	
	
	close($fh_out);	 
	
	
} 
else
{
	print "Source file for rein data does not exist so we use the old one $REIN_TABLES_DEF \n";
}

# build up topo_update.sql file used for test
open($fh_out_final, ">", 'topo_update-pre.sql');

copy_file_into($REIN_TABLES_DEF,$fh_out_final);

copy_file_into('../../../main/sql/topo_update/schema_topo_update.sql',$fh_out_final);

for my $file (glob '../../../main/sql/topo_update/schema_userdef*') {
	copy_file_into($file,$fh_out_final);
}

for my $file (glob '../../../main/sql/topo_update/function*') {
	copy_file_into($file,$fh_out_final);
}

close($fh_out_final);	 


sub copy_file_into() { 
	my ($v1, $v2) = @_;
	open(my $fh, '<',$v1);
	while (my $row = <$fh>) {
	  print $v2 "$row\n";
	}
	close($fh);	 
    
}

#!/usr/bin/perl
use File::Copy;
use File::Spec::Functions;

my ($pre_filename) = @ARGV;


print "\n Output file is $pre_filename \n";

$REIN_TABLES_DEF='topo_common-pre.sql';

if ( -e '/Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/schema_topo_rein.sql' ) 
{


	print "Source file for rein data exist so we can create a new $REIN_TABLES_DEF \n";
	# We need the spatial ref. for this tests 
	open($fh_out, ">", $REIN_TABLES_DEF);

	# This tables are not in any public repo so we only generate when they are available 
	for my $file (glob '/Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/schema*.sql') {
		copy_file_into($file,$fh_out);
	}

	copy_file_into('/Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/tables_01_kode_topo_rein.sql',$fh_out);
	copy_file_into('/Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_arstidsbeite_var_flate.sql',$fh_out);
	copy_file_into('/Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_reindrift_anlegg_linje.sql',$fh_out);
	copy_file_into('/Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_reindrift_anlegg_punkt.sql',$fh_out);
	copy_file_into('/Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_rein_trekklei_linje.sql',$fh_out);

	# This tables are not in any public repo so we only generate when they are available 
	for my $file (glob '/Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/view_*.sql') {
		copy_file_into($file,$fh_out);
	}
	
	close($fh_out);	 
	
	
} 
else
{
	print "Source file for rein data does not exist so we use the old one $REIN_TABLES_DEF \n";
}

# build up topo_update.sql file used for test
open($fh_out_final, ">", $pre_filename);

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
	  print $v2 "$row";
	}
	close($fh);	 
    
}

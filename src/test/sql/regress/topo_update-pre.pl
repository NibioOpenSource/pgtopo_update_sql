#!/usr/bin/perl

use strict;
use warnings;

my $pre_filename = "topo_update-pre.sql";
my $cmd = "perl topo_common-pre.pl $pre_filename";

#print "\nStart $cmd \n";
my $exit_code = system "$cmd";
$exit_code == 0;

#print "\nDone $cmd \n";


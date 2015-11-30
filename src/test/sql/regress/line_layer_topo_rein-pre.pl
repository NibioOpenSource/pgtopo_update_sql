#!/usr/bin/perl

use strict;
use warnings;

my $pre_filename = "line_layer_topo_rein-pre.sql";
my $cmd = "perl topo_common-pre.pl $pre_filename";

print "\nStart $cmd \n";
system "$cmd" ;
print "\nDone $cmd \n";

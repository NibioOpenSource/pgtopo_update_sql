#!/usr/bin/perl

use strict;
use warnings;

our $TEST;
my $REGDIR = abs_path(dirname($0));

my $pre_filename = $TEST . '-pre.sql';
my $cmd = "perl topo_common-pre.pl $pre_filename";
return 0 if system("$cmd") != 0;

my $post_filename = $TEST . '-post.sql';
# TODO: use topo_common-post.sql instead ?
symlink(${REGDIR}.'/topo_update-post.sql', $post_filename);

1;

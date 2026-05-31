#!/usr/bin/perl -w

use strict;

use FindBin;
use lib $FindBin::Bin;

use MITRAILLE;

MITRAILLE::run (
  station         => $ENV{STATION},
  mit_install_dir => $ENV{MIT_INSTALL_DIR},
  build           => $ENV{BUILD},
  cycle           => $ARGV[0],
  pro_file        => $ARGV[1],
);

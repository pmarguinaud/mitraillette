package mitraille::printer::csv;

use strict;

use base qw (mitraille::printer);

sub separator
{
  return " ; ";
}

sub interval
{
  0;
}

1;

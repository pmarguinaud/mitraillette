package mitraille::printer::terminal;

use strict;

use base qw (mitraille::printer);

sub colored
{
  use Term::ANSIColor qw ();
  my $self = shift;
  return &Term::ANSIColor::colored (@_);
}

sub separator
{
  return " | ";
}

sub interval
{
  my $self = shift;
  return $self->{interval};
}

1;

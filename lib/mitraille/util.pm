package mitraille::util;

use strict;

use FileHandle;

use base qw (Exporter);

our @EXPORT_OK = qw (slurp slurpl spew);

# Contents of a file, as a string

sub slurp
{
  my $f = shift;
  (my $fh = 'FileHandle'->new ("<$f")) or die ("Cannot open `$f'\n");
  local $/ = undef;
  my $text = <$fh>;
  return $text;
}

# Lines of a file, without end of line

sub slurpl
{
  my $f = shift;
  (my $fh = 'FileHandle'->new ("<$f")) or die ("Cannot open `$f'\n");
  my @x = <$fh>;
  chomp for (@x);
  return @x;
}

# Write a file

sub spew
{
  my ($f, $text) = @_;
  (my $fh = 'FileHandle'->new (">$f")) or die ("Cannot write `$f'\n");
  $fh->print ($text);
  $fh->close () or die ("Cannot write `$f'\n");
}

1;

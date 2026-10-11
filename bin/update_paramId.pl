#!/usr/bin/perl
#
# Merge extra parameter definitions into an ecCodes paramId.def file.
#
# Usage: update_paramId.pl BASE.def EXTRA.def [OUTPUT.def]
#
# Entries of EXTRA.def replace all entries of BASE.def with the same paramId;
# new paramIds are appended. Comment lines just above an entry (its name)
# go with it. Output goes to OUTPUT.def, or stdout if omitted.
# OUTPUT.def may be BASE.def (in-place update).
#

use File::Path;
use File::Basename;

use strict;

use warnings;

die "Usage: $0 BASE.def EXTRA.def [OUTPUT.def]\n" unless (@ARGV == 2 || @ARGV == 3);
my ($base, $extra, $output) = @ARGV;

sub slurp
{
  my $f = shift;

  my $fh;

  if ($f eq '-')
    {
      $fh = \*STDIN;
    }
  else
    {
      open ($fh, '<', $f) or die "Cannot open $f: $!\n";
    }

  local $/;
  my $text = <$fh>;
  close ($fh);
  $text .= "\n" if (length ($text) && $text !~ m/\n\z/o);
  return $text;
}

# One entry: leading comment lines, then 'ID' = { ... }
my $ENTRY = qr/((?:^[ \t]*#[^\n]*\n)*)^[ \t]*'([^']+)'[ \t]*=[ \t]*\{[^}]*\}[^\n]*\n/m;

my $extratext = &slurp ($extra);

my @ids;
while ($extratext =~ m/$ENTRY/g)
  {
    push @ids, $2;
  }
die "No definition found in $extra\n" unless (@ids);
my %ids = map { ($_, 1) } @ids;

my $text = &slurp ($base);

my %replaced;
$text =~ s/$ENTRY/$ids{$2} ? do { $replaced{$2}++; '' } : $&/ge;

$text .= $extratext;

for my $id (@ids)
  {
    printf STDERR ("%-10s %s\n", $id, $replaced{$id} ? "replaced ($replaced{$id} entries)" : "added");
  }

if (defined ($output))
  {
    &mkpath (&dirname ($output));
    open (my $fh, '>', $output) or die "Cannot write $output: $!\n";
    print $fh $text;
    close ($fh);
  }
else
  {
    print $text;
  }

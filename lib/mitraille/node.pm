package mitraille::node;

# Comparison of the spectral norms printed by two runs of a test case

use strict;

use FileHandle;

# Spectral norms of a job output: a list of [step, field, value]; step is the
# NSTEP of the preceding "NORMS AT NSTEP" line, or `-' for the norms printed
# before the first time step

#  NORMS AT NSTEP CNT4    1
#  SPECTRAL NORMS -    LOG(PREHYDS)    0.114991694787231E+02
#  LEV     VORTICITY             DIVERGENCE           TEMPERATURE            HUMIDITY             KINETIC ENERGY
#  AVE 0.227212030872266E-04 0.567044894920163E-05 0.256646026048479E+03 0.430636858016040E-02 0.153979781408458E+03

sub norms
{
  my $f = shift;

  my $fh = 'FileHandle'->new ("<$f");
  $fh or die ("Cannot open $f\n");

  my @line = <$fh>;

  my $step = '-';
  my @x;

  while (defined (my $line = shift (@line)))
    {
      if ($line =~ m/^\s*NORMS AT NSTEP CNT4\s+(\d+)/o)
        {
          $step = $1;
          next;
        }

      next unless ($line =~ m/^\s*SPECTRAL\s+NORMS\s+-\s+LOG\(PREHYDS\)\s+(\S+)/o);

      push @x, [$step, LOG_PREHYDS => $1];

# Field names (separated by two blanks at least), then their average values

      while (@line && ($line[0] =~ m/^\s+LEV\s+(.*?)\s*$/o))
        {
          my @k = split (m/\s{2,}/o, $1);
          shift (@line);
          last unless (@line && ($line[0] =~ m/^\s+AVE\s+(.*?)\s*$/o));
          my @v = split (m/\s+/o, $1);
          shift (@line);
          push @x, [$step, '?', '?'] if (scalar (@k) != scalar (@v)); # Cannot be compared
          push @x, map { [$step, $k[$_], $v[$_]] } (0 .. $#k);
        }
    }

  return @x;
}

my $INF = 999**999;

sub digitdiff
{
  my ($x1, $x2) = @_;
  return $INF if ($x1 == $x2);
  return - log (abs ($x1 - $x2)) / log (10);
}

my @find = qw (TEMPERATURE VORTICITY DIVERGENCE);

sub fields
{
  return @find;
}

# Compare the spectral norms of two job outputs; returns:
#  {struct => 1}                      : norms cannot be compared (different
#                                       steps, fields or number of prints)
#  {diff => 0}                        : identical norms
#  {diff => 1, step => s, digits => [...]} : s is the first step with a difference,
#                                       digits the minimum number of common digits
#                                       for each of fields ()

sub compare
{
  my ($f1, $f2) = @_;

  my @x1 = &norms ($f1);
  my @x2 = &norms ($f2);

  return {struct => 1} if (scalar (@x1) != scalar (@x2));

  my %mind = map { ($_, $INF) } @find;
  my $step;

  for my $i (0 .. $#x1)
    {
      my ($s1, $k1, $v1) = @{ $x1[$i] };
      my ($s2, $k2, $v2) = @{ $x2[$i] };

      return {struct => 1} if (($s1 ne $s2) || ($k1 ne $k2) || ($k1 eq '?'));

      for ($v1, $v2)
        {
          s/(\d)([+-]\d+)$/$1E$2/o;
        }

      next if (sprintf ('%17.9e', $v1 - $v2) + 0. == 0.);

      $step = $s1 unless (defined ($step));

      $mind{$k1} = &digitdiff ($v1, $v2)
        if (exists ($mind{$k1}) && (&digitdiff ($v1, $v2) < $mind{$k1}));
    }

  return {diff => 0} unless (defined ($step));

  return {diff => 1, step => $step, digits => [map { sprintf ('%5.2f', $mind{$_}) } @find]};
}

1;

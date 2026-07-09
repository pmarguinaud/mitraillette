package mitraille::node;

use strict;

use FileHandle;
use Data::Dumper;

my @spnorms = ("VORTICITY", "DIVERGENCE", "TEMPERATURE", "KINETIC ENERGY");

sub xave
{
  my $f = shift;
  my $fh = 'FileHandle'->new ("<$f");

  $fh or die ("Cannot open $f\n");

  my @gpregs;


  my @line = <$fh>;
  my @x;
  MAIN: while (defined (my $line = shift (@line)))
    {
      AGAIN:

#  GPNORMS OF FIELDS TO BE WRITTEN OUT ON FILE :
#                                    AVERAGE               MINIMUM               MAXIMUM
#  PROFTEMPERATURE  : 0.291195674511515E+03 0.201887381812149E+03 0.315847778487033E+03

      if ($line =~ s/^\s*SPECTRAL\s+NORMS\s+-\s+LOG\(PREHYDS\)\s+(\S+)//o)
        {
          my $LOG_PREHYDS = $1;

          push @x, [LOG_PREHYDS => $LOG_PREHYDS];

          AGAIN_SPNORMS:

          goto AGAIN
            unless (($line = shift (@line)) =~ s/^\s+LEV\s+//o);

          my %index;
          %index = ();
          for my $spnorm (@spnorms)
            {
              my $index = index ($line, $spnorm);
              $index{$spnorm} = $index 
                if ($index >= 0);
            }

          my @spnormk = sort { $index{$a} <=> $index{$b} } 
                        grep { defined $index{$_} } 
                        @spnorms;

          goto AGAIN
            unless (($line = shift (@line)) =~ s/^\s+AVE\s+//o);

          my @spnormv = split (m/\s+/o, $line);

          while (@spnormk)
            {
              my $spnormk = shift (@spnormk);
              my $spnormv = shift (@spnormv);
              die ("$spnormk, $spnormv\n")
                unless (defined ($spnormk) && defined ($spnormv));
              push @x, [ $spnormk, $spnormv ];
            }

          goto AGAIN_SPNORMS;

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

sub diff
{
  my ($f1, $f2) = @_;

  my @fx1 = &xave ($f1);
  my @fx2 = &xave ($f2);

  my @x = ([]);
  
  my $diff = 0;

  my %mind; # Minimum number of common digits
  for (@find)
    {
      $mind{$_} = $INF;
    }
  
  while (defined (my $fx1 = shift (@fx1)) && defined (my $fx2 = shift (@fx2)))
    {
      my ($f1, $x1) = @$fx1;
      my ($f2, $x2) = @$fx2;
  
      die ("Field mismatch $f1 != $f2\n")
        unless ($f1 eq $f2);
  
      chomp ($x1); chomp ($x2);

      if (($x1 !~ m/^\s*$/o) && ($x2 !~ m/^\s*$/o))
        {
          for ($x1, $x2)
            {
              s/(\d)([+-]\d+)$/$1E$2/o;
            }
          my $dx = $x1 - $x2;
  
          my $sdx = sprintf ('%17.9e', $dx);
  
          $dx = $sdx; $dx = $dx + 0.;
  
          push @{$x[-1]},
            sprintf (" | %-20s | %17.9e  |  %17.9e  |  %17s  | \n", $f1, $x1, $x2, $sdx);
  
          $diff++ if ($dx);

          my $dd = &digitdiff ($x1, $x2);

          if ($mind{$f1})
            {
              $mind{$f1} = $dd if ($dd < $mind{$f1});
            }
        }
      else
        {
          push @x, [];
        }
    }

  my @mind = map { sprintf ('%5.2f', $mind{$_}) } @find;

  return $diff ? (@mind) : ();
}

1;

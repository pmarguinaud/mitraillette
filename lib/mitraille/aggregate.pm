package mitraille::aggregate;

use FileHandle;
use Data::Dumper;
use Storable;

use strict;

use mitraille::aggregate::maxtime;
use mitraille::aggregate::maxjob;

sub slurpl
{
  my $f = shift;
  my @x = do { my $fh = 'FileHandle'->new ("<$f"); <$fh> };
  chomp for (@x);
  return @x;
}

sub header
{
  my $f = shift;

  my @sbatch = grep { s/^#SBATCH\s+//o } &slurpl ($f);

  my %h;

  for (@sbatch)
    {
      s/\s*$//o;
      next if (m/^--job-name=/o);
      next if (m/^-J/o);

      if (m/^(--\S+)=(.*)$/o)
        {
          $h{$1} = $2;
        }
      elsif (m/^(--?\S+)\s+(\S.*)$/o)
        {
          $h{$1} = $2;
        }
      elsif (m/^(-\S+)$/o)
        {
          $h{$1} = '__FLAG__';
        }
    }  

  for (values (%h))
    {
      s/^"//o;
      s/"$//o;
    }

  return \%h;
}

sub aggregate
{
  my $args = shift;

  return $args->{maxjob} > 0 
       ? &mitraille::aggregate::maxjob::aggregate ($args->{maxjob}, @_)
       : &mitraille::aggregate::maxtime::aggregate ($args->{maxtime}, @_)
  ;
}

1;

package mitraille::aggregate;

# Run several jobs (.cjob) sequentially in one Slurm job (mit.NNNNNN.sh);
# only jobs with the same #SBATCH directives (except job name, time and
# output) can be grouped. How the jobs of a group are distributed among
# wrappers is decided by mitraille::aggregate::maxtime or maxjob.

use FileHandle;
use Storable;

use strict;

use mitraille::util qw (slurpl);

use mitraille::aggregate::maxtime;
use mitraille::aggregate::maxjob;

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

# Slurm time limit (minutes, MM:SS, HH:MM:SS, D-HH, D-HH:MM, D-HH:MM:SS) in minutes

sub minutes
{
  my $limit = shift;

  (my $t = $limit) =~ s/^\s+|\s+$//go;

  my $d = ($t =~ s/^(\d+)-//o) ? $1 : 0;
  my @x = split (m/:/o, $t);

  die ("Cannot parse time limit `$limit'\n")
    if (grep { ! m/^\d+$/o } @x) || (! @x) || (@x > 3);

  my ($h, $m, $s);

  if ($d)
    {
      ($h, $m, $s) = (@x, 0, 0)[0 .. 2];
    }
  elsif (@x == 3)
    {
      ($h, $m, $s) = @x;
    }
  else
    {
      ($h, $m, $s) = (0, @x, 0)[0 .. 2];
    }

  my $minutes = ((24 * $d + $h) * 60 + $m) + $s / 60;

  return $minutes == int ($minutes) ? $minutes : int ($minutes) + 1;
}

# Group jobs by Slurm directives; returns a list of [header, [jobs]], groups using
# more nodes first. A job is {file => ..., time => minutes, output => ...}.

sub group
{
  my @cjob = @_;

  local $Storable::canonical = 1;

  my (%j, %h);

  for my $f (@cjob)
    {
      my $h = &header ($f);

      my $time = &minutes (delete $h->{'--time'});
      my $o = delete $h->{'-o'};

      my $sign = &Storable::freeze ($h);

      push @{ $j{$sign} }, {file => $f, time => $time, output => $o};
      $h{$sign} = $h;
    }

  return map { [$h{$_}, $j{$_}] }
         sort { ($h{$b}{'--nodes'} <=> $h{$a}{'--nodes'}) || ($a cmp $b) } keys (%j);
}

# Write a wrapper running some jobs of the same group, one after the other

sub write_wrapper
{
  my ($sh, $h, @job) = @_;

  my $time = 0;
  $time += $_->{time} for (@job);

  my $fh = 'FileHandle'->new (">$sh");

  $fh->print ("#!/bin/bash\n");

  for my $attr (sort keys (%$h))
    {
      if ($h->{$attr} eq '__FLAG__')
        {
          $fh->print ("#SBATCH $attr\n");
        }
      else
        {
          $fh->print ("#SBATCH $attr $h->{$attr}\n");
        }
    }

  $fh->printf ("#SBATCH --time %d\n", $time + scalar (@job)); # + 1 minute per job
  $fh->print ("#SBATCH -o /dev/null\n");

  $fh->print ("\n" x 2);

  for my $job (@job)
    {
      chmod (0755, $job->{file});
      (my $output = $job->{output}) =~ s/%j/\$SLURM_JOBID/o;
      (my $CNMEXPL = $job->{file}) =~ s/\.cjob$//o;
      $fh->print ("echo \"CNMEXPL=$CNMEXPL\" > $output\n\n");
    }

  $fh->print ("\n" x 2);

  for my $job (@job)
    {
      (my $output = $job->{output}) =~ s/%j/\$SLURM_JOBID/o;
      $fh->print ("sleep 2; STARTTIME=\$(date +%Y-%m-%dT%H:%M:%S) timeout --signal=TERM $job->{time}m ./$job->{file} > $output 2>&1\n\n");
    }

  $fh->close ();

  return $sh;
}

# Returns the files to submit: either the jobs themselves, or wrappers (--maxjob
# takes precedence over --maxtime)

sub aggregate
{
  my ($args, @cjob) = @_;

  unlink ($_) for (<mit.*.sh>);

  my @bins; # [header, [jobs]] for each wrapper

  if ($args->{maxjob} > 0)
    {
      return @cjob if (scalar (@cjob) <= $args->{maxjob});
      @bins = &mitraille::aggregate::maxjob::bins ($args->{maxjob}, &group (@cjob));
    }
  elsif ($args->{maxtime} > 0)
    {
      @bins = &mitraille::aggregate::maxtime::bins ($args->{maxtime}, &group (@cjob));
    }
  else
    {
      return @cjob;
    }

  my $count = 0;

  return map { &write_wrapper (sprintf ('mit.%6.6d.sh', $count++), $_->[0], @{ $_->[1] }) } @bins;
}

1;

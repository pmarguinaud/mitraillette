package mitraille::aggregate;

use strict;

use FileHandle;
use Data::Dumper;
use Storable;

use strict;

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
  my $max = shift; # Max time in minutes

  my @cjob = @_;

  return @cjob unless ($max > 0);

  local $Storable::canonical = 1;
  
  my (%j, %h);
  
  for my $f (@cjob)
    {
      my $h = &header ($f);
  
      my $time = delete $h->{'--time'};
      my $o = delete $h->{'-o'};
  
      my $sign = &Storable::freeze ($h);

      push @{ $j{$sign} }, {file => $f, time => $time, output => $o};
      $h{$sign} = $h;
    }

  my @sh;
  
  my $count = 0;

  for my $sign (sort { $h{$b}{'--nodes'} <=> $h{$a}{'--nodes'} } keys (%j))
    {
      my $h = $h{$sign};

      my $time = 0;
  
      my @job;

      my $dump = sub
      {
        return unless (@job);

        push @sh, (my $sh = sprintf ('mit.%6.6d.sh', $count++));

        my $fh = 'FileHandle'->new (">$sh");
        
        $fh->print ("#!/bin/bash\n");

        for my $attr (sort keys (%$h))
          {
            if ($attr eq '-J') { }
            if ($attr eq '--job-name') { }
            elsif ($h->{$attr} eq '__FLAG__')
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
            chmod (0755, $job->{file});
            (my $output = $job->{output}) =~ s/%j/\$SLURM_JOBID/o;
            $fh->print ("sleep 2; STARTTIME=\$(date +%Y-%m-%dT%H:%M:%S) timeout --signal=TERM $job->{time}m ./$job->{file} > $output 2>&1\n\n");
          }
  
        $fh->close ();
  
        $time = 0; 
        @job = ();
      };
  
      for my $job (@{ $j{$sign} })
        {

          if ($time + $job->{'time'} > $max)
            {
              $dump->();
            }

          $time += $job->{'time'};
  
          push @job, $job;

        }

      $dump->();
  
    }

  return @sh;
}

1;

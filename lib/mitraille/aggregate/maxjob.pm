package mitraille::aggregate::maxjob;

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
  my $maxjob = shift;

  my @cjob = @_;
  unlink ($_) for (<mit.*.sh>);

  return @cjob unless ($maxjob > 0);

  return @cjob if (scalar (@cjob) <= $maxjob);

  local $Storable::canonical = 1;
  
  my (%j, %h);
  
  for my $f (@cjob)
    {
      my $hh = &header ($f);
  
      my $time = delete $hh->{'--time'};
      my $o = delete $hh->{'-o'};
  
      my $sign = &Storable::freeze ($hh);

      push @{ $j{$sign} }, {file => $f, time => $time, output => $o};
      $h{$sign} = $hh;
    }

  my $S = scalar keys %j;

  # Step 2: Compute minimum scripts per signature (always 1 when maxjob is active)
  my %min_scripts;
  my %total_time;

  for my $sign (sort { $h{$b}{'--nodes'} <=> $h{$a}{'--nodes'} } keys (%j))
    {
      $min_scripts{$sign} = 1;
      $total_time{$sign} = 0;
      $total_time{$sign} += $_->{time} for @{ $j{$sign} };
    }

  my $min_total = 0;
  $min_total += $min_scripts{$_} for keys %min_scripts;

  # Step 3: Determine target total
  my $target_total = ($maxjob >= $min_total) ? $maxjob : $min_total;

  # Step 4: Distribute extra slots
  my %k = %min_scripts;
  my $remaining = $target_total - $min_total;

  if ($remaining > 0)
    {
      while ($remaining > 0)
        {
          my $best_sign = undef;
          my $best_load = -1;

          for my $sign (keys %k)
            {
              my $njobs = scalar @{ $j{$sign} };
              next if ($k{$sign} >= $njobs);
              my $load = $total_time{$sign} / $k{$sign};
              if ($load > $best_load)
                {
                  $best_load = $load;
                  $best_sign = $sign;
                }
            }

          last unless defined $best_sign;

          $k{$best_sign}++;
          $remaining--;
        }
    }

  # Step 5 & 6: Pack jobs and write scripts
  my @sh;
  my $count = 0;

  for my $sign (sort { $h{$b}{'--nodes'} <=> $h{$a}{'--nodes'} } keys (%j))
    {
      my $hh = $h{$sign};
      my @bins;

      # Use LPT (Longest Processing Time) to pack jobs
      my @jobs = sort { $b->{time} <=> $a->{time} } @{ $j{$sign} };
      @bins = map { [] } (1 .. $k{$sign});
      my @bin_time = (0) x $k{$sign};

      for my $job (@jobs)
        {
          my $min_idx = 0;
          my $min_time = $bin_time[0];
          for my $i (1 .. $#bin_time)
            {
              if ($bin_time[$i] < $min_time)
                {
                  $min_time = $bin_time[$i];
                  $min_idx = $i;
                }
            }
          push @{ $bins[$min_idx] }, $job;
          $bin_time[$min_idx] += $job->{time};
        }

      for my $bin (@bins)
        {
          next unless (@$bin);

          my $bin_time = 0;
          $bin_time += $_->{time} for @$bin;

          push @sh, (my $sh = sprintf ('mit.%6.6d.sh', $count++));

          my $fh = 'FileHandle'->new (">$sh");
          
          $fh->print ("#!/bin/bash\n");

          for my $attr (sort keys (%$hh))
            {
              if ($attr eq '-J') { }
              if ($attr eq '--job-name') { }
              elsif ($hh->{$attr} eq '__FLAG__')
                {
                  $fh->print ("#SBATCH $attr\n");
                }
              else
                {
                  $fh->print ("#SBATCH $attr $hh->{$attr}\n");
                }
            }
          $fh->printf ("#SBATCH --time %d\n", $bin_time + scalar (@$bin));
          $fh->print ("#SBATCH -o /dev/null\n");
    
          $fh->print ("\n" x 2);
    
          for my $job (@$bin)
            {
              chmod (0755, $job->{file});
              (my $output = $job->{output}) =~ s/%j/\$SLURM_JOBID/o;
              (my $CNMEXPL = $job->{file}) =~ s/\.cjob$//o;
              $fh->print ("echo \"CNMEXPL=$CNMEXPL\" > $output\n\n");
            }
    
          $fh->print ("\n" x 2);
    
          for my $job (@$bin)
            {
              chmod (0755, $job->{file});
              (my $output = $job->{output}) =~ s/%j/\$SLURM_JOBID/o;
              $fh->print ("sleep 2; STARTTIME=\$(date +%Y-%m-%dT%H:%M:%S) timeout --signal=TERM $job->{time}m ./$job->{file} > $output 2>&1\n\n");
            }
    
          $fh->close ();
        }
    }

  return @sh;
}

1;

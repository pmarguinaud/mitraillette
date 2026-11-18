package mitraille::aggregate::maxtime;

# Distribute the jobs of each group among wrappers, in order, starting a new
# wrapper when the next job would make it exceed maxtime minutes

use strict;

sub bins
{
  my ($maxtime, @group) = @_;

  my @bins;

  for my $group (@group)
    {
      my ($h, $jobs) = @$group;

      my ($time, @job) = (0);

      for my $job (@$jobs)
        {
          if (@job && ($time + $job->{time} > $maxtime))
            {
              push @bins, [$h, [@job]];
              ($time, @job) = (0);
            }
          $time += $job->{time};
          push @job, $job;
        }

      push @bins, [$h, [@job]] if (@job);
    }

  return @bins;
}

1;

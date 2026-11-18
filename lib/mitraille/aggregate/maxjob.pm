package mitraille::aggregate::maxjob;

use strict;

sub bins
{
  my ($maxjob, @group) = @_;

  my @total = map { my $t = 0; $t += $_->{time} for (@{ $_->[1] }); $t } @group;

# One wrapper per group at least; extra wrappers go, one at a time, to the group
# with the highest load per wrapper (and less wrappers than jobs)

  my @k = (1) x scalar (@group);

  for (my $remaining = $maxjob - scalar (@group); $remaining > 0; $remaining--)
    {
      my ($best, $best_load) = (undef, -1);

      for my $i (0 .. $#group)
        {
          next if ($k[$i] >= scalar (@{ $group[$i][1] }));
          my $load = $total[$i] / $k[$i];
          ($best, $best_load) = ($i, $load) if ($load > $best_load);
        }

      last unless (defined ($best));

      $k[$best]++;
    }

# Pack the jobs of each group in its wrappers: longest jobs first, each in
# the wrapper with the smallest load (LPT)

  my @bins;

  for my $i (0 .. $#group)
    {
      my ($h, $jobs) = @{ $group[$i] };

      my @bin = map { [] } (1 .. $k[$i]);
      my @bin_time = (0) x $k[$i];

      for my $job (sort { $b->{time} <=> $a->{time} } @$jobs)
        {
          my ($min) = sort { ($bin_time[$a] <=> $bin_time[$b]) || ($a <=> $b) } (0 .. $#bin);
          push @{ $bin[$min] }, $job;
          $bin_time[$min] += $job->{time};
        }

      push @bins, map { [$h, $_] } grep { @$_ } @bin;
    }

  return @bins;
}

=pod

# Algorithm of `mitpack --maxjob N`

Goal: run the jobs of a test case in at most N Slurm jobs (wrappers `mit.*.sh`, each running some
`.cjob` one after the other), with elapsed times as balanced as possible.

1. Jobs are grouped by their `#SBATCH` directives (all except `--time`, `-o`, `-J`, `--job-name`);
   a wrapper only runs jobs of one group. If there are N jobs or less, they are submitted as is.
2. Each group gets one wrapper. If there are more groups than N, there are more wrappers than N.
3. The remaining wrappers (N minus the number of groups) are given one at a time to the group with
   the highest load per wrapper (total time of its jobs divided by its number of wrappers); a group
   never gets more wrappers than jobs.
4. In each group, jobs are packed with LPT (longest processing time): sorted by time, longest
   first, each job goes to the wrapper with the smallest total time so far.
5. A wrapper's `--time` is the sum of the times of its jobs, plus one minute per job.

`--maxtime` is not used when `--maxjob` is given.

Example: jobs A, B, C, D (10 minutes, 8 nodes) and E, F (20 minutes, 2 nodes), `--maxjob 4`: two
groups, two extra wrappers, one for each group (both have a load of 40 minutes); result: [A, B],
[C, D], [E], [F], about 20 minutes each.

=cut

1;

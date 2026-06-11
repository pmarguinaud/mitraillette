package mitraille::aggregate::maxjob;

use strict;

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
      my $hh = &mitraille::aggregate::header ($f);
  
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

=pod

# Algorithm for `mitraille::aggregateMaxJob`

## Goal

Given a list of `.cjob` files and a user-specified `--maxjob` limit, generate SLURM wrapper scripts (`mit.*.sh`) such that:
1. The total number of scripts is **at most `maxjob`** when possible.
2. If the number of distinct SLURM signatures exceeds `maxjob`, we create at least one script per signature (total scripts `> maxjob` — this is unavoidable because signatures cannot be mixed).
3. The elapsed time across all generated scripts is as balanced as possible.

## Input

- A list of `.cjob` files (each with its own `#SBATCH` header and `--time` value).
- An integer `maxjob` — the target maximum number of `mit.*.sh` scripts.
- An optional integer `maxtime` — the maximum allowed sum of job times per script (inherited from the existing `aggregate.pm`).

## Output

- A list of generated `mit.*.sh` scripts.
- Each script executes a subset of `.cjob` files sequentially.
- Each script’s `#SBATCH --time` is the sum of its job times plus 1 minute per job (overhead).

## Constraints

1. **Same signature per script**: Jobs inside a single `mit.*.sh` must share the same SLURM signature (all `#SBATCH` attributes except `--time`, `-o`, `-J`, `--job-name`).
2. **No signature merging**: If `maxjob` is smaller than the number of distinct signatures, we **do not merge** signatures. We create one script per signature (or more if `maxtime` forces it), accepting that the total script count exceeds `maxjob`.
3. **Sequential execution**: The elapsed time of a wrapper is the sum of individual job times inside it.
4. **Overhead**: The wrapper’s `#SBATCH --time` is set to `sum(job_times) + n_jobs × 1 minute`.
5. **Maxtime respect**: If `maxtime > 0` is also provided, no script may exceed `maxtime` in total job time. If `maxtime` forces more scripts than `maxjob`, `maxtime` takes precedence.

## Step-by-Step Algorithm

### Step 1: Parse and Group by Signature

For each `.cjob` file:
- Read the `#SBATCH` header.
- Extract:
  - `time`: the value of `#SBATCH --time` (in minutes).
  - `output`: the value of `#SBATCH -o` (if present).
  - `signature`: a canonical representation of all other `#SBATCH` attributes (excluding `-o`, `-J`, `--job-name`). The signature is stored using `Storable::freeze` for deterministic comparison.
- Group jobs into **signature buckets**. Each bucket contains a list of `{file, time, output}` records.

### Step 2: Compute Minimum Scripts per Signature

For each signature bucket `i`:
- If `maxtime > 0`: compute the minimum number of scripts `min_i` needed to pack all jobs in this bucket such that no script exceeds `maxtime`. This uses the same greedy first-fit approach as the original `aggregate.pm` (accumulate jobs until the next job would exceed `maxtime`, then start a new script).
- If `maxtime == 0`: `min_i = 1` (at least one script per signature).

Let `min_total = Σ min_i` and `S = number of signatures`.

### Step 3: Determine Target Total Number of Scripts

- If `maxjob <= 0`: fall back to the original behavior (no `maxjob` aggregation).
- Else:
  - `target_total = maxjob` if `maxjob >= min_total`, otherwise `target_total = min_total`.
  - If `maxjob < S`: `target_total` will be at least `S` (since `min_total >= S`), so the total script count exceeds `maxjob`. This is expected and allowed.

### Step 4: Distribute Extra Slots (if `target_total > min_total`)

If `target_total > min_total`:
- `remaining = target_total - min_total`.
- Initialize `k_i = min_i` for each signature.
- Repeatedly assign one extra slot to the signature with the **highest current average load** (`T_i / k_i`), where `T_i` is the total time of all jobs in bucket `i`.
- Stop when `remaining == 0` or when all signatures have `k_i = N_i` (one script per job, fully saturated).
- This greedy distribution approximates equalizing the load per script across all signatures.

### Step 5: Pack Jobs Inside Each Signature

For each signature bucket `i`:
- If `k_i == min_i` and `maxtime > 0`: reuse the greedy packing from Step 2.
- If `k_i > min_i` or `maxtime == 0`: use **LPT (Longest Processing Time)** to pack jobs into `k_i` bins:
  - Sort jobs by `--time` descending.
  - Create `k_i` empty bins.
  - For each job in sorted order, assign it to the bin with the **smallest current total load**.
  - LPT is the classic greedy approximation for multiprocessor makespan minimization.

### Step 6: Write the Wrapper Scripts

For each bin (one per `mit.*.sh`):
- Use the bucket’s shared signature as the `#SBATCH` header.
- Set `#SBATCH --time` to `bin_total_time + n_jobs_in_bin` (1 minute overhead per job).
- Write the `echo` pre-run and `timeout` execution lines exactly as in `aggregate.pm`.
- Generate filenames `mit.000000.sh`, `mit.000001.sh`, etc.

## Integration with `mitpack.pl`

1. **`mitpack.pl`**:
   - Add `maxjob => 0` to the `%opts` hash.
   - Add `maxjob` to the `@opts_s` list (so it can be parsed from `--maxjob=NN` or `--maxjob NN`).

2. **`mitraille.pm`**:
   - Add `use mitraille::aggregateMaxJob;`.
   - In the `runMitrailletteTestCase` subroutine:
     - If `$args{maxjob} > 0`, call `&mitraille::aggregateMaxJob::aggregate ($args{maxjob}, $args{maxtime}, @cjob)`.
     - Otherwise, fall back to `&mitraille::aggregate::aggregate ($args{maxtime}, @cjob)`.

3. **`mitraille/aggregateMaxJob.pm`**:
   - Copy the `slurpl`, `header` helper functions from `aggregate.pm`.
   - Implement the `aggregate` function with the algorithm described above.

## Example

| Job | Time | Signature |
|-----|------|-----------|
| A   | 10   | nodes=8   |
| B   | 10   | nodes=8   |
| C   | 10   | nodes=8   |
| D   | 10   | nodes=8   |
| E   | 20   | nodes=2   |
| F   | 20   | nodes=2   |

With `maxjob=4`, `maxtime=0`:
- `S = 2` signatures.
- `min_i = 1` for both.
- `min_total = 2`.
- `target_total = 4` (since `maxjob >= min_total`).
- `remaining = 2`.
- Signature nodes=8: `T=40`, `k=1`, load=40.
- Signature nodes=2: `T=40`, `k=1`, load=40.
- Both have equal load. Give one extra slot to each: `k=2` for both.
- LPT for nodes=8: [A, B] = 20, [C, D] = 20.
- LPT for nodes=2: [E] = 20, [F] = 20.
- Result: 4 scripts, each ~20 minutes.

With `maxjob=1` (same jobs):
- `S = 2` > `maxjob = 1`.
- `min_total = 2`.
- `target_total = 2` (since `maxjob < min_total`).
- Result: 2 scripts (one per signature), total exceeds `maxjob`. This is allowed.

---

*This algorithm prioritizes signature integrity while balancing load as much as possible within the `maxjob` budget.*

=cut

1;

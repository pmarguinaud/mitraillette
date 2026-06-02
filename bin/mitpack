#!/usr/bin/perl -w


=head1 NAME

mitpack

=head1 SYNOPSIS

  $ cd pack
  $ cd 49t1_tot2nvmassweno.03.IMPIIFC2018.x
  $ mitpack                                    #  Create a new MITRAILLETTE test case and run it
  $ mitpack --reuse                            #  Rerun last test case
  $ mitpack --dryrun                           #  Create last test case, but do not run tasks
  $ mitpack --status                           #  Show a small report on all tasks
  $ mitpack --status --reference /path/to/ref  #  Show a small report on all tasks, compare with a reference
  $ mitpack --cancel                           #  Cancel already submitted tasks
  $ mitpack --maxtime                          #  Submit jobs per groups of jobs, maxtime is the maximumu time of the group of jobs.

=head1 DESCRIPTION

Run MITRAILLETTE test suite from within a pack.

=head1 DETAILS

This script will : 

=over 4

=item 

Create the MITRAILLETTE test case; create a PRO_FILE, run mitraille.x, and remove dependencies
between individual tasks.

=item

Start the MITRAILLETTE test case (all tasks at once).

=back

Once the MITRAILLETTE tasks have ended, mitpack will provide a short report for each
of the tasks.

=head1 OPTIONS

=over 4

=item --dryrun

Create the test case, but do not start any task.

=item --reuse

Reuse the last test case.

=item --version

Provide MITRAILLETTE test version.

=item --status

Show the status for last test case.

=item --cancel

Cancel tasks (with scancel) for last test case.

=item --reference

Provide a reference for comparison; this may be the path of a MITRAILLETTE test case
of the path of a pack which will be searched for MITRAILLETTE test cases.

=back

=head1 CONFIGURATION & REQUIREMENTS

You need to install MITRAILLETTE in ~/mitraille. You also need to provide a 
PRO_FILE.version with the list of test you want to run for the version of tests.

=head1 CAVEATS

All tasks are submitted simultaneously. You may hit a limit on the number of jobs allowed
by the scheduler.

=head1 SEE ALSO

C<gmkpack>, C<mitraillette>

=head1 AUTHOR

pmarguinaud@hotmail.com

=cut

use FindBin qw ($Bin);
use lib "$Bin/../lib";

use File::Basename;
use Getopt::Long;
use File::stat;

use strict;

use bt;

use mitraille;

my $build = 'mitraille::build'->new ();
$build or die ("mitpack should be called either from a pack or from a cmake build");

my %opts = (version => $build->getVersion (), filter => '', maxtime => 0);
my @opts_f = qw (verbose help reuse dryrun status cancel list);
my @opts_s = qw (version filter maxtime);
my @opts_l = qw (reference);


sub help
{
  print "Usage: " . &basename ($0) . "\n" 
      . " Options:\n" . join ('', map { "   --$_\n" } @opts_f, @opts_s, @opts_l);
}

if (-f '.mitpack.conf')
  {
    unshift (@ARGV, @{ do './.mitpack.conf' });
  }

if ($opts{reference})
  {
    $opts{reference} = [$opts{reference}];
  }

&GetOptions
(
  (map { ($_, \$opts{$_}) } @opts_f),
  (map { ("$_=s", \$opts{$_}) } @opts_s),
  (map { ("$_=s@", \$opts{$_}) } @opts_l),
);

if ($opts{help})
  {
    &help (); 
    exit (0);
  }

my $mitraillette;

$opts{reuse} ||= $opts{status};
$opts{reuse} ||= $opts{cancel};
$opts{reuse} ||= $opts{list};

if ($opts{reference})
  {
    for (@{ $opts{reference} })
      {
        $_ = 'File::Spec'->rel2abs ($_);
      }
    ($opts{reference1}, $opts{reference2}) = @{ $opts{reference} };
  }

$opts{filter} = [split (m/,/o, $opts{filter})];


if ($opts{reuse})
  {
    $mitraillette = &mitraille::getLastMitraillette (build => $build);
    die ("Could not found last mitraillette directory\n")
      unless ($mitraillette);
  }
else
  {
    die ("No version of tests was found\n") 
      unless ($opts{version});
    $mitraillette = &mitraille::createMitrailletteTestCase (build => $build, %opts);
    my $local = $build->getPath () . '/' . &basename ($mitraillette);
    symlink ($mitraillette, $local);
    &mitraille::swapLink ($local);
  }

if ($opts{list})
  {
    &mitraille::listTestCases (mitraillette => $mitraillette, build => $build, %opts);
  }
elsif ($opts{status})
  {
    &mitraille::showStatus (mitraillette => $mitraillette, build => $build, %opts);
  }
elsif ($opts{cancel})
  {
    &mitraille::cancelMitraillette (mitraillette => $mitraillette, %opts);
  }
elsif (! $opts{dryrun})
  {
    &mitraille::runMitrailletteTestCase (mitraillette => $mitraillette, %opts);
  }




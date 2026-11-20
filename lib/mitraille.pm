package mitraille;

use Cwd;
use FileHandle;
use File::Path;
use File::Spec;
use File::Basename;
use Data::Dumper;

use strict;

use mitraille::aggregate;
use mitraille::build;
use mitraille::node;
use mitraille::printer::terminal;
use mitraille::generate;
use mitraille::util qw (slurp);

sub runCommand
{
  my %args = @_;
  my @cmd = @{ ${args}{command} };

  print "@cmd\n" if ($args{verbose});

  if ($args{stdout})
    {
      my $out = `@cmd`;
      my $c = $?;
      $c && goto ERROR;
      return $out;
    }
  else
    {
      system (@cmd) 
        and goto ERROR;
    }

  return;

ERROR:
  die ("Command `@cmd' failed\n");
}

# The directory is on a file system shared between nodes

sub isShared
{
  my $dir = shift;
  chomp (my $type = `stat -f -c %T $dir 2>/dev/null`);
  return grep { $type eq $_ } qw (nfs nfs4 lustre gpfs);
}

# Numbers of the test cases (mitraille_NNNN) in a directory

sub testCaseNumbers
{
  my $dir = shift;
  return map { m/mitraille_(\d+)$/o ? ($1) : () } <$dir/mitraille_*>;
}

# Create the directory of a new test case: in the build directory if it is
# shared between nodes; otherwise (eg /tmp of a node) in $MITPACK_DIR, or in
# $MIT_INSTALL_DIR/<version>, with a link in the build directory

sub newTestCaseDirectory
{
  my %args = @_;

  my $path = $args{build}->getPath ();

  my $root = &isShared ($path) 
           ? $path 
           : ($ENV{MITPACK_DIR} || "$ENV{MIT_INSTALL_DIR}/" . lc ($args{version}));

  &mkpath ($root) unless (-d $root);

  my ($n) = sort { $b <=> $a } (0, &testCaseNumbers ($root), &testCaseNumbers ($path));

# mkdir fails if the directory exists, eg created by another mitpack

  my $dir;
  while (1)
    {
      $dir = sprintf ("%s/mitraille_%4.4d", $root, ++$n);
      last if (mkdir ($dir));
      die ("Cannot create `$dir': $!\n") unless (-e $dir);
    }

  symlink ($dir, "$path/" . &basename ($dir))
    or die ("Cannot create link to `$dir' in `$path'\n") 
    unless ($root eq $path);

  return $dir;
}

sub getProFile
{
  my %args = @_;
  my $pro_file = "$ENV{MIT_INSTALL_DIR}/PRO_FILE.$args{version}";
  return $pro_file;
}

sub createMitrailletteTestCase
{
  my %args = @_;

  my $build = $args{build};

  my $pro_file = &getProFile (build => $build, %args);

  my $mitraillette = &newTestCaseDirectory (%args);

  &mitraille::generate::run
  (
    build           => $build->getInstallPath (),
    cycle           => $args{version},
    pro_file        => $pro_file,
    save            => $args{save},
    job_dir         => $mitraillette,
  );
  
  'FileHandle'->new (">$mitraillette/VERSION")->print ("$args{version}\n");

  return $mitraillette;
}

sub submitJob
{
  my %args = @_;
  my $job = $args{job};
# When submitting from within a Slurm job, sbatch would pass the CPU mask of
# this job to the new job; srun then fails in jobs using part of a node
  local %ENV = %ENV;
  delete @ENV{grep { m/^SLURM_CPU_BIND/o } keys (%ENV)};
  my $out = &runCommand (%args, stdout => 1, command => ['sbatch', $job]);
  my ($id) = ($out =~ m/Submitted batch job (\d+)/o);
  'FileHandle'->new (">$job.id")->print ("$id\n");
  return $id;
}

sub cancelJob
{
  my %args = @_;
  my $job = $args{job};
  return unless (-f "$job.id");
  chomp (my $id = &slurp ("$job.id")); 
  &runCommand (%args, command => ['scancel', $id]);
  unlink ("$job.id");
  return $id;
}

sub cancelMitraillette
{
  my %args = @_;

  my $mitraillette = $args{mitraillette};

  chdir ($mitraillette);

  for my $jobid (<*.id>)
    {
      (my $job = $jobid) =~ s/\.id$//o;
      &cancelJob (%args, job => $job);
    }

}

sub runMitrailletteTestCase
{
  my %args = @_;

  my $mitraillette = $args{mitraillette};

  chdir ($mitraillette);

  &mkpath ('old');

  if (my @o = <*.o*>)
    {
      rename ($_, "old/$_") for (@o);
    }

  my @cjob = grep 
  {
    my $cjob = $_;
    my $ok = 1;
    if (my @filter = @{ $args{filter} })
      {
        $ok = 0;
        for (@filter)
          {
            $ok ||= ($cjob =~ m/$_/);
          }
      }
    $ok
  } <*.cjob>;

  my @sh = &mitraille::aggregate::aggregate (\%args, @cjob);

  for my $sh (@sh)
    {
      &submitJob (%args, job => $sh);
    }

}

# Job status: the first failure found in the job output (earliest in the text),
# otherwise COMPLETED if the job ran to its end, otherwise UNKNOWN

my $FAIL = 'black on_red';

my @STATUS =
(
# Message in the output                                                         Status              Color
  [qr/OUT_OF_MEMORY/,                                                           'OOM',              $FAIL],
  [qr/Command exited with non-zero status/,                                     'non-zero status',  $FAIL],
  [qr/Process received signal/,                                                 'signalled',        $FAIL],
  [qr/mpirun detected that one or more processes exited with non-zero status/,  'non-zero status',  $FAIL],
  [qr/ABOR1/,                                                                   'ABOR1',            $FAIL],
  [qr/ABORT!/,                                                                  'ABORT!',           $FAIL],
  [qr/FAILED at line/,                                                          'FAILED',           $FAIL],
  [qr/SIGSEGV/,                                                                 'SIGSEGV',          $FAIL],
  [qr/CANCELLED/,                                                               'CANCELLED',        $FAIL],
  [qr/forrtl: severe/,                                                          'forrtl: severe',   $FAIL],
  [qr/BAD TERMINATION/,                                                         'BAD TERMINATION',  $FAIL],
  [qr/SPECTRAL NORMS[^\n]*NaN/,                                                 'NaN',              $FAIL],
  [qr/Cannot access ..\/(?:MASTERODB|ARPEXE)./s,                                'Missing',          $FAIL],
);

my %COLOR = ((map { ($_->[1], $_->[2]) } @STATUS), COMPLETED => 'green', UNKNOWN => 'yellow');

# Each message is searched separately: a single alternation of all of them is
# about 50 times slower on large outputs, because it disables the fast substring
# search of the regex engine

sub jobStatus
{
  my $text = shift;

  my ($status, $pos);

  for my $s (@STATUS)
    {
      next unless ($text =~ $s->[0]);
      ($status, $pos) = ($s->[1], $-[0]) if ((! defined ($pos)) || ($-[0] < $pos));
    }

  return $status if (defined ($status));

  return $text =~ m/COMPLETED/o ? 'COMPLETED' : 'UNKNOWN';
}

sub jobInfo
{
  my $o = shift;
  my %args = @_;

  # Listing of Davai: the task succeeded, or it would not have been imported

  return {status => 'COMPLETED', CNMEXPL => $1} if ($o =~ m,/([^/]+)/ref/NODE\.001_01$,o);

  my $text = &slurp ($o);

  my ($CNMEXPL) = ($text =~ m/CNMEXPL=(\w+)/goms);
  $CNMEXPL or return {status => 'UNKNOWN', CNMEXPL => '?'};

  my $status = &jobStatus ($text);

  my %h;

  if (scalar (@{ $args{fields} }))
    {
      %h = ($text =~ m/([A-Z]\w*)\s*=\s*(\S+)/igoms);
     
      for (values (%h))
        {
          s/,$//o;
        }
    }

  $h{status} = $status;
  $h{CNMEXPL} = $CNMEXPL;

  return \%h;
}

sub getColorStatus
{
  my $text = shift;
  (my $status = $text) =~ s/(?:^\s*|\s*$)//go;
  return $COLOR{$status};
}

sub listTestCases
{
  my %args = @_;

  (my $build = $args{build}) or die;

  my $mitraillette = $args{mitraillette};

  $mitraillette or die;
  chdir ($mitraillette) or die;

  for my $cjob (<*.cjob>)
    {
      print &basename ($cjob, qw (.cjob)), "\n";
    }

}

sub getReferenceMitraillette
{
  my %args = @_;

  return unless (my $reference = $args{reference});

  my $mitraillette1;

  if ($reference)
    {
      if (my $build1 = 'mitraille::build'->new (path => $reference))
        {
          ($mitraillette1) = &getLastMitraillette (build => $build1);
          $mitraillette1 or die;
        }
      elsif (my ($cjob) = <$reference/*.cjob>)
        {
          $mitraillette1 = $reference;
        }
      elsif (&isDavaiData ($reference))
        {
          $mitraillette1 = $reference;
        }
      else
        {
          die;
        }
    }

  return $mitraillette1;
}

# Data of a Davai experiment imported by davimport: <test>/ref/NODE.001_01 are
# the listings of Davai, and are used as the outputs of a reference

sub isDavaiData
{
  my $dir = shift;
  my @node = <$dir/*/ref/NODE.001_01>;
  return (-f "$dir/TAG") && @node;
}

sub getStatusOutputs
{
  my $mitraillette = shift;

  if ($mitraillette && &isDavaiData ($mitraillette))
    {
      return map { m,/([^/]+)/ref/NODE\.001_01$,o ? ("O$1", $_) : () } <$mitraillette/*/ref/NODE.001_01>;
    }

  my %o = $mitraillette ? map 
  { 
    my $o = $_;  
    $_ = &basename ($_);
    s/\.o\d+$//o;
    ($_, $o) 
  } <$mitraillette/*.o*> : ();

  return %o;
}

sub showStatus
{
  my %args = @_;

  (my $build = $args{build}) or die;

  my $mitraillette0 = $args{mitraillette};

  my $mitraillette1 = &getReferenceMitraillette (%args, reference => $args{reference1});
  my $mitraillette2 = &getReferenceMitraillette (%args, reference => $args{reference2});

  $mitraillette0 or die;

  my %o0 = &getStatusOutputs ($mitraillette0);
  my %o1 = &getStatusOutputs ($mitraillette1);
  my %o2 = &getStatusOutputs ($mitraillette2);

  my $len = 0;
  for my $o (sort keys (%o0))
    {
      $len = length ($o) > $len ? length ($o) : $len;
    }

  my @R = ('RUN');

  if ($mitraillette1 && $mitraillette2)
    {
      push @R, 'REF1', 'REF2';
    }
  elsif ($mitraillette1)
    {
      push @R, 'REF';
    }

  printf ("%-6s = %s\n", $R[0], $mitraillette0);
  printf ("%-6s = %s\n", $R[1], $mitraillette1) if ($mitraillette1);
  printf ("%-6s = %s\n", $R[2], $mitraillette2) if ($mitraillette2);

  my @length = ($len);
  my @justify = ('left');
  
  for my $R (@R)
    {
      push @length, 20;
      push @justify, 'center';
    }

  if (my @f = @{ $args{fields} })
    {
      push @length, (10) x scalar (@f);
      push @justify, ('center') x scalar (@f);
    }

  if ($mitraillette1 && $mitraillette2)
    {
      # STATUS
      push @length, 12;
      push @justify, 'center';
      my @F = 'mitraille::node'->fields ();
      push @length, (11) x scalar (@F);
      push @justify, ('center') x scalar (@F);
    }

  my $printer = 'mitraille::printer::terminal'->new 
  (
    color => 1, justify => \@justify, 
    length => \@length, interval => 5,
  );


  my @head = ('TEST CASE');

  for my $R (@R)
    {
      push @head, $R;
    }

  if (my @f = @{ $args{fields} })
    {
      push @head, @f;
    }

  if ($mitraillette1 && $mitraillette2)
    {
      push @head, 'STATUS';
      my @F = 'mitraille::node'->fields ();
      for my $F (@F)
        {
          push @head, $F;
        }
    }

  $printer->line (@head);

  my @O = sort keys (%o0);

  MAIN : for my $i (0 .. $#O)
    {
      my @line;

      my $O = $O[$i];
      my $o0 = $o0{$O};
      my $o1 = $o1{$O};
      my $o2 = $o2{$O};

      my $info0 = $o0 && &jobInfo ($o0, %args);
      my $info1 = $o1 && &jobInfo ($o1, %args);
      my $info2 = $o2 && &jobInfo ($o2, %args);

      push @line, $O;

      my $txtmess = '';
      my $colmess = '';

      my @info = ($info0);
      push @info, $info1 if ($mitraillette1);
      push @info, $info2 if ($mitraillette2);

      for my $info (@info)
        {
          push @line, $info ? ('<' . &getColorStatus ($info->{status}) . '>', $info->{status}) : ('');
        }

      for my $f (@{ $args{fields} })
        {
          push @line, defined ($info0->{$f}) ? $info0->{$f} : '';
        }

      if ($o1 && $o2 && ! grep ({ $_->{status} ne 'COMPLETED' } ($info0, $info1, $info2)))
        {
          my $diff01 = &mitraille::node::compare ($o0, $o1);
          my $diff21 = &mitraille::node::compare ($o2, $o1);

          if ($diff01->{struct} || $diff21->{struct})
            {
              push @line, '<red on_black>', 'DIFF-STRUCT';
            }
          elsif ($diff01->{diff})
            {
              my @txtmess;
              $colmess = '';
              for my $i (0 .. $#{ $diff01->{digits} })
                {
                  my $d01 = $diff01->{digits}[$i];
                  my $d21 = $diff21->{diff} ? $diff21->{digits}[$i] : '  inf';
                  push @txtmess, "$d01 $d21";
                  $colmess = 'red on_black' if ((! $diff21->{diff}) || ($d01 < $d21));
                }
              push @line, "<$colmess>", "DIFF\@$diff01->{step}", map { ("<$colmess>", $_) } @txtmess;
            }

        }
      elsif ($o1 && ! grep ({ $_->{status} ne 'COMPLETED' } ($info0, $info1)))
        {
          my $diff01 = &mitraille::node::compare ($o0, $o1);
          if ($diff01->{struct})
            {
              push @line, '<red on_black>', 'DIFF-STRUCT';
            }
          elsif ($diff01->{diff})
            {
              push @line, '<red on_black>', "DIFF\@$diff01->{step}";
            }
        }
      elsif ($o1 && ($info0->{status} ne 'UNKNOWN') && ($info0->{status} ne $info1->{status}))
        {
          $txtmess = 'DIFF';
          $colmess = 'red on_black';

          push @line, "<$colmess>", $txtmess;
        }

      $printer->line (@line);

    }

}

sub getLastMitraillette
{
  my %args = @_;

  (my $build = $args{build}) or die;

  my $path = $build->getPath ();

  my ($n) = sort { $b <=> $a } grep { -d sprintf ("%s/mitraille_%4.4d", $path, $_) } &testCaseNumbers ($path);

  return defined ($n) ? sprintf ("%s/mitraille_%4.4d", $path, $n) : undef;
}


1;

package mitraille;

use Cwd;
use FileHandle;
use File::Path;
use File::Spec;
use File::Basename;
use Data::Dumper;
use File::stat;

use strict;

use mitraille::aggregate;
use mitraille::build;
use mitraille::node;
use mitraille::printer::terminal;
use mitraille::generate;

sub center
{
  my ($s, $n) = @_; 
  my $i = 0;
  while (length ($s) < $n) 
    {   
      $s = $i % 2 ? " $s" : "$s ";
      $i++;
    }   
  return $s; 
}

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

sub swapLink
{
  my $f = shift;
  return unless (-l $f);

  $f = 'File::Spec'->rel2abs ($f);

  my $g = readlink ($f);

  my $stf = stat (&dirname ($f));
  my $stg = stat (&dirname ($g));

  return unless ($stf->dev == $stg->dev);

  unlink ($f);
  rename ($g, $f);
  symlink ($f, $g);
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

  chdir ($ENV{MIT_INSTALL_DIR});
  
  my $dir = lc ($args{version});
  
  &mkpath ($dir) unless (-d $dir);
  
  my @test0 = map { &basename ($_) } <$dir/*>;
  my %test0 = map { ($_, 1) } @test0;
  
  &mitraille::generate::run
  (
    build           => $build->getInstallPath (),
    cycle           => $args{version},
    pro_file        => $pro_file,
  );
  
  my @test1 = map { &basename ($_) } <$dir/*>;
  my ($mitraillette) = grep { ! $test0{$_} } @test1;
  
  $mitraillette = "$ENV{MIT_INSTALL_DIR}/$dir/$mitraillette";
  
  my @cjob = sort <$mitraillette/*.cjob>;

  for my $cjob (@cjob)
    {
      &patchCJob (cjob => $cjob, build => $build);
    }

  'FileHandle'->new (">$mitraillette/VERSION")->print ("$args{version}\n");

  return $mitraillette;
}

sub patchCJob
{
  my %args = @_;

  my ($build, $cjob) = @args{qw (build cjob)};
  
  my $install = $build->getInstallPath ();

  my @text = do { my $fh = 'FileHandle'->new ("<$cjob"); <$fh> };

  for (@text)
    {
     if (/test\.x\d+/o)
       {
         $_ = "\n";
       }
    }

  'FileHandle'->new (">$cjob")->print (join ('', @text));
}

sub submitJob
{
  my %args = @_;
  my $job = $args{job};
  my $out = &runCommand (%args, stdout => 1, command => ['sbatch', $job]);
  my ($id) = ($out =~ m/Submitted batch job (\d+)/o);
  'FileHandle'->new (">$job.id")->print ("$id\n");
  return $id;
}

sub slurp
{
  my $f = shift;
  (my $fh = 'FileHandle'->new ("<$f")) or die ("Cannot open `$f'");
  local $/ =  undef; 
  my $text = <$fh>;
  return $text;
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


  my @sh = &mitraille::aggregate::aggregate ($args{maxtime}, @cjob);

  for my $sh (@sh)
    {
      &submitJob (%args, job => $sh);
    }

}

sub jobInfo
{
  my $o = shift;

  my $text = &slurp ($o);

  my $ABORTED = << 'EOF';

#########################################
#        BULL - METEO-FRANCE            #
#        Job Accounting                 #
#########################################
EOF

  if (substr ($text, 0, length ($ABORTED)) eq $ABORTED)
    {
      unlink ($o);
      return;
    }

  my ($CNMEXPL) = ($text =~ m/CNMEXPL=(\w+)/goms);
  $CNMEXPL or return {status => 'UNKNOWN', CNMEXPL => '?'};

  my ($status) = ($text =~ m/(Command exited with non-zero status|Process received signal|mpirun detected that one or more processes exited with non-zero status|ABOR1|ABORT!|FAILED|SIGSEGV|CANCELLED|forrtl: severe|BAD TERMINATION|SPECTRAL NORMS[^\n]*NaN|Cannot access ..\/(?:MASTERODB|ARPEXE).)/goms);

  $status =~ s/^forrtl:.*SIGSEGV/SIGSEGV/o if ($status);
  $status = 'NaN' if ($status && ($status =~ m/NaN/o));
  $status = 'Missing' if ($status && ($status =~ m/Cannot access/o));
  $status = 'non-zero status' if ($status && ($status =~ m/^mpirun detected/o));
  $status = 'non-zero status' if ($status && ($status =~ m/^Command exited with non-zero status/o));
  $status = 'signalled' if ($status && ($status =~ m/^Process received signal/o));
  

  $status = substr ($status, 0, 20) if ($status);

  unless ($status)
    {
      ($status) = ($text =~ m/(COMPLETED)/goms);
    }

  $status ||= 'UNKNOWN';

  if ($status eq 'UNKNOWN')
    {
      if ($text =~ m/sacct -j/o)
        {
#         $status = 'COMPLETE';
        }
    }

  return {status => $status, CNMEXPL => $CNMEXPL};
}

sub getColorStatus
{
  my $text = shift;
  (my $status = $text) =~ s/(?:^\s*|\s*$)//go;

  my %color = 
  (
    FAILED            => 'black on_red',
    ABOR1             => 'black on_red',
    COMPLETED         => 'green',
    'forrtl: severe'  => 'black on_red',
    SIGSEGV           => 'black on_red',
    UNKNOWN           => 'yellow',
    CANCELLED         => 'black on_red',
    'BAD TERMINATION' => 'black on_red',
    NaN               => 'black on_red',
    Missing           => 'black on_red',
    'non-zero status' => 'black on_red',
    'ABORT!'          => 'black on_red',
    signalled         => 'black on_red',
  );

  return $color{$status};
}

sub colorStatus
{
  my $text = shift;
  &colorMessage (&getColorStatus ($text), $text);
}

sub colorMessage
{
  my ($color, $text) = @_;
  if ((-t STDOUT) && $color)
    {
      return &colored ([$color], $text);
    }
  else
    {
      return $text;
    }
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
      else
        {
          die;
        }
    }

  return $mitraillette1;
}

sub getStatusOutputs
{
  my $mitraillette = shift;

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

  if ($mitraillette1 && $mitraillette2)
    {
      # STATUS
      push @length, 10;
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

      my $info0 = $o0 && &jobInfo ($o0);
      my $info1 = $o1 && &jobInfo ($o1);
      my $info2 = $o2 && &jobInfo ($o2);

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

      if ($o1 && $o2 && ! grep ({ $_->{status} ne 'COMPLETED' } ($info0, $info1, $info2)))
        {
          my @txtmess;

          my @diff01 = &mitraille::node::diff ($o0, $o1);
          my @diff21 = &mitraille::node::diff ($o2, $o1);

          if (@diff01 && @diff21)
            {
              for my $i (0 .. $#diff01)
                {
                  push @txtmess, "$diff01[$i] $diff21[$i]";
                  $colmess = 'red on_black' if ($diff01[$i] < $diff21[$i]);
                }
            }
          elsif (@diff01)
            {
              for my $i (0 .. $#diff01)
                {
                  push @txtmess, "$diff01[$i]   inf";
                  $colmess = 'red on_black';
                }
            }
          
          $txtmess = "DIFF[" . join ("|", @txtmess) . "]" if (@txtmess);

          if (@txtmess)
            {
              push @line, "<$colmess>", 'DIFF', map { ("<$colmess>", $_) } @txtmess;
            }

        }
      elsif ($o1 && ! grep ({ $_->{status} ne 'COMPLETED' } ($info0, $info1)))
        {
          my @diff01 = &mitraille::node::diff ($o0, $o1);
          if (@diff01)
            {
              $txtmess = 'DIFF';
              $colmess = 'red on_black';
            }

          if ($txtmess)
            {
              push @line, "<$colmess>", $txtmess;
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

sub statusEquiv
{
  my ($status1, $status2) = @_;
  return (($status1 eq 'COMPLETED') == ($status2 eq 'COMPLETED')) || ($status1 eq 'UNKNOWN') || ($status2 eq 'UNKNOWN');
}

sub getLastMitraillette
{
  my %args = @_;

  (my $build = $args{build}) or die;

  my $path = $build->getPath ();

  my @mitraillette = sort grep { -d && m/mitraille_\d\d\d\d$/o } <$path/mitraille_????>;

  return pop (@mitraillette);
}


1;

package mitraille;

use strict;

use Cwd qw (cwd);
use File::Basename;
use File::Spec;
use FileHandle;
use Data::Dumper;

use base qw (Exporter);

our @EXPORT_OK = qw (run);

sub read_file
{
  my ($file) = @_;
  (my $fh = 'FileHandle'->new ("<$file"))
    or die ("Cannot open `$file'");
  local $/ = undef;
  my $content = <$fh>;
  $fh->close ();
  return $content;
}

sub getjob
{
  my %args = @_;
  my $job_name = $args{job_name};
  if (-f "$args{mitra_home}/$args{cycle_lc}/$job_name")
    {
      return "$args{mitra_home}/$args{cycle_lc}/$job_name";
    }
  else
    {
      return "$args{ref_jobsdir}/$job_name";
    }
}

sub getprofil
{
  my %args = @_;
  my $job_name = $args{job_name};
  $job_name =~ s/\.pjob$//o;
  my $profil_table = $args{profil_table};

  my @h = @{ $profil_table->{header} };

  my @c;

  if (exists ($profil_table->{$job_name}))
    {
      @c = @{ $profil_table->{$job_name} };
    }
  # Fallback: use endjob profile or defaults
  elsif (exists ($profil_table->{"endjob"}))
    {
      @c = @{ $profil_table->{"endjob"} };
    }
  else
    {
die;
      @c = (10, 0, 1, 1, 128);
    }

  my %p = map { ($h[$_], $c[$_]) } (0 .. $#h);

  return \%p;
}

sub set_job
{
  my %args = @_;

  my $job_name = $args{job_name};
  my $code_name = $args{code_name};
  my $build = $args{build} // '';

  my $JOB = &getjob (%args);

  my $content = &read_file ($JOB);

  my ($prof, $time) = ($content =~ m/PROFILE\s*=\s*(\S+)\s*,\s*TIME\s*=\s*(\d+)m?/goms);

  if ($prof && $time)
    {
      $prof = &getprofil (%args, job_name => $prof);
      $prof->{walltime} = $time;
    }
  else
    {
      die $job_name;
    }

  my $NBNODES = $prof->{nnode_fc} + $prof->{nnode_io};

  my $cjob_file = "$args{job_dir}/${code_name}.cjob";
  $content = &read_file ("$args{ref_jobsdir}/$args{station}/multiheader")
           . "export STATION=$args{station}\n"
           . &read_file ("$args{ref_jobsdir}/$args{station}/config_$args{cycle}")
           . $content
           . &read_file ("$args{ref_jobsdir}/$args{station}/jobtrailer");

  my $nam_path_plain = "$args{ref_namdir}/$args{cycle_lc}";
  my $mitra_home_plain = $args{mitra_home};
  my $mit_install_dir = $args{mit_install_dir} // '';

  for ($content)
    {
      s/__jobname__/O${code_name}/go;

      s/__nb_nodes__/${NBNODES}/go;

      s/__nnode_fc__/$prof->{nnode_fc}/go;
      s/__ntask_fc__/$prof->{ntask_fc}/go;
      s/__nopmp_fc__/$prof->{nopmp_fc}/go;

      s/__nnode_io__/$prof->{nnode_io}/go;
      s/__ntask_io__/$prof->{ntask_io}/go;
      s/__nopmp_io__/$prof->{nopmp_io}/go;

      s/__job_walltime__/$prof->{walltime}/go;
      s/__v_cycle__/$args{cycle}/go;
      s/__my_own_pack__/${build}/go;
      s/__nam_path__/${nam_path_plain}/go;
      s/__mitra_pid__/$args{mitra_pid}/go;
      s/__mitra_home__/${mitra_home_plain}/go;
      s/__mit_install_dir__/${mit_install_dir}/go;
    }

  (my $cj = 'FileHandle'->new (">$cjob_file"))
    or die ("Cannot write `$cjob_file'");
  $cj->print ($content);
  $cj->close ();
}

#---------------------------------------------------------------------------------------------------------
# Main entry point
#---------------------------------------------------------------------------------------------------------

sub run
{
  my %args = @_;

  $args{mitra_home} = cwd ();
  $args{ref_jobsdir} = "$args{mit_install_dir}/protojobs";
  $args{ref_namdir} = "$args{mit_install_dir}/namelist";
  $args{cycle_lc} = lc ($args{cycle});
  $args{local_dir} = cwd ();

  #---------------------------------------------------------------------------------------------------------
  # 1. MITRA_PID handling (read ~/.mitrc, increment, etc.)
  #---------------------------------------------------------------------------------------------------------

  my $mitra_pid;
  my $mitra_pid1;
  my $mitra_namdir = '';

  my $mitrc = "$ENV{HOME}/.mitrc";
  if (! -f $mitrc)
    {
      (my $mf = 'FileHandle'->new (">$mitrc"))
        or die ("Cannot create `$mitrc'");
      $mf->print (<<'BASTA');
# the next chain ID
MITRA_PID=0002

BASTA
      $mf->close ();
      $mitra_pid = 1;
    }
  else
    {
      (my $mf = 'FileHandle'->new ("<$mitrc"))
        or die ("Cannot open `$mitrc'");
      local $/ = undef;
      my $mitrc_content = <$mf>;
      $mf->close ();

      if ($mitrc_content =~ /MITRA_PID\s*=\s*(\d+)/)
        {
          $mitra_pid = $1 + 0;
        }
      if ($mitrc_content =~ /MITRA_NAMDIR\s*=\s*(.+)/)
        {
          $mitra_namdir = $1;
          $mitra_namdir =~ s/^"//;
          $mitra_namdir =~ s/"$//;
        }

      if (! defined $mitra_pid)
        {
          die ("MITRA_PID variable is missing in \$HOME/.mitrc\n");
        }
      if ($mitra_pid <= 9999)
        {
          $mitra_pid1 = $mitra_pid + 1;
        }
      else
        {
          $mitra_pid1 = 1;
        }
      $mitrc_content =~ s/MITRA_PID\s*=\s*\d+/MITRA_PID=${mitra_pid1}/;
      (my $mf2 = 'FileHandle'->new (">$mitrc"))
        or die ("Cannot write `$mitrc'");
      $mf2->print ($mitrc_content);
      $mf2->close ();
    }

  $args{mitra_pid} = sprintf ("%04d", $mitra_pid);
  $args{ref_namdir} = $mitra_namdir if ($mitra_namdir);

  #---------------------------------------------------------------------------------------------------------
  # 2. Arguments tests
  #---------------------------------------------------------------------------------------------------------

  if (! $args{cycle})
    {
      die ("CYCLE must be provided\n");
    }
  if (! $args{pro_file})
    {
      die ("PRO_FILE must be provided\n");
    }
  if ($args{local_dir} ne $args{mitra_home})
    {
      die ("Please run from \$MITRA_HOME ($args{mitra_home}), not $args{local_dir}\n");
    }
  if (! -d "$args{local_dir}/$args{cycle_lc}")
    {
      die ("Cycle directory does not exist: $args{local_dir}/$args{cycle_lc}\n");
    }
  if (! -f $args{pro_file})
    {
      die ("PRO_FILE does not exist: $args{pro_file}\n");
    }

  #---------------------------------------------------------------------------------------------------------
  # 3. Read profil_table into a hash
  #---------------------------------------------------------------------------------------------------------

  my %PROFIL_TABLE;
  my $profil_file = "$args{ref_jobsdir}/$args{station}/profil_table.csv";
  (my $pf = 'FileHandle'->new ("<$profil_file"))
    or die ("Cannot open `$profil_file'");

  chomp (my $h = <$pf>);

  for ($h)
    {
      s/^\s*//o; s/;\s*$//o; s/\s*$//o;
    }

  my @h = split (m/\s*;\s*/o, $h);

  $PROFIL_TABLE{header} = \@h;

  while (my $line = <$pf>)
    {
      chomp ($line);

      for ($line)
        {
          s/^\s*//o; s/;\s*$//o; s/\s*$//o; 
        }

      my @c = split (m/\s*;\s*/o, $line);
      for (@c)
        {
          s/^0+//o; $_ ||= 0;
        }
      $PROFIL_TABLE{$c[0]} = \@c;
    }
  $pf->close ();

  $args{profil_table} = \%PROFIL_TABLE;

  #---------------------------------------------------------------------------------------------------------
  # 4. Initialisations
  #---------------------------------------------------------------------------------------------------------

  $args{job_dir} = "$args{mitra_home}/$args{cycle_lc}/mitraille_$args{mitra_pid}";

  mkdir ($args{job_dir}) if (! -d $args{job_dir});

  #---------------------------------------------------------------------------------------------------------
  # 5. Process PRO_FILE and generate jobs
  #---------------------------------------------------------------------------------------------------------

  (my $proffh = 'FileHandle'->new ("<$args{mitra_home}/$args{pro_file}"))
    or die ("Cannot open `$args{mitra_home}/$args{pro_file}'");
  while (<$proffh>)
    {
      chomp;
      s/\t/ /go;
      s/^\s+//o;
      s/\s+$//o;
      next if (/^#/o || /^\s*$/o);

      my $CODE_JOB = $_;

      &set_job (%args, job_name => "${CODE_JOB}.pjob", code_name => $CODE_JOB);
    }
  $proffh->close ();
}

1;

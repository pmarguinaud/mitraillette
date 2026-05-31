package MITRAILLE;

use strict;

use Cwd qw(cwd);
use File::Basename;
use File::Spec;
use FileHandle;

use base qw (Exporter);

our @EXPORT_OK = qw (run);

#---------------------------------------------------------------------------------------------------------
# Helper functions
#---------------------------------------------------------------------------------------------------------

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
  my $profil_table = $args{profil_table};
  if (exists $profil_table->{$job_name})
    {
      return @{ $profil_table->{$job_name} };
    }
  # Fallback: use endjob profile or defaults
  if (exists $profil_table->{"endjob"})
    {
      return @{ $profil_table->{"endjob"} };
    }
  return (10, 0, 1, 1, 128);
}

sub set_job
{
  my %args = @_;

  my $job_name = $args{job_name};
  my $code_name = $args{code_name};
  my $build = $args{build} // '';

  my $JOB = &getjob (%args);
  my ($job_walltime, $job_nproc_io, $job_ntasks_tot, $job_nnode, $job_nthreads) = &getprofil (%args);

  my $NPROC_IO = int ($job_nproc_io);
  my $NTASKS_TOT = int ($job_ntasks_tot);
  my $NBNODES = int ($job_nnode);
  my $NBTHREADS = int ($job_nthreads);
  my $NTASKS = $NTASKS_TOT - $NPROC_IO;
  my $NTASKS_BY_NODE = ($NBNODES > 0) ? int ($NTASKS_TOT / $NBNODES) : $NTASKS_TOT;

  my $cjob_file = "$args{job_dir}/${code_name}.cjob";
  my $content = '';
  $content .= &read_file ("$args{ref_jobsdir}/$args{station}/multiheader");
  $content .= "export STATION=$args{station}\n";
  $content .= &read_file ("$args{ref_jobsdir}/$args{station}/config_$args{cycle}");
  $content .= &read_file ($JOB);
  $content .= &read_file ("$args{ref_jobsdir}/$args{station}/jobtrailer");

  my $nam_path_plain = "$args{ref_namdir}/$args{cycle_lc}";
  my $mitra_home_plain = $args{mitra_home};
  my $mit_install_dir = $args{mit_install_dir} // '';


  for ($content)
    {
      s/__jobname__/O${code_name}/go;
      s/__ntasks_tot__/${NTASKS_TOT}/go;
      s/__ntasks__/${NTASKS}/go;
      s/__nb_proc_io__/${NPROC_IO}/go;
      s/__nb_nodes__/${NBNODES}/go;
      s/__ntasks_by_node__/${NTASKS_BY_NODE}/go;
      s/__nb_threads__/${NBTHREADS}/go;
      s/__job_walltime__/${job_walltime}/go;
      s/__v_cycle__/$args{cycle}/go;
      s/__my_own_pack__/${build}/go;
      s/__nam_path__/${nam_path_plain}/go;
      s/__mitra_pid__/$args{mitra_pid}/go;
      s/__mitra_home__/${mitra_home_plain}/go;
      s/__mit_install_dir__/${mit_install_dir}/go;
      s/\[ ! -n "\$MIT_UNCHAINED_JOB" \] && \.\/test\.x\d+\s*\n//o;
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
  my $mitra_idbypid = 'false';
  my $mitra_namdir = '';

  my $mitrc = "$ENV{HOME}/.mitrc";
  if (! -f $mitrc)
    {
      (my $mf = 'FileHandle'->new (">$mitrc"))
        or die ("Cannot create `$mitrc'");
      $mf->print (<<'BASTA');
# the next chain ID
MITRA_PID=0002

# do you rather want to have the chains IDs
# given by the process id (like before)?
MITRA_IDbyPID=false
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
      if ($mitrc_content =~ /MITRA_IDbyPID\s*=\s*(\w+)/)
        {
          $mitra_idbypid = $1;
        }
      if ($mitrc_content =~ /MITRA_NAMDIR\s*=\s*(.+)/)
        {
          $mitra_namdir = $1;
          $mitra_namdir =~ s/^"//;
          $mitra_namdir =~ s/"$//;
        }

      if ($mitra_idbypid eq 'true')
        {
          $mitra_pid = $$;
        }
      else
        {
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
  my $profil_file = "$args{ref_jobsdir}/$args{station}/profil_table";
  (my $pf = 'FileHandle'->new ("<$profil_file"))
    or die ("Cannot open `$profil_file'");
  while (<$pf>)
    {
      chomp;
      next if (/^\s*#/o || /^\s*$/o);
      my @cols = split (/\s+/o, $_);
      shift @cols while (@cols && $cols[0] eq '');
      next unless (@cols >= 6);
      my $job_name = $cols[0];
      my $walltime = $cols[1];
      my $nproc_io = $cols[2];
      my $nprocs = $cols[3];
      my $nnode = $cols[4];
      my $nthreads = $cols[5];
      $PROFIL_TABLE{$job_name} = [$walltime, $nproc_io, $nprocs, $nnode, $nthreads];
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

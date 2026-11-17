package mitraille::generate;

use strict;

use FileHandle;

use mitraille::util qw (slurp spew);

sub getjob
{
  my %args = @_;
  my $job_name = $args{job_name};
  if (-f "$args{mit_install_dir}/$args{cycle_lc}/$job_name")
    {
      return "$args{mit_install_dir}/$args{cycle_lc}/$job_name";
    }
  else
    {
      return "$args{ref_jobsdir}/$job_name";
    }
}

sub getprofil
{
  my %args = @_;
  my ($profile, $profil_table) = @args{qw (profile profil_table)};

  die ("$args{job_name}: unknown profile `$profile' (see $args{profil_file})\n")
    unless (exists ($profil_table->{$profile}));

  my @h = @{ $profil_table->{header} };
  my @c = @{ $profil_table->{$profile} };

  my %p = map { ($h[$_], $c[$_]) } (0 .. $#h);

  return \%p;
}

# Shell code following the Slurm directives: task & thread counts

my $JOBHEADER = << 'EOF';

NNODE_FC=__nnode_fc__
NTASK_FC=__ntask_fc__
NOPMP_FC=__nopmp_fc__

let "NPROC=$NNODE_FC*$NTASK_FC"

NNODE_IO=__nnode_io__
NTASK_IO=__ntask_io__
NOPMP_IO=__nopmp_io__

if [ $NTASK_IO -eq 0 ]
then
  NTASK_IO=1
fi

let "NPROC_IO=$NNODE_IO*$NTASK_IO"

EOF

# End of the job

my $JOBTRAILER = << 'EOF';

sleep 2

echo COMPLETED

showslurminfo
EOF

# Slurm directives of a job: profiles with the partial flag use part of a single
# node (sbatch.partial), that is ntask_fc x nopmp_fc cores; when Slurm counts
# hyperthreads as CPUs (cpus_per_core > 1 in machine.conf), each OpenMP thread is
# given all the CPUs of a core. Other jobs, and all jobs on stations without
# sbatch.partial, use whole nodes (sbatch.full).

sub sbatch_header
{
  my %args = @_;

  my ($prof, $machine, $job_name) = @args{qw (prof machine job_name)};

  my $partial = "$args{ref_jobsdir}/$args{station}/sbatch.partial";

  return (&slurp ("$args{ref_jobsdir}/$args{station}/sbatch.full"), $prof->{nopmp_fc})
    unless ($prof->{partial} && (-f $partial));

  die ("$job_name: a partial node profile must use a single node, without IO server\n")
    unless (($prof->{nnode_fc} == 1) && ($prof->{nnode_io} == 0));
  die ("$job_name: a partial node profile must use at most $machine->{cores_per_node} cores\n")
    if ($machine->{cores_per_node} && ($prof->{ntask_fc} * $prof->{nopmp_fc} > $machine->{cores_per_node}));

  return (&slurp ($partial), $prof->{nopmp_fc} * ($machine->{cpus_per_core} || 1));
}

sub set_job
{
  my %args = @_;

  my $job_name = $args{job_name};
  my $code_name = $args{code_name};

  my $JOB = &getjob (%args);

  my $content = &slurp ($JOB);

  my ($profile, $time) = ($content =~ m/PROFILE\s*=\s*(\S+)\s*,\s*TIME\s*=\s*(\d+)m?/oms);

  die ("$JOB: no `# MITRAILLE PROFILE = <profile>, TIME = <minutes>' line\n")
    unless ($profile && $time);

  my $prof = &getprofil (%args, profile => $profile);

  my ($sbatch, $cpus_per_task) = &sbatch_header (%args, prof => $prof);

  $content = $sbatch
           . $JOBHEADER
           . "export STATION=$args{station}\n"
           . &slurp ("$args{ref_jobsdir}/$args{station}/config_$args{cycle}")
           . $content
           . $JOBTRAILER;

# Values of the __placeholders__; upper case ones (eg __NTASKS__) belong to
# namelist templates and are replaced by the jobs themselves

  my %subst =
  (
    jobname          => "O${code_name}",
    nb_nodes         => $prof->{nnode_fc} + $prof->{nnode_io},
    (map { ($_, $prof->{$_}) } qw (nnode_fc ntask_fc nopmp_fc nnode_io ntask_io nopmp_io)),
    cpus_per_task    => $cpus_per_task,
    job_walltime     => $time,
    v_cycle          => $args{cycle},
    my_own_pack      => $args{build} // '',
    nam_path         => "$args{ref_namdir}/$args{cycle_lc}",
    mitra_pid        => $args{mitra_pid},
    mit_install_dir  => $args{mit_install_dir} // '',
  );

  for ($content)
    {
      s{__([a-z][a-z0-9_]*)__}
       {
         exists ($subst{$1}) or die ("$JOB: unknown placeholder `__$1__'\n");
         $subst{$1}
       }geo;

      if ($args{save})
        {
          s{^([ \t]*)(mpilaunch\b.*)$}
           {$1impilaunch=\$((impilaunch+1))\n$1mitsave start \$SAVE_DIR/\$CNMEXPL.\$impilaunch\n$1$2\n$1mitsave end \$SAVE_DIR/\$CNMEXPL.\$impilaunch}gmo;
        }
    }

  &spew ("$args{job_dir}/${code_name}.cjob", $content);
}

#---------------------------------------------------------------------------------------------------------
# Main entry point
#---------------------------------------------------------------------------------------------------------

sub run
{
  my %args = @_;

  $args{mit_install_dir} ||= $ENV{MIT_INSTALL_DIR};
  $args{station}         ||= $ENV{STATION};

  $args{ref_jobsdir} = "$args{mit_install_dir}/protojobs";
  $args{ref_namdir} = "$args{mit_install_dir}/namelist";
  $args{cycle_lc} = lc ($args{cycle});

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
  if (! -d "$args{mit_install_dir}/$args{cycle_lc}")
    {
      mkdir ("$args{mit_install_dir}/$args{cycle_lc}");
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
  $args{profil_file} = $profil_file;

  #---------------------------------------------------------------------------------------------------------
  # 3b. Read machine description (compute nodes), if any
  #---------------------------------------------------------------------------------------------------------

  my $machine_file = "$args{ref_jobsdir}/$args{station}/machine.conf";
  if (-f $machine_file)
    {
      $args{machine} = do ($machine_file)
        or die ("Cannot read `$machine_file': " . ($@ || $!) . "\n");
    }

  #---------------------------------------------------------------------------------------------------------
  # 4. Initialisations
  #---------------------------------------------------------------------------------------------------------

  $args{job_dir} = "$args{mit_install_dir}/$args{cycle_lc}/mitraille_$args{mitra_pid}";

  mkdir ($args{job_dir}) if (! -d $args{job_dir});

  #---------------------------------------------------------------------------------------------------------
  # 5. Process PRO_FILE and generate jobs
  #---------------------------------------------------------------------------------------------------------

  (my $proffh = 'FileHandle'->new ("<$args{pro_file}"))
    or die ("Cannot open `$args{pro_file}'");
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

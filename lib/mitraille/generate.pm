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

# Shell settings, before the station settings (site.sh)

my $JOBSHELL = << 'EOF';

set -e
set -E

trap 'echo "FAILED at line $LINENO" ; showslurminfo ; exit 1' ERR
trap 'echo "CANCELLED"; showslurminfo ; exit 1' TERM

set -x

EOF

# Settings common to all stations, after the station settings (site.sh)

my $JOBCONFIG = << 'EOF';

# where the io_serv tools are
IO_SERV_TOOLS_DIR=__mit_install_dir__/io_serv_tools

# Where to save the files created or modified by the jobs (mitpack --save)
SAVE_DIR=${WORKDIR}/mitsave

if [ "x$STARTTIME" != "x" ]
then
TMP_LOC=$TMP_BASE/mitraille.${SLURM_JOBID}.${STARTTIME}
else
TMP_LOC=$TMP_BASE/mitraille.${SLURM_JOBID}
fi

\rm -rf $TMP_LOC/*
mkdir -p $TMP_LOC

# Location of input data: cycle independent data
# FILE_PATH_DBASE.. for databases to use conf 923.
# FILE_PATH for other files.

# - for regular validation
FILE_PATH=${INPUTFILES_HOME}/anal_mitraille
FILE_PATH_DILA=${INPUTFILES_HOME}/dila
FILE_PATH_DBASE1=${INPUTFILES_HOME}/const/923N/RELIEF_G/GTOPT030
FILE_PATH_DBASE2=${INPUTFILES_HOME}/const/923N/SURFACE_G/version2/i3e
FILE_PATH_DBASE3=${INPUTFILES_HOME}/const/923N/N108/i3e
FILE_PATH_DBASE5=${INPUTFILES_HOME}/const/923N/SURFACE_L/EUROPEb_v1/i3e
FILE_PATH_DBASE6=${INPUTFILES_HOME}/const/923N/CLIM_G/version2/i3e
FILE_PATH_DBASE8=${INPUTFILES_HOME}/const/923N/CLIM_G/ozone/ascii
FILE_PATH_DBASE9=${INPUTFILES_HOME}/const/923N/CLIM_G/aerosols/ascii
FILE_PATH_IFS=${INPUTFILES_HOME}/ifs-tco399
# - for scientific tests
FILE_PATH_EXPS=${INPUTFILES_WORKDIR}

# Location of input data: cycle dependent data
# FILE_PATH_RRTMCST for constant files used in the RRTM radiation scheme.
# FILE_PATH_ECOCLIMAP for "ecoclimap" files used in SURFEX.
# FILE_PATH_PGD for databases to make PGD files.
FILE_PATH_RRTMCST=${INPUTFILES_HOME}/const/rrtm_cst_cy47R1   ##netcdf files since cy47t1r1.v03 (= pre-cy48 v3)
FILE_PATH_ECOCLIMAP=${INPUTFILES_HOME}/const/ecoclimap/V8.0
FILE_PATH_PGD=${INPUTFILES_HOME}/const/mesonh/PGD/V02

# Definition of cp/ecp for files and namelists
# - for files which are on the local machine.
CP="copy"    # 'ln -s' is forbidden for this command
# - for files which may be either on a storage machine or on the local machine.
ECP="ln -sf"   # 'ln -s' is allowed for this command

# io_serv tools
# IO POLL, recombining fields after io_serv
IOPOLL="$IO_SERV_TOOLS_DIR/io_poll"
# LFI copy, with repacking
LFICP="lficp"
# LFI move, with repacking
LFIMV="lfimv"

function lfimv
{
  s=$1
  d=$2
  mkdir -p $(dirname $d)
  $IO_SERV_TOOLS_DIR/lfi_move -pack -force $s $d
}

function lficp
{
  s=$1
  d=$2
  mkdir -p $(dirname $d)
  $IO_SERV_TOOLS_DIR/lfi_copy -pack -force $s $d
}

function copy
{
  d="${!#}"
  set -- "${@:1:$#-1}"

  for s in $*
  do
    mkdir -p $(dirname $d)
    /bin/cp $s $d
  done
}

function mpilaunch
{
  bin=$(dirname $1)
  prefix=$(dirname $bin)

  if [ -f "$prefix/mitpack.sh" ]
  then
    source "$prefix/mitpack.sh"
  fi

  ls -d ./* > dirlst

  time \
    $MPIAUTO \
    --verbose --wrap --wrap-stdeo \
        -nn $NNODE_FC -nnp $NTASK_FC -openmp $NOPMP_FC -- $* \
    --  -nn $NNODE_IO -nnp $NTASK_IO -openmp $NOPMP_IO -- $*
}

function showslurminfo
{
if [ "x$STARTTIME" != "x" ]
then
sacct -j $SLURM_JOBID -o jobID,ncpu,TotalCPU,UserCPU,SystemCPU,Elapsed,State,ExitCode,AveVMSize,MaxVMSize,AveRSS,MaxRSS,AvePages --starttime $STARTTIME
else
sacct -j $SLURM_JOBID -o jobID,ncpu,TotalCPU,UserCPU,SystemCPU,Elapsed,State,ExitCode,AveVMSize,MaxVMSize,AveRSS,MaxRSS,AvePages
fi
}

export PATH=__mit_install_dir__/bin:$PATH

# xpnam
XPNAM=xpnam

# the io_serv tools need LFITOOLS
export LFITOOLS=$EXEC_IFSAUX_LFITOOLS

EOF

# Beginning of the test case, before the pjob

my $JOBPROLOGUE = << 'EOF';

CNMEXPL=__cnmexpl__
echo CNMEXPL=$CNMEXPL

NAM_PATH=__nam_path__
BINDIR=__my_own_pack__/bin
MYOWNBIN=$BINDIR/MASTERODB

# Set the parallel distribution in namprovi; --io adds the number of IO server tasks

function setnampar
{
  local io=""
  if [ "x$1" = "x--io" ]
  then
    io="
&NAMIO_SERV
  NPROC_IO=$NPROC_IO,
/"
  fi
  $XPNAM --delta="$io
&NAMPAR0
  MBX_SIZE=$MBX_SIZE,
  NPROC=$NPROC,
  MP_TYPE=$MP_TYPE,
  LOPT_SCALAR=$LOPT_SCALAR,
/
&NAMPAR1
  NSTRIN=$NPROC,
  NSTROUT=$NPROC,
  NCOMBFLEN=$NCOMBFLEN,
/
" namprovi=${CNMEXPL}.nam
}

# Copy the namelist of the test case, and set the parallel distribution in namprovi

function getnam
{
  $CP ${NAM_PATH}/${CNMEXPL}.nam ${CNMEXPL}.nam
  setnampar "$@"
}

# Print the listings of the MPI tasks

function shownode
{
  if [ -a NODE.001_01 ]
  then
    for file in NODE*
    do
      echo " Expand file $file "
      \cat $file
    done
  fi
}

echo "@@ `date`"

# Move on a workspace.
cd $TMP_LOC

EOF

# End of the test case, after the pjob

my $JOBEPILOGUE = << 'EOF';

ls -l

echo "@@ `date`"
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

# Station settings: site_<cycle>.sh if a cycle needs its own, otherwise site.sh

sub site_file
{
  my %args = @_;
  for my $site ("site_$args{cycle}.sh", "site.sh")
    {
      return "$args{ref_jobsdir}/$args{station}/$site" 
        if (-f "$args{ref_jobsdir}/$args{station}/$site");
    }
  die ("No site.sh for station `$args{station}'\n");
}

sub set_job
{
  my %args = @_;

  my $job_name = $args{job_name};
  my $code_name = $args{code_name};

  my $JOB = &getjob (%args);

  my $content = &slurp ($JOB);

# Metadata: "# MITRAILLE KEY = value" lines (PROFILE, TIME in minutes, COMMENT)

  my %meta = ($content =~ m/^#\s*MITRAILLE\s+(\w+)\s*=[ \t]*(.*?)[ \t]*$/gm);

  my ($profile, $time) = @meta{qw (PROFILE TIME)};

  die ("$JOB: `# MITRAILLE PROFILE = <profile>' and `# MITRAILLE TIME = <minutes>' lines are required\n")
    unless ($profile && defined ($time) && ($time =~ s/^(\d+)m?$/$1/o));

  my $prof = &getprofil (%args, profile => $profile);

  my ($sbatch, $cpus_per_task) = &sbatch_header (%args, prof => $prof);

  $content = $sbatch
           . $JOBHEADER
           . "export STATION=$args{station}\n"
           . $JOBSHELL
           . &slurp (&site_file (%args))
           . $JOBCONFIG
           . $JOBPROLOGUE
           . $content
           . $JOBEPILOGUE
           . $JOBTRAILER;

# Values of the __placeholders__; upper case ones (eg __NTASKS__) belong to
# namelist templates and are replaced by the jobs themselves

  my %subst =
  (
    jobname          => "O${code_name}",
    cnmexpl          => $code_name,
    nb_nodes         => $prof->{nnode_fc} + $prof->{nnode_io},
    (map { ($_, $prof->{$_}) } qw (nnode_fc ntask_fc nopmp_fc nnode_io ntask_io nopmp_io)),
    cpus_per_task    => $cpus_per_task,
    job_walltime     => $time,
    v_cycle          => $args{cycle},
    my_own_pack      => $args{build} // '',
    nam_path         => "$args{ref_namdir}/$args{cycle_lc}",
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
  if (! $args{job_dir})
    {
      die ("Test case directory must be provided\n");
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
  # 4. Process PRO_FILE and generate jobs
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

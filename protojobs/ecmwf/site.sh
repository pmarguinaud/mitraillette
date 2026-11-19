#
# Mitraillette settings for the ECMWF cluster
#

# Where to store the output files
WORKDIR=${SCRATCH}

# The temporary directory of each job is created there
TMP_BASE=$SCRATCH/tmp

# Location of input data
INPUTFILES_HOME=/perm/sor/mitraillette-data/
INPUTFILES_WORKDIR=/perm/sor/mitraillette-data/

# LFITOOLS
EXEC_IFSAUX_LFITOOLS=/perm/soa1/mitraille/io_serv_tools/lfitools_cy50t1rc.OMPIIFC2302DP2.y/lfitools

# MPI launcher
MPIAUTO=/home/sor/install/mpiauto/mpiauto

# Machine-depending namelist variables
LOPT_SCALAR=.TRUE.
MBX_SIZE=1024000000
NCOMBFLEN=1800000
MP_TYPE=2

# BULL specific environment variables
ulimit -s unlimited
module purge

#Oper settings for Intel MKL library
# variables for perfect reproductibilty for some oper conf.
export MKL_CBWR=AUTO,STRICT
export MKL_DEBUG_CPU_TYPE=5
export MKL_NUM_THREADS=1

export OMP_STACKSIZE=4G
export KMP_STACKSIZE=4G
export KMP_MONITOR_STACKSIZE=1G
export EC_MPI_ATEXIT=0
export EC_PROFILE_HEAP=0
export MPIAUTOCONFIG=mpiauto.TIME.conf

export DR_HOOK=1
export DR_HOOK_IGNORE_SIGNALS=-1
export DR_HOOK_SILENT=1
export DR_HOOK_OPT=prof
export MPL_MBX_SIZE=2048000000
export KMP_BLOCKTIME=12
export OMP_WAIT_POLICY=ACTIVE


export ZOPT="" # optimisation options when running.
export EC_MEMINFO=0

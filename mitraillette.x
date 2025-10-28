#!/bin/ksh
#

#=============================================================================
#|            PORTABLE MITRAILLETTE. VERSION October 2025                   |
#|            May be used for cycle CY50T1                                  |
#=============================================================================

#************************************************************************************************************************
# LA MITRAILLETTE                                                                                                       #
#                                                                                                                       #
#  C. Fischer *Meteo-France/CNRM/GMAP*                                                                                  #
#   original du 18 juin 1999                                                                                            #
#   march 2004 revision (A. Dziedzic, add some configurations)                                                          #
#   december 2004 revision (K. Yessad, possibility to choose monoproc or multiproc jobs)                                #
#   january 2005 revision (K. Yessad, remove obsolete configs, add new configs)                                         #
#   march 2005 revision (K. Yessad, add new configs)                                                                    #
#   june 2005 revision (M. Janousek + M. Jerczynski, various improvements, add new configs)                             #
#   december 2006 revision (G. Boloni, add new configs)                                                                 #
#   february 2007 revision (K. Yessad + P. Saez, remove obsolete configs, add new configs, upgrades)                    #
#   april 2007 revision (author=???, add new configs)                                                                   #
#   april 2008 revision (Tomas Wilhelmsson, made portable to ECMWF HPCE)                                                #
#   august 2008 revision (author=???, new NH configs)                                                                   #
#   october 2008 revision (Ulf Andrae, (re)port to ECMWF HPCE / SMHI Linux cluster)                                     #
#   january 2009 revision (P. Saez, upgrades)                                                                           #
#   spring 2010 complete revision                                                                                       #
#   spring 2011 complete revision                                                                                       #
#   september 2011 revision (physics cy36t1_op2)                                                                        #
#   december 2011 revision (add AC1T, AC1U, AXSX, AXSY)                                                                 #
#   june 2012 revision                                                                                                  #
#   april 2013 revision                                                                                                 #
#   summer 2013 revisions (porting on BULL)                                                                             #
#   january 2014 revision (removal of command line)                                                                     #
#   april 2014 revision (merge mitrarp/mitraillette environments)                                                       #
#   december 2014 revision (v122014)                                                                                    #
#   march 2015 revision (v032015)                                                                                       #
#   january 2016 revision (v012016)                                                                                     #
#   july 2016 revision (v072016)                                                                                        #
#   february 2017 revision (v022017; new flexible MITRAILLETTE)                                                         #
#   october 2017 revision (v102017)                                                                                     #
#   April 2018 revision (v042018)                                                                                       #
#   December 2018 revision (v122018)                                                                                    #
#   December 2019 revision (v122019) (physics cy43t2_op2)                                                               #
#   December 2021 revision (v122021):                                                                                   #
#    -add options WENO,RK4; add précip,visi and flash diag; NH option "W";                                              #
#    -FPOF becomes conf. 903; add aero fields on 2 jobs                                                                 #
#    -test LELTRA=T (NAMDYNA) in 2 jobs                                                                                 #
#    -4 new protojobs and namelists: L3_FCST_NHE_SL2_VFD_ADIAB_GWADV5_PCF_FROC, GM_FCST_HYD_SL2RK_VFE_ARPPHYISBA_TL107U,#
#    GM_FCST_NHE_SL2_VFD_ADIAB_GWADV5_SI_TL030S, GM_FCTI_HYD_SL2_VFE_ARPPHYSFEX_WENO_TL798S                             #
#   October 2025 revision (v102025): add 10 new jobs:                                                                #
#    -5 IFS forecast, 2 WENO jobs, 2 CVFE jobs, 1 PEARP options job, 
#*****************                                                                                                      #
#                                                                                                                       #
#  Usage :  mitraillette.x CYCLE PRO_FILE                                                                               #
#           mitraillette.x ?                                                                                            #
#                                                                                                                       #
#  Localisation        : [machine] ~saez/mitraille/mitraillette.x                                                       #
#                        Under GIT: mitraille/procedures/mitraillette.x                                                 #
#                                                                                                                       #
#*****************                                                                                                      #
#  Script used to test a list of ARPEGE, ALADIN, AROME, ALARO configurations.                                           #
#  This script uses job chaining; when a job ends, it automatically sends the following job.                            #
#  "mitraillette" starts sequence itself, then each job launches script "test.x${MITRA_PID}" which                      #
#   allows to chain "qsub" in the appropriate directory (matching with cycle to be validated).                          #
#  "mitraillette" fills files "rank_file.x${MITRA_PID}" and "rank_last.x${MITRA_PID}"; it reads                         #
#   configurations to be validated in a file named PRO_FILE.                                                            #
#  Finally, "mitraillette" provides a file named "log_file_$CYCLE_${MITRA_PID}" under directory "$MITRA_HOME":          #
#   this file provided the set of configurations asked for in tests with their order number.                            #
#                                                                                                                       #
#---------------------------------------------------------------------------                                            #
#  User must do the non-automatic following actions:                                                                    #
#   * create file PRO_FILE.                                                                                             #
#   * execute "mitraillette.x CYCLE PRO_FILE"                                                                           #
#     CYCLE name should be in capital letters and should match the directory [cycle]                                    #
#     (in lowercase letters, under "$MITRA_HOME") where jobs are stored.                                                #
#                                                                                                                       #
#---------------------------------------------------------------------------                                            #
#  Where are stored input data and environnement files?                                                                 #
#---------------------------------------------------------------------------                                            #
#                                                                                                                       #
#  * Each task is now described by an identifier starting for example by GM, GE, L3, L2, L1.                            #
#    GM: global model, LECMWF=F                                                                                         #
#    GE: global model, LECMWF=T                                                                                         #
#    L3: LAM model (3D)                                                                                                 #
#    L2: 2D LAM model                                                                                                   #
#    L1: 1D LAM model (column)                                                                                          #
#    This identifier is used at several places, for example in protojobs and namelists.                                 #
#    This identifier tries to describe what does the job.                                                               #
#                                                                                                                       #
#----------------------------------------                                                                               #
#  * Input files are stored on: /scratch/work/saez/                                                                     #
#                                                                                                                       #
#  * Namelists : ~saez/mitraille/namelist/[cycle]                                                                       #
#    Under GIT: directory mitraille/namelist                                                                            #
#    A new directory must be created for namelists at each new cycle.                                                   #
#    Namelists may contain some character chains which can be substituted by scripts.                                   #
#    Namelists names are generally [identifier].nam                                                                     #
#                                                                                                                       #
#  * Protojobs scripts : ~saez/mitraille/protojobs                                                                      #
#    Under GIT: directory mitraille/protojobs                                                                           #
#    Protojobs names are generally [identifier].pjob                                                                    #
#                                                                                                                       #
#  * Chainjob files have a name [identifier].cjob                                                                       #
#                                                                                                                       #
#  * Output files have a name starting by O[identifier]                                                                 #
#----------------------------------------                                                                               #
#                                                                                                                       # 
#************************************************************************************************************************



# Specifiy and store the current directory
MITRA_HOME=`pwd`

# Host specific settings

# Rename any digits in hostname (translating "hpce0105" to "hpce")
## HOST=`uname -n | tr -d "[:digit:]"`
HOST=$STATION

# Copy arguments

CYCLE=$1
PRO_FILE=$2

# Get the configuration
if [ ! -n "$MIT_INSTALL_DIR" ] ; then
 echo "variable MIT_INSTALL_DIR must be defined and exported in your environment"
 echo " for example: export MIT_INSTALL_DIR=\${HOME}/mitraille (in your ~/.bash_profile)"
 exit 1
fi

REF_JOBSDIR=$MIT_INSTALL_DIR/protojobs
REF_NAMDIR=$MIT_INSTALL_DIR/namelist
MULTIHEADER=$REF_JOBSDIR/$HOST/multiheader
JOBTRAILER=$REF_JOBSDIR/$HOST/jobtrailer
eval WORKDIR=$(echo $(awk -F"=" "\$1==\"WORKDIR\" { print \$2;exit }" ${MIT_INSTALL_DIR}/protojobs/$HOST/config_${CYCLE}))
SUBMIT=$(awk -F"=" "\$1==\"SUBMIT\" { print \$2;exit }" ${MIT_INSTALL_DIR}/protojobs/$HOST/config_${CYCLE})

# Set up the experiment ID and the resource file
typeset -Z4 MITRA_PID
typeset -Z4 MITRA_PID1
if [ ! -f $HOME/.mitrc ] ; then
  cat > $HOME/.mitrc <<BASTA
# the next chain ID
MITRA_PID=0002

# do you rather want to have the chains IDs
# given by the process id (like before)?
MITRA_IDbyPID=false
BASTA
  MITRA_PID=1
else
  . $HOME/.mitrc
  if [ "$MITRA_IDbyPID" = "true" ] ; then
    MITRA_PID=$$
  else
    [ -n "$MITRA_PID" ] || { echo "MITRA_PID variable is missing in \$HOME/.mitrc"  ; exit 1 ; }
    if [ $MITRA_PID -le 9999 ] ; then MITRA_PID1=$(($MITRA_PID + 1)) ; else MITRA_PID1=1 ; fi
    sed -e "s/MITRA_PID=${MITRA_PID}/MITRA_PID=${MITRA_PID1}/" $HOME/.mitrc > .mw$$ && \mv .mw$$ $HOME/.mitrc
  fi
fi
# eventually take the namelist directory from .mitrc file
[ -n "$MITRA_NAMDIR" ] && REF_NAMDIR=$MITRA_NAMDIR
set +x

LOG_MIT=$(pwd)/mitraillette.o${MITRA_PID}
echo "\n ********************************************************" | tee -a ${LOG_MIT}
echo " **M_INFO   ** BEGINNING OF mitraillette.x ( id = ${MITRA_PID} )" | tee -a ${LOG_MIT}
echo " ********************************************************\n" | tee -a ${LOG_MIT}


#---------------------------------------------------------------------------------------------------------
# 0. Arguments tests
#---------------------------------------------------------------------------------------------------------

#
# directories - cycle - information
#
WHOAMI=`logname`

case $# in
1) if [ "$CYCLE" != '?' ] ; then
    echo "\n **M_ERROR  ** If one argument used then" | tee -a ${LOG_MIT}
    echo "               it must be '?', please !" | tee -a ${LOG_MIT}
    echo "               See informations below...\n" | tee -a ${LOG_MIT}
    CYCLE="?"
   fi ;;
2) cycle=`echo $CYCLE | tr [A-Z] [a-z]`
   LOCAL_DIR=`pwd`
   if [ "$LOCAL_DIR" != "$MITRA_HOME" ] ; then
    echo "\n **M_ERROR  ** Please create your local directory name : mitraille" | tee -a ${LOG_MIT}
    echo "LOCAL_DIR=$LOCAL_DIR MITRA_HOME=$MITRA_HOME" | tee -a ${LOG_MIT}
    echo "               ( for mitraillette and test.ref files and CYCLE jobs directory )" | tee -a ${LOG_MIT}
    echo "               See informations below...\n" | tee -a ${LOG_MIT}
    CYCLE="?"
   else
    if [ ! -d "$LOCAL_DIR/$cycle" ] || [ ! -a "$PRO_FILE" ]  ; then
     echo "\n **M_ERROR  ** If two arguments used then" | tee -a ${LOG_MIT}
     echo "               the first must be an existing directory named CYCLE" | tee -a ${LOG_MIT}
     echo "               in upper case characters format," | tee -a ${LOG_MIT}
     echo "               the second must be an existing file (PRO_FILE format)," | tee -a ${LOG_MIT}
     echo "               See informations below...\n" | tee -a ${LOG_MIT}
     CYCLE="?"
    else
     echo "\n **M_INFO   ** Arguments are valid, Go ahead !\n" | tee -a ${LOG_MIT}
    fi
   fi ;;
*) echo "\n **M_ERROR  ** One or two arguments needed, please !" | tee -a ${LOG_MIT}
   echo "               See informations below...\n" | tee -a ${LOG_MIT}
   CYCLE="?" ;;
esac

if [ "$CYCLE" = '?' -o "$CYCLE" = '-?' -o "$CYCLE" = '-h' -o "$CYCLE" = '-help' -o "$CYCLE" = '--h' ] ; then
cat << EOCAT | tee -a ${LOG_MIT}

Well, in a brief:
1) Make your PRO_FILE text file containing lines
xxxx executable_path_and_name
where xxxx = mitraillette configuration to run
      executable_path_and_name = full path to the binary
2) Make directory \$MITRA_HOME/cycle/
3) If you want to have your own prototype scripts copy them to
\$MITRA_HOME/cycle/
4) If you need your own namelists have them in a directory like somenamelistdirectory/cycle/
5) If any of 3 or 4 is the case ame your copy of mitraillette.x
and put your directories with scripts and/or namelists to the beginning of the script.
6) Run mitraillette.x CYCLE yourPRO_FILE 
where CYCLE is cycle in upper-case.
7) Your chain scripts will have been created in \$MITRA_HOME/cycle/.
Run \$MITRA_HOME/test.xNNNN where NNNN is the chain ID (a number) to start the chain of jobs.

EOCAT
exit 0
fi


#---------------------------------------------------------------------------------------------------------
# 1. Initialisations
#---------------------------------------------------------------------------------------------------------

#
# function definitions
#
getjob () {
if [ -f $MITRA_HOME/$cycle/$2 ] ; then
  eval $1=$MITRA_HOME/$cycle/$2
else
  eval $1=$REF_JOBSDIR/$2
fi
}

# Get settings for one job: Memory, time, Processors, nodes, threads ...
getprofil () {
 pickProfile=$(awk "\$1==\"$1\" { print \$0;exit }" $REF_JOBSDIR/$HOST/profil_table)
 eval $2=$(echo ${pickProfile} | awk '{ print $2}')
 eval $3=$(echo ${pickProfile} | awk '{ print $3}')
 eval $4=$(echo ${pickProfile} | awk '{ print $4}')
 eval $5=$(echo ${pickProfile} | awk '{ print $5}')
 eval $6=$(echo ${pickProfile} | awk '{ print $6}')
 eval $7=$(echo ${pickProfile} | awk '{ print $7}')
 eval $8=$(echo ${pickProfile} | awk '{ print $8}')
}

function set_job 
{
JOB_NAME=$1
CODE_NAME=$2
COMMENT=$3
# We distinguish between NTASKS which matches the namelist variable "NPROC",
#  and NTASKS_TOT which is the total number of processors which appears in the job header (NTASKS_TOT >= NTASKS).
 getjob JOB $JOB_NAME
 getprofil $JOB_NAME job_maxmem job_walltime job_cputime job_nproc_io job_ntasks_tot job_nnode job_nthreads

  NPROC_IO=`echo $job_nproc_io | awk '{printf("%d",$0)}'` # matches with namelist variable "NPROC_IO"
  NTASKS_TOT=`echo $job_ntasks_tot | awk '{printf("%d",$0)}'` # total number of processors
  NBNODES=`echo $job_nnode | awk '{printf("%d",$0)}'`
  NBTHREADS=`echo $job_nthreads | awk '{printf("%d",$0)}'`
  NTASKS=$(( $NTASKS_TOT - $NPROC_IO ))                       # matches with namelist variable "NPROC"
  NTASKS_BY_NODE=$(( $NTASKS_TOT / $NBNODES ))                       # for the header job
  cat $MULTIHEADER $REF_JOBSDIR/$HOST/config_${CYCLE} $JOB $JOBTRAILER | \
  sed  -e "s/__jobname__/O${CODE_NAME}/" \
       -e "s/__ntasks_tot__/${NTASKS_TOT}/g" -e "s/__ntasks__/${NTASKS}/" -e "s/__nb_proc_io__/${NPROC_IO}/" \
       -e "s/__nb_nodes__/${NBNODES}/" -e "s/__ntasks_by_node__/${NTASKS_BY_NODE}/" \
       -e "s/__nb_threads__/${NBTHREADS}/" \
       -e "s/__job_maxmem__/${job_maxmem}/" -e "s/__job_walltime__/${job_walltime}/" -e "s/__job_cputime__/${job_cputime}/" \
       -e "s/__v_cycle__/${CYCLE}/" -e "s/__my_own_bin__/${UL_MOWN}/" \
       -e "s/__nam_path__/${nam_path}/" -e "s/__mitra_pid__/${MITRA_PID}/g" -e "s/__mitra_home__/${mitra_home}/" \
       -e "s/__mit_unchained_job__/${MIT_UNCHAINED_JOB}/" \
       > ${JOB_DIR}/${CODE_NAME}.cjob
  ln -s ${JOB_DIR}/${CODE_NAME}.cjob ${JOB_DIR}/chainjob_$seqn
  echo "$seqn : ${COMMENT} :  ${CODE_NAME} " >> $LOG_FILE
  seqn=$(( $seqn + 1 ))
}
#end function set_job
# startup
#

# create directory for receiving historical output files
#
echo "\n **M_INFO   ** Creating directory OUTPUT_FILES/$CYCLE on WORKDIR $WORKDIR \n" | tee -a ${LOG_MIT}

if  [ ! -d ${WORKDIR}/OUTPUT_FILES ]
then
 mkdir ${WORKDIR}/OUTPUT_FILES
fi

if  [ ! -d ${WORKDIR}/OUTPUT_FILES/${CYCLE} ]
then
 mkdir ${WORKDIR}/OUTPUT_FILES/${CYCLE}
fi

if  [ ! -d ${WORKDIR}/OUTPUT_FILES/${CYCLE}/mitraille_${MITRA_PID} ]
then
 mkdir ${WORKDIR}/OUTPUT_FILES/${CYCLE}/mitraille_${MITRA_PID}
fi

#
# initialize chaining
#
LOG_FILE=${LOCAL_DIR}/log_file_${CYCLE}_${MITRA_PID}
> $LOG_FILE

echo 00 > rank_file.x${MITRA_PID}

JOB_DIR="${MITRA_HOME}/${cycle}/mitraille_${MITRA_PID}"
mkdir -p $JOB_DIR
echo "\n **M_INFO   ** Created directory $JOB_DIR \n" | tee -a ${LOG_MIT}
#
##############################################################################################
# Preparing last job to solve the "qcat -n" bug at the end (old version).
##############################################################################################

getprofil endjob job_maxmem job_walltime job_cputime job_nproc_io job_ntasks_tot job_nnode job_nthreads
NBPROCS_END=`echo $job_ntasks_tot | awk '{printf("%d",$0)}'`
NBNODES_END=`echo $job_nnode | awk '{printf("%d",$0)}'`
NTASKS_END=$(( $NBPROCS_END / $NBNODES_END ))
NB_THREADS_END=`echo $job_nthreads | awk '{printf("%d",$0)}'`
sed  -e "s/__jobname__/endjob/" \
     -e "s/__job_maxmem__/${job_maxmem}/" -e "s/__nb_threads__/${NB_THREADS_END}/" \
     -e "s/__job_walltime__/${job_walltime}/" -e "s/__job_cputime__/${job_cputime}/" \
     -e "s/__ntasks_tot__/${NBPROCS_END}/" \
     -e "s/__nb_nodes__/${NBNODES_END}/" -e "s/__ntasks_by_node__/${NTASKS_END}/" \
     $MULTIHEADER > job_end.x${MITRA_PID}
cat >> job_end.x${MITRA_PID} <<PEOF

#waiting for last listing
sleep 30
cd ${MITRA_HOME}
./test.x${MITRA_PID}
PEOF
cat $JOBTRAILER >> job_end.x${MITRA_PID}
##############################################################################################
cat > test.x${MITRA_PID} <<BASTA
#!/bin/ksh

# This script submits the next partial job of the mitraillette chain
# or closes the whole chain

typeset -Z3 ncurrent
read ncurrent < ${MITRA_HOME}/rank_file.x${MITRA_PID}
read nlast < ${MITRA_HOME}/rank_last.x${MITRA_PID}
if [ "\$ncurrent" -eq 0 ] ; then
    echo "\\n *****************************************************" | tee -a ${LOG_MIT}
    echo " **T_INFO   ** BEGINNING OF \$0 ( rank = 1 )" | tee -a ${LOG_MIT}
    echo " *****************************************************\\n" | tee -a ${LOG_MIT}
else
    echo "\\n **T_INFO   ** Beginning of partial \$0 ( rank = \${ncurrent} )\\n" | tee -a ${LOG_MIT}
fi

if [ \$ncurrent -gt \$nlast ] ; then
    echo "-9" >${MITRA_HOME}/rank_file.x${MITRA_PID} 
    $SUBMIT job_end.x${MITRA_PID}
    exit 0
elif [ \$ncurrent -eq -9 ] ; then
    # this is the last task of the chain
    # dump the last job output and pack the directory with all outputs
    MIT_DIR=mitraille_${MITRA_PID}
    \\cp $LOG_FILE $JOB_DIR
    echo "               go ahead for compacting \$MIT_DIR directory\\n" | tee -a ${LOG_MIT}
    cd $cycle
    echo "\\n **T_INFO   ** Compressing \$MIT_DIR directory \\n" | tee -a ${LOG_MIT}
    tar cvf \${MIT_DIR}.tar \${MIT_DIR} | tee -a ${LOG_MIT}
    gzip \${MIT_DIR}.tar
#    /usr/local/bin/ftput -q \${MIT_DIR}.tar.gz OUTPUT_FILES/$CYCLE/\${MIT_DIR}.tar.gz
    cp \${MIT_DIR}.tar.gz ${WORKDIR}/OUTPUT_FILES/${CYCLE}/\${MIT_DIR}.tar.gz
    
    cd ..
    ## echo "\\n **T_INFO   ** Cleaning temporary files\\n" | tee -a ${LOG_MIT}
    ## rm -f rank_file.x${MITRA_PID} rank_last.x${MITRA_PID} test.x${MITRA_PID}
    echo "\\n ***********************************************" | tee -a ${LOG_MIT}
    echo " **T_INFO   ** END OF \$0 ( rank = \${nlast} )" | tee -a ${LOG_MIT}
    echo " ***********************************************\\n" | tee -a ${LOG_MIT}
else
    cd $JOB_DIR
    until [ -f chainjob_\$ncurrent -o \$ncurrent -gt \$nlast ] ; do
      #if the chain job does not exist advance ncurrent by one
      ncurrent=\$(( \$ncurrent + 1 ))
    done
    if [ \$ncurrent -le \$nlast ] ; then
      echo "\\n **T_INFO   ** Submit chainjob rank \$ncurrent \\n" | tee -a ${LOG_MIT}
      $SUBMIT chainjob_\$ncurrent
      C_NN=\$ncurrent
      ncurrent=\$(( \$ncurrent + 1 ))
      echo "\\n **T_INFO   ** Increment rank_file.x${MITRA_PID} to \${ncurrent} \\n" | tee -a ${LOG_MIT}
      echo \$ncurrent > ${MITRA_HOME}/rank_file.x${MITRA_PID}
      echo "\\n **T_INFO   ** Partial end of \$0 ( rank = \${C_NN} )\\n" | tee -a ${LOG_MIT}
    else
      #if ncurrent goes above nlast rerun this script recursively in order to perform
      #the chain closing and cleaning
      echo \$ncurrent > ${MITRA_HOME}/rank_file.x${MITRA_PID}
      eval \$0
    fi
fi
BASTA
##############################################################################################

chmod 755 test.x${MITRA_PID}
echo "\n **M_INFO   ** Chaining script test.x${MITRA_PID} updated for cycle $CYCLE \n" | tee -a ${LOG_MIT}
#
# count for job number (used for chaining submissions in test.x)
#
cd $cycle
typeset -Z3 seqn=0

#Environment variable ENV_MIT_SEQN can be used to set the "seqn" number to a number > 0
if [ "$ENV_MIT_SEQN" != "" ]
then
 typeset -Z3 seqn=$ENV_MIT_SEQN
fi
echo "\n **M_INFO   ** Historical log on file $LOG_FILE \n" | tee -a ${LOG_MIT}
echo "\n **M_INFO   ** Making scripts for validation \n" | tee -a ${LOG_MIT}



#---------------------------------------------------------------------------------------------------------
# 2. Preparation of all the scripts for validation 
#---------------------------------------------------------------------------------------------------------

nam_path=$(echo ${REF_NAMDIR}/${cycle} | sed -e 's/\//\\\//g' -e 's/\$/\\\$/g')
mitra_home=$(echo ${MITRA_HOME} | sed -e 's/\//\\\//g' -e 's/\$/\\\$/g')
#
echo "\n **M_INFO   ** Chaining validation jobs for cycle $CYCLE \n" | tee -a ${LOG_MIT}
#
# profiling of the validation business
#
echo "\n **M_INFO   ** Profiling of the validation read from $PRO_FILE \n" | tee -a ${LOG_MIT}


# Main loop for reading lines of PROFILE file and creating appropriated scripts in the same order of the PROFILE file
# -------------------------------------------------------------------------------------------------------------------

cat ../${PRO_FILE} | sed "s/\t/ /g" |
while read VAR1 VAR2
do
# add the possibility of comment lines in PROFILE file
  COMMENT=$(echo $VAR1 | cut -c1)
  if [ "$COMMENT" = '#' ]; then ; continue ; fi

  echo "               *-->$VAR1<-->$VAR2<--*" | tee -a ${LOG_MIT}
  VAR2=$(echo $VAR2 | sed -e 's/\//\\\//g' -e 's/\$/\\\$/g')

  CODE_JOB=$VAR1
  UL_MOWN=$VAR2

  # - Syntax is generally (maximal number of characters of identifier is 60):
  # if [ "$CODE_JOB" = 'identifier' ]                                                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "comment on 105 characters                                                                                " ; fi

  #---------------------------------------------------------------------------------------------------------------------
  # ===== LAM model light validation (small files) =====================================================================
  #---------------------------------------------------------------------------------------------------------------------

  # - Hydrostatic adiabatic E001 with Eulerian advection scheme (former AH1E)
  if [ "$CODE_JOB" = 'L3_FCST_HYD_EUL_VFD_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD euler; no DFI                                                                               "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_HYD_EUL_VFD_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD euler; DFI                                                                                  "  ; fi

  # - Hydrostatic adiabatic E001 with semi-lagrangian 3 time-level advection (former AH1S)
  if [ "$CODE_JOB" = 'L3_FCST_HYD_SL3_VFD_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl3tl; no DFI; VFD; no SLHD                                                                 "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_HYD_SL3_VFD_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl3tl; DFI; VFD; no SLHD                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_HYD_SL3_VFE_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl3tl; no DFI; VFE; no SLHD                                                                 "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_HYD_SL3_VFE_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl3tl; DFI; VFE; no SLHD                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_HYD_SL3_VFD_ADIAB_SLHD_PGAL' ]                          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl3tl; no DFI; VFD; SLHD                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_HYD_SL3_VFD_ADIAB_SLHD_PGAL' ]                          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl3tl; DFI; VFD; SLHD                                                                       "  ; fi

  # - Hydrostatic adiabatic E001 with semi-lagrangian 2 time-level advection (former AH1T)
  if [ "$CODE_JOB" = 'L3_FCST_HYD_SL2_VFD_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl; no DFI; VFD; no SLHD                                                                 "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_HYD_SL2_VFD_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl; DFI; VFD; no SLHD                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_HYD_SL2_VFE_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl; no DFI; VFE; no SLHD                                                                 "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_HYD_SL2_CVFE_ADIAB_PGAL' ]                              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl; no DFI; VFE; no SLHD; LVFE_COMPATIBLE=.TRUE.                                         "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_HYD_SL2_VFE_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl; DFI; VFE; no SLHD                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_HYD_SL2_VFD_ADIAB_SLHD_PGAL' ]                          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl; no DFI; VFD; SLHD                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_HYD_SL2_VFD_ADIAB_SLHD_PGAL' ]                          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl; DFI; VFD; SLHD                                                                       "  ; fi

  # - Hydrostatic adiabatic E501 with Eulerian advection scheme (former AH5E)
  if [ "$CODE_JOB" = 'L3_C501_HYD_EUL_VFD_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 501HYD euler; no DFI; VFD; no SLHD                                                                 "  ; fi

  # - Hydrostatic adiabatic E501 with semi-lagrangian 2 time-level advection scheme (former AH5T)
  if [ "$CODE_JOB" = 'L3_C501_HYD_SL2_VFD_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 501HYD sl2tl; no DFI; VFD; no SLHD                                                                 "  ; fi
  if [ "$CODE_JOB" = 'L3_C501_HYD_SL2_VFE_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 501HYD sl2tl; no DFI; VFE; no SLHD                                                                 "  ; fi

  # - Hydrostatic adiabatic E401 with Eulerian advection scheme (former AH4E)
  if [ "$CODE_JOB" = 'L3_C401_HYD_EUL_VFD_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 401HYD euler; no DFI; VFD; no SLHD                                                                 "  ; fi

  # - Hydrostatic adiabatic E401 with semi-lagrangian 2 time-level advection scheme (former AH4T)
  if [ "$CODE_JOB" = 'L3_C401_HYD_SL2_VFD_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 401HYD sl2tl; no DFI; VFD; no SLHD                                                                 "  ; fi
  if [ "$CODE_JOB" = 'L3_C401_HYD_SL2_VFE_ADIAB_PGAL' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 401HYD sl2tl; no DFI; VFE; no SLHD                                                                 "  ; fi

  # - Hydrostatic with Buizza physics E601 with Eulerian advection scheme (former AH6E)
  if [ "$CODE_JOB" = 'L3_C601_HYD_EUL_VFD_VSIPHY_PGAL' ]                              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 601HYD euler; no DFI; VFD; no SLHD                                                                 "  ; fi

  # - Hydrostatic with Buizza physics E601 with semi-lagrangian 2 time-level advection scheme (former AH6T)
  if [ "$CODE_JOB" = 'L3_C601_HYD_SL2_VFD_VSIPHY_PGAL' ]                              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 601HYD sl2tl; no DFI; VFD; no SLHD                                                                 "  ; fi
  if [ "$CODE_JOB" = 'L3_C601_HYD_SL2_VFE_VSIPHY_PGAL' ]                              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 601HYD sl2tl; no DFI; VFE; no SLHD                                                                 "  ; fi

  # - NHEE Non-hydrostatic adiabatic E001 with Eulerian advection scheme (former AN1E)
  if [ "$CODE_JOB" = 'L3_FCST_NHE_EUL_VFD_ADIAB_FROC' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE euler; no DFI; FullPCiter                                                                   "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHE_EUL_VFD_ADIAB_FROC' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE euler; DFI; FullPCiter                                                                      "  ; fi

  # - NHQE Non-hydrostatic adiabatic E001 with Eulerian advection scheme (former AN1E)
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_EUL_VFD_ADIAB_FROC' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ euler; no DFI; FullPCiter                                                                   "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHQ_EUL_VFD_ADIAB_FROC' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ euler; DFI; FullPCiter                                                                      "  ; fi

  # - NHEE Non-hydrostatic adiabatic E001 with semi-lagrangian 3 time-level advection scheme (former AN1S)
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL3_VFD_ADIAB_RDBBC2_FROC' ]                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl3tl; no DFI; SI; RDbbc; VFD                                                               "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHE_SL3_VFD_ADIAB_RDBBC2_FROC' ]                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl3tl; DFI; SI; RDbbc; VFD                                                                  "  ; fi

  # - NHQE Non-hydrostatic adiabatic E001 with semi-lagrangian 3 time-level advection scheme (former AN1S)
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL3_VFD_ADIAB_RDBBC2_FROC' ]                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl3tl; no DFI; SI; RDbbc; VFD                                                               "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHQ_SL3_VFD_ADIAB_RDBBC2_FROC' ]                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl3tl; DFI; SI; RDbbc; VFD                                                                  "  ; fi

  # - NHEE Non-hydrostatic adiabatic E001 with semi-lagrangian 2 time-level advection scheme (former AN1T)
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_ADIAB_RDBBC2_PCC_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl; no DFI; CheapPC; RDbbc; ND4SYS=2; VFD                                                "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHE_SL2_VFD_ADIAB_RDBBC2_PCC_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl; DFI; CheapPC; RDbbc; ND4SYS=2; VFD                                                   "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_ADIAB_RDBBC2_PCF_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl; no DFI; FullPC; RDbbc; ND4SYS=2; VFD                                                 "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHE_SL2_VFD_ADIAB_RDBBC2_PCF_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl; DFI; FullPC; RDbbc; ND4SYS=2; VFD                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCC_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl; no DFI; CheapPC; GWadv; ND4SYS=2; VFD                                                "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHE_SL2_VFD_ADIAB_GWADV2_PCC_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl; DFI; CheapPC; GWadv; ND4SYS=2; VFD                                                   "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCF_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl; no DFI; FullPC; GWadv; ND4SYS=2; VFD                                                 "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_ADIAB_GWADV5_PCF_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl; no DFI; FullPC; GWadv; ND4SYS=2; VFDR ; WENO                                         "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHE_SL2_VFD_ADIAB_GWADV2_PCF_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl; DFI; FullPC; GWadv; ND4SYS=2; VFD                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFE_ADIAB_GWADV2_PCF_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl; no DFI; FullPC; GWadv; ND4SYS=2; VFE                                                 "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_CVFE_ADIAB_GWADV2_PCF_FROC' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl; no DFI; FullPC; GWadv; ND4SYS=2; VFE; LVFE_COMPATIBLE=.TRUE.                         "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHE_SL2_VFE_ADIAB_GWADV2_PCF_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl; DFI; FullPC; GWadv; ND4SYS=2; VFE                                                    "  ; fi

  # - Additional NHEE Non-hydrostatic SL2TL semi-Lagrangian adiabatic configuration 001 (stretched-tilted) (former ANLY):
  #   Use LNHEE_SVDLAPL_FIRST=T and LSI_NHEE=T, will replace their GWADV2 counterpart in the future.
  if [ "$CODE_JOB" = 'L3_FCTI_NHE_SL2_VFD_ADIAB_NGWADV2_PCF_FROC' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl; DFI; FullPC; GWadv; ND4SYS=2; VFD; modern version                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHE_SL2_VFE_ADIAB_NGWADV2_PCF_FROC' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl; DFI; FullPC; GWadv; ND4SYS=2; VFE; modern version                                    "  ; fi

  # - NHQE Non-hydrostatic adiabatic E001 with semi-lagrangian 2 time-level advection scheme (former AN1T)
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_ADIAB_RDBBC2_PCC_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl; no DFI; CheapPC; RDbbc; ND4SYS=2; VFD                                                "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHQ_SL2_VFD_ADIAB_RDBBC2_PCC_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl; DFI; CheapPC; RDbbc; ND4SYS=2; VFD                                                   "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_ADIAB_RDBBC2_PCF_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl; no DFI; FullPC; RDbbc; ND4SYS=2; VFD                                                 "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHQ_SL2_VFD_ADIAB_RDBBC2_PCF_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl; DFI; FullPC; RDbbc; ND4SYS=2; VFD                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_ADIAB_GWADV2_PCC_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl; no DFI; CheapPC; GWadv; ND4SYS=2; VFD                                                "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHQ_SL2_VFD_ADIAB_GWADV2_PCC_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl; DFI; CheapPC; GWadv; ND4SYS=2; VFD                                                   "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_ADIAB_GWADV2_PCF_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl; no DFI; FullPC; GWadv; ND4SYS=2; VFD                                                 "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHQ_SL2_VFD_ADIAB_GWADV2_PCF_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl; DFI; FullPC; GWadv; ND4SYS=2; VFD                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFE_ADIAB_GWADV2_PCF_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl; no DFI; FullPC; GWadv; ND4SYS=2; VFE                                                 "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_NHQ_SL2_VFE_ADIAB_GWADV2_PCF_FROC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl; DFI; FullPC; GWadv; ND4SYS=2; VFE                                                    "  ; fi

  # - Hydrostatic 1D model E001 with semi-lagrangian 2 time-level advection scheme. ARPEGE-ALADIN physics (former AHUT)
  if [ "$CODE_JOB" = 'L1_FCST_HYD_SL2_VFD_ARPPHY1D' ]                                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD-1D sl2tl with ARPEGE/ALADIN physics; VFD                                                    "  ; fi

  # - Hydrostatic 1D model E001 with semi-lagrangian 2 time-level advection scheme. AROME physics (former ARUT)
  if [ "$CODE_JOB" = 'L1_FCST_HYD_SL2_VFD_AROPHY1D' ]                                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD-1D sl2tl with AROME physics; VFD                                                            "  ; fi

  # - Hydrostatic 2D model adiabatic E001 with semi-lagrangian 3 time-level advection scheme (former AH2S)
  if [ "$CODE_JOB" = 'L2_FCST_HYD_SL3_VFD_ADIAB' ]                                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD-2D sl3tl; no DFI; VFD                                                                       "  ; fi
  if [ "$CODE_JOB" = 'L2_FCTI_HYD_SL3_VFD_ADIAB' ]                                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD-2D sl3tl; DFI; VFD                                                                          "  ; fi

  # - Hydrostatic 2D model adiabatic E001 with semi-lagrangian 2 time-level advection scheme (former AH2T)
  if [ "$CODE_JOB" = 'L2_FCST_HYD_SL2_VFD_ADIAB' ]                                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD-2D sl2tl; no DFI; VFD                                                                       "  ; fi
  if [ "$CODE_JOB" = 'L2_FCTI_HYD_SL2_VFD_ADIAB' ]                                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD-2D sl2tl; DFI; VFD                                                                          "  ; fi

  # - NHEE Non-hydrostatic 2D model adiabatic E001 with Eulerian advection scheme (former AN2E)
  if [ "$CODE_JOB" = 'L2_FCST_NHE_EUL_VFD_ADIAB' ]                                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE-2D euler; no DFI; SI; VFD                                                                   "  ; fi

  # - NHQE Non-hydrostatic 2D model adiabatic E001 with Eulerian advection scheme (former AN2E)
  if [ "$CODE_JOB" = 'L2_FCST_NHQ_EUL_VFD_ADIAB' ]                                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ-2D euler; no DFI; SI; VFD                                                                   "  ; fi

  # - NHEE Non-hydrostatic 2D model adiabatic E001 with semi-lagrangian 3 time-level advection scheme (former AN2S)
  if [ "$CODE_JOB" = 'L2_FCST_NHE_SL3_VFD_ADIAB' ]                                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE-2D sl3tl; no DFI; SI; VFD                                                                   "  ; fi
  if [ "$CODE_JOB" = 'L2_FCTI_NHE_SL3_VFD_ADIAB' ]                                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE-2D sl3tl; DFI; SI; VFD                                                                      "  ; fi

  # - NHQE Non-hydrostatic 2D model adiabatic E001 with semi-lagrangian 3 time-level advection scheme (former AN2S)
  if [ "$CODE_JOB" = 'L2_FCST_NHQ_SL3_VFD_ADIAB' ]                                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ-2D sl3tl; no DFI; SI; VFD                                                                   "  ; fi
  if [ "$CODE_JOB" = 'L2_FCTI_NHQ_SL3_VFD_ADIAB' ]                                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ-2D sl3tl; DFI; SI; VFD                                                                      "  ; fi

  # - NHEE Non-hydrostatic 2D model adiabatic E001 with semi-lagrangian 2 time-level advection scheme (former AN2T)
  if [ "$CODE_JOB" = 'L2_FCST_NHE_SL2_VFD_ADIAB_RDBBC2_PCF_SETTLS' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE-2D sl2tl; no DFI; FullPC with SETTLS; RDbbc; ND4SYS=2; VFD                                  "  ; fi
  if [ "$CODE_JOB" = 'L2_FCTI_NHE_SL2_VFD_ADIAB_RDBBC2_PCF_SETTLS' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE-2D sl2tl; DFI; FullPC with SETTLS; RDbbc; ND4SYS=2; VFD                                     "  ; fi
  if [ "$CODE_JOB" = 'L2_FCST_NHE_SL2_VFD_ADIAB_RDBBC2_PCF_NESC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE-2D sl2tl; no DFI; FullPC with NESC; RDbbc; ND4SYS=2; VFD                                    "  ; fi
  if [ "$CODE_JOB" = 'L2_FCTI_NHE_SL2_VFD_ADIAB_RDBBC2_PCF_NESC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE-2D sl2tl; DFI; FullPC with NESC; RDbbc; ND4SYS=2; VFD                                       "  ; fi
  if [ "$CODE_JOB" = 'L2_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCF_NESC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE-2D sl2tl; no DFI; FullPC with NESC; GWadv; ND4SYS=2; VFD                                    "  ; fi
  if [ "$CODE_JOB" = 'L2_FCTI_NHE_SL2_VFD_ADIAB_GWADV2_PCF_NESC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE-2D sl2tl; DFI; FullPC with NESC; GWadv; ND4SYS=2; VFD                                       "  ; fi

  # - NHQE Non-hydrostatic 2D model adiabatic E001 with semi-lagrangian 2 time-level advection scheme (former AN2T)
  if [ "$CODE_JOB" = 'L2_FCST_NHQ_SL2_VFD_ADIAB_RDBBC2_PCF_SETTLS' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ-2D sl2tl; no DFI; FullPC with SETTLS; RDbbc; ND4SYS=2; VFD                                  "  ; fi
  if [ "$CODE_JOB" = 'L2_FCTI_NHQ_SL2_VFD_ADIAB_RDBBC2_PCF_SETTLS' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ-2D sl2tl; DFI; FullPC with SETTLS; RDbbc; ND4SYS=2; VFD                                     "  ; fi
  if [ "$CODE_JOB" = 'L2_FCST_NHQ_SL2_VFD_ADIAB_RDBBC2_PCF_NESC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ-2D sl2tl; no DFI; FullPC with NESC; RDbbc; ND4SYS=2; VFD                                    "  ; fi
  if [ "$CODE_JOB" = 'L2_FCTI_NHQ_SL2_VFD_ADIAB_RDBBC2_PCF_NESC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ-2D sl2tl; DFI; FullPC with NESC; RDbbc; ND4SYS=2; VFD                                       "  ; fi
  if [ "$CODE_JOB" = 'L2_FCST_NHQ_SL2_VFD_ADIAB_GWADV2_PCF_NESC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ-2D sl2tl; no DFI; FullPC with NESC; GWadv; ND4SYS=2; VFD                                    "  ; fi
  if [ "$CODE_JOB" = 'L2_FCTI_NHQ_SL2_VFD_ADIAB_GWADV2_PCF_NESC' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ-2D sl2tl; DFI; FullPC with NESC; GWadv; ND4SYS=2; VFD                                       "  ; fi

  #---------------------------------------------------------------------------------------------------------------------
  # ===== LAM model light validation (fullpos) =========================================================================
  #---------------------------------------------------------------------------------------------------------------------

  # - Off-line FULLPOS; 927-like; Hydrostatic model (former AH9E)
  if [ "$CODE_JOB" = 'L3_FPOF_HYD_SPLELAM_ARUNES' ]                                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD EE927-NFPOS2 ARUNES                                                                         "  ; fi

  # - Full-POS tests (former AHFE):
  if [ "$CODE_JOB" = 'L3_FPOF_HYD_MODEL' ]                                            ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 903HYD FPOS MOD; LELAM=T; CFPFMT=MODEL; OFF-LINE                                                   "  ; fi
  if [ "$CODE_JOB" = 'L3_FPOF_HYD_GPLELAM_CI_GRI1' ]                                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 903HYD FPOS GRI1; LELAM=T; CFPFMT=LELAM; C+I; OFF-LINE                                             "  ; fi
  if [ "$CODE_JOB" = 'L3_FPOF_HYD_GPLELAM_CI_GRI2' ]                                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 903HYD FPOS GRI2; LELAM=T; CFPFMT=LELAM; C+I; OFF-LINE                                             "  ; fi
  if [ "$CODE_JOB" = 'L3_FPOF_HYD_GPLALON_LAL' ]                                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 903HYD FPOS LAL; LELAM=T; CFPFMT=LALON; OFF-LINE                                                   "  ; fi
  if [ "$CODE_JOB" = 'L3_FPOF_HYD_GPLELAM_CIE_LAM1' ]                                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 903HYD FPOS LAM1; LELAM=T; CFPFMT=LELAM; C+I+E; OFF-LINE                                           "  ; fi
  if [ "$CODE_JOB" = 'L3_FPOF_HYD_GPLALON_OPE2_ARPPHYISBA' ]                          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS OPE2; LELAM=T; CFPFMT=LALON; OFF-LINE                                                  "  ; fi
  if [ "$CODE_JOB" = 'L3_FPOF_HYD_GPLELAM_CI_OPEX' ]                                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS OPEX; LELAM=T; CFPFMT=LELAM; C+I; OFF-LINE                                             "  ; fi
  if [ "$CODE_JOB" = 'L3_FPIN_HYD_MODEL_ARPPHYISBA' ]                                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS INL; LELAM=T; CFPFMT=MODEL; IN-LINE                                                    "  ; fi

  #---------------------------------------------------------------------------------------------------------------------
  # ===== LAM model complementary validation ===========================================================================
  #---------------------------------------------------------------------------------------------------------------------

  # - Testing Incrimental DFI with SL2TL advection scheme (former AGIT):
  if [ "$CODE_JOB" = 'L3_FCTI_HYD_SL2_VFE_ARPPHYISBA_TSTDFI_FRAN' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl (IDFI test); DFI                                                                      "  ; fi

  # - Hydrostatic oper-type of E001 (2TLSL+oper physics) (former AG1T):
  if [ "$CODE_JOB" = 'L3_FCTI_HYD_SL2_VFE_ARPPHYSFEX_FRAN' ]                          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl (cf. oper); DFI                                                                       "  ; fi

  # - Hydrostatic LACE-ALARO-type of E001 (2TLSL+ALARO physics) (former AA1T):
  if [ "$CODE_JOB" = 'L3_FCTI_HYD_SL2_VFD_ALRPHYISBA_OLDLACE' ]                       ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl (cf. ALARO old version); DFI                                                          "  ; fi
  if [ "$CODE_JOB" = 'L3_FCTI_HYD_SL2_VFE_ALRPHYISBA_LACE' ]                          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl (cf. ALARO recent version); DFI                                                       "  ; fi

  # - Hydrostatic rotated Mercator GRANLMRT domain E001 (12 hour+2TLSL+oper physics) (former AC1T):
  if [ "$CODE_JOB" = 'L3_FCTI_HYD_SL2_VFE_ARPPHYISBA_GRANLMRT' ]                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl (rot. Mercator GRANLMRT); DFI                                                         "  ; fi

  # - NHEE Non-hydrostatic rotated Mercator GRANLMRT domain E001 (12 hour+2TLSL+oper physics) (former AC1U):
  if [ "$CODE_JOB" = 'L3_FCTI_NHE_SL2_VFD_ARPPHYISBA_GRANLMRT' ]                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (rot. Mercator GRANLMRT); DFI                                                         "  ; fi

  # - NHQE Non-hydrostatic rotated Mercator GRANLMRT domain E001 (12 hour+2TLSL+oper physics) (former AC1U):
  if [ "$CODE_JOB" = 'L3_FCTI_NHQ_SL2_VFD_ARPPHYISBA_GRANLMRT' ]                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (rot. Mercator GRANLMRT); DFI                                                         "  ; fi

  # - NH and HYD AROME E001 with physics (former AR1T):
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCCMAD_AROMALP1300' ]     ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (cf. AROME); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD                        "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCC_AROMALP1300' ]        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (cf. AROME); no DFI; CheapPC with NESC; GWadv; ND4SYS=2                               "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCF_AROMALP1300' ]        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (cf. AROME); no DFI; FullPC with NESC; GWadv; ND4SYS=2                                "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_HYD_SL2_VFD_AROPHYSFEX_MAD_AROMALP1300' ]               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl (cf. AROME); no DFI; SI with SETTLS; COMAD                                            "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_HYD_SL2_VFD_AROPHYSFEX_AROMALP1300' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl (cf. AROME); no DFI; SI with SETTLS                                                   "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_HYD_SL2_VFD_AROPHYSFEX_REST_AROMALP1300' ]              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl (cf. AROME); no DFI; SI with SETTLS; restart                                          "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCCMADIOS_AROMALP1300' ]  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (cf. AROME); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD; io_server             "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCCMADIOSH_AROMALP1300' ] ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (cf. AROME); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD; io_server; FlexDDH    "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCFMAD_AROMALP1300' ]     ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (cf. AROME); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD                         "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCFMADIOS_AROMALP1300' ]  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (cf. AROME); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD; io_server              "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_AROPHYSFEX_GWADV2_PCCMAD_AROMALP1300' ]     ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (cf. AROME); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD                        "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_AROPHYSFEX_GWADV2_PCC_AROMALP1300' ]        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (cf. AROME); no DFI; CheapPC with NESC; GWadv; ND4SYS=2                               "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_AROPHYSFEX_GWADV2_PCF_AROMALP1300' ]        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (cf. AROME); no DFI; FullPC with NESC; GWadv; ND4SYS=2                                "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_AROPHYSFEX_GWADV2_PCCMADIOS_AROMALP1300' ]  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (cf. AROME); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD; io_server             "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_AROPHYSFEX_GWADV2_PCFMAD_AROMALP1300' ]     ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (cf. AROME); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD                         "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_AROPHYSFEX_GWADV2_PCFMADIOS_AROMALP1300' ]  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (cf. AROME); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD; io_server              "  ; fi

  # - Conf E923 / clim files preparation (former AXCX):
  if [ "$CODE_JOB" = 'L3_C923_LELAM_LACE' ]                                           ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LELAM_LACE                                                                         "  ; fi
  if [ "$CODE_JOB" = 'L3_C923_LELAM_FRANCE' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LELAM_FRANCE                                                                       "  ; fi
  if [ "$CODE_JOB" = 'L3_C923_LELAM_REUNION' ]                                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LELAM_REUNION                                                                      "  ; fi
  if [ "$CODE_JOB" = 'L3_C923_LALON_FRANX01' ]                                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LALON_FRANX01                                                                      "  ; fi

  # - Makepgd / make PGD file for AROME (former AXSY):
  if [ "$CODE_JOB" = 'L3_PGDI_LELAM_FRANCE' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD file for AROME LELAM_FRANCE                                                                    "  ; fi

  #---------------------------------------------------------------------------------------------------------------------
  # ===== LAM model: make AROME climatologies ==========================================================================
  #---------------------------------------------------------------------------------------------------------------------

  # - Make model climatologies for AROME (domain OCCITANIE-250m):
  if [ "$CODE_JOB" = 'L3_PGDI_LELAM_OC0250' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD file for AROME LELAM_OC0250                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_C923_LELAM_OC0250' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LELAM_OC0250                                                                       "  ; fi
  if [ "$CODE_JOB" = 'L3_PGDS_LELAM_OC0250' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD-S file for AROME LELAM_OC0250                                                                  "  ; fi
  if [ "$CODE_JOB" = 'L3_PGDC_LELAM_OC0250' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "convert PGD LFI to FA for AROME LELAM_OC0250                                                            "  ; fi

  # - Make model climatologies for AROME (domain OCCITANIE-275m):
  if [ "$CODE_JOB" = 'L3_PGDI_LELAM_OC0275' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD file for AROME LELAM_OC0275                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_C923_LELAM_OC0275' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LELAM_OC0275                                                                       "  ; fi
  if [ "$CODE_JOB" = 'L3_PGDS_LELAM_OC0275' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD-S file for AROME LELAM_OC0275                                                                  "  ; fi
  if [ "$CODE_JOB" = 'L3_PGDC_LELAM_OC0275' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "convert PGD LFI to FA for AROME LELAM_OC0275                                                            "  ; fi

  # - Make model climatologies for AROME (domain OCCITANIE-375m):
  if [ "$CODE_JOB" = 'L3_PGDI_LELAM_OC0375' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD file for AROME LELAM_OC0375                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_C923_LELAM_OC0375' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LELAM_OC0375                                                                       "  ; fi
  if [ "$CODE_JOB" = 'L3_PGDS_LELAM_OC0375' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD-S file for AROME LELAM_OC0375                                                                  "  ; fi
  if [ "$CODE_JOB" = 'L3_PGDC_LELAM_OC0375' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "convert PGD LFI to FA for AROME LELAM_OC0375                                                            "  ; fi

  # - Make model climatologies for AROME (domain OCCITANIE-500m):
  if [ "$CODE_JOB" = 'L3_PGDI_LELAM_OC0500' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD file for AROME LELAM_OC0500                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_C923_LELAM_OC0500' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LELAM_OC0500                                                                       "  ; fi
  if [ "$CODE_JOB" = 'L3_PGDS_LELAM_OC0500' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD-S file for AROME LELAM_OC0500                                                                  "  ; fi
  if [ "$CODE_JOB" = 'L3_PGDC_LELAM_OC0500' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "convert PGD LFI to FA for AROME LELAM_OC0500                                                            "  ; fi

  # - Make model climatologies for AROME (domain OCCITANIE-750m):
  if [ "$CODE_JOB" = 'L3_PGDI_LELAM_OC0750' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD file for AROME LELAM_OC0750                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_C923_LELAM_OC0750' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LELAM_OC0750                                                                       "  ; fi
  if [ "$CODE_JOB" = 'L3_PGDS_LELAM_OC0750' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD-S file for AROME LELAM_OC0750                                                                  "  ; fi
  if [ "$CODE_JOB" = 'L3_PGDC_LELAM_OC0750' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "convert PGD LFI to FA for AROME LELAM_OC0750                                                            "  ; fi

  # - Make model climatologies for AROME (domain OCCITANIE-1000m):
  if [ "$CODE_JOB" = 'L3_PGDI_LELAM_OC1000' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD file for AROME LELAM_OC1000                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_C923_LELAM_OC1000' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LELAM_OC1000                                                                       "  ; fi
  if [ "$CODE_JOB" = 'L3_PGDS_LELAM_OC1000' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD-S file for AROME LELAM_OC1000                                                                  "  ; fi
  if [ "$CODE_JOB" = 'L3_PGDC_LELAM_OC1000' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "convert PGD LFI to FA for AROME LELAM_OC1000                                                            "  ; fi

  # - Make model climatologies for AROME (domain OCCITANIE-1300m):
  if [ "$CODE_JOB" = 'L3_PGDI_LELAM_OC1300' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD file for AROME LELAM_OC1300                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_C923_LELAM_OC1300' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LELAM_OC1300                                                                       "  ; fi
  if [ "$CODE_JOB" = 'L3_PGDS_LELAM_OC1300' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD-S file for AROME LELAM_OC1300                                                                  "  ; fi
  if [ "$CODE_JOB" = 'L3_PGDC_LELAM_OC1300' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "convert PGD LFI to FA for AROME LELAM_OC1300                                                            "  ; fi

  # - Make BDAP climatologies for AROME (domain OCCITANIE-500m):
  if [ "$CODE_JOB" = 'L3_PGDI_LALON_OC0500' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD file for AROME LALON_OC0500                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_C923_LALON_OC0500' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LALON_OC0500                                                                       "  ; fi

  # - Make BDAP climatologies for AROME (domain OCCITANIE-750m):
  if [ "$CODE_JOB" = 'L3_PGDI_LALON_OC0750' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD file for AROME LALON_OC0750                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_C923_LALON_OC0750' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LALON_OC0750                                                                       "  ; fi

  # - Make BDAP climatologies for AROME (domain OCCITANIE-1000m):
  if [ "$CODE_JOB" = 'L3_PGDI_LALON_OC1000' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD file for AROME LALON_OC1000                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_C923_LALON_OC1000' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LALON_OC1000                                                                       "  ; fi

  # - Make BDAP climatologies for AROME (domain OCCITANIE-1300m):
  if [ "$CODE_JOB" = 'L3_PGDI_LALON_OC1300' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD file for AROME LALON_OC1300                                                                    "  ; fi
  if [ "$CODE_JOB" = 'L3_C923_LALON_OC1300' ]                                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf E923; make clim LALON_OC1300                                                                       "  ; fi

  #---------------------------------------------------------------------------------------------------------------------
  # ===== LAM model addenda    =========================================================================================
  #---------------------------------------------------------------------------------------------------------------------

  # - NH and HYD AROME E001 with physics (domain OCCITANIE-250m):
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCCMAD_AROMOC0250' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (AROME OC0250); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD                     "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCFMAD_AROMOC0250' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (AROME OC0250); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD                      "  ; fi

  # - NH and HYD AROME E001 with physics (domain OCCITANIE-275m):
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCCMAD_AROMOC0275' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (AROME OC0275); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD                     "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCFMAD_AROMOC0275' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (AROME OC0275); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD                      "  ; fi

  # - NH and HYD AROME E001 with physics (domain OCCITANIE-375m):
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCCMAD_AROMOC0375' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (AROME OC0375); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD                     "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCFMAD_AROMOC0375' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (AROME OC0375); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD                      "  ; fi

  # - NH and HYD AROME E001 with physics (domain OCCITANIE-500m):
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCCMAD_AROMOC0500' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (AROME OC0500); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD                     "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCFMAD_AROMOC0500' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (AROME OC0500); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD                      "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_AROPHYSFEX_GWADV2_PCCMAD_AROMOC0500' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (AROME OC0500); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD                     "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_AROPHYSFEX_GWADV2_PCFMAD_AROMOC0500' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (AROME OC0500); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD                      "  ; fi

  # - NH and HYD AROME E001 with physics (domain OCCITANIE-750m):
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCCMAD_AROMOC0750' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (AROME OC0750); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD                     "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCFMAD_AROMOC0750' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (AROME OC0750); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD                      "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_AROPHYSFEX_GWADV2_PCCMAD_AROMOC0750' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (AROME OC0750); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD                     "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_AROPHYSFEX_GWADV2_PCFMAD_AROMOC0750' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (AROME OC0750); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD                      "  ; fi

  # - NH and HYD AROME E001 with physics (domain OCCITANIE-1000m):
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCCMAD_AROMOC1000' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (AROME OC1000); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD                     "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCFMAD_AROMOC1000' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (AROME OC1000); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD                      "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_AROPHYSFEX_GWADV2_PCCMAD_AROMOC1000' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (AROME OC1000); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD                     "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_AROPHYSFEX_GWADV2_PCFMAD_AROMOC1000' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (AROME OC1000); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD                      "  ; fi

  # - NH and HYD AROME E001 with physics (domain OCCITANIE-1300m):
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCCMAD_AROMOC1300' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (AROME OC1300); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD                     "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHE_SL2_VFD_AROPHYSFEX_GWADV2_PCFMAD_AROMOC1300' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl (AROME OC1300); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD                      "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_AROPHYSFEX_GWADV2_PCCMAD_AROMOC1300' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (AROME OC1300); no DFI; CheapPC with NESC; GWadv; ND4SYS=2; COMAD                     "  ; fi
  if [ "$CODE_JOB" = 'L3_FCST_NHQ_SL2_VFD_AROPHYSFEX_GWADV2_PCFMAD_AROMOC1300' ]      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl (AROME OC1300); no DFI; FullPC with NESC; GWadv; ND4SYS=2; COMAD                      "  ; fi

  #---------------------------------------------------------------------------------------------------------------------
  # ===== Global model light validation ECO ============================================================================
  #---------------------------------------------------------------------------------------------------------------------

  # - Hydrostatic eulerian adiabatic configuration 001 (former AHEA):
  if [ "$CODE_JOB" = 'GM_FCST_HYD_EUL_VFD_ADIAB_TL031U' ]                             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD euler adiab TL031L15c1; no DFI                                                              "  ; fi

  # - Hydrostatic SL3TL semi-lagrangian adiabatic configuration 001 (former AHSA):
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL3_VFD_ADIAB_TL031U' ]                             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl3tl adiab TL031L15c1; no DFI                                                              "  ; fi

  # - Hydrostatic SL2TL semi-lagrangian adiabatic configuration 001 (former AHLA):
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_EXTCLA_VESL_TL031U' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL031L15c1; no DFI; classic extrapol; VESL                                      "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_VESL_TL031U' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL031L15c1; no DFI; SETTLS; VESL                                                "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_EXTCLA_XIDT_TL031U' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL031L15c1; no DFI; classic extrapol; XIDT                                      "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_TL031U' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL031L15c1; no DFI; SETTLS; XIDT                                                "  ; fi

  # - Hydrostatic eulerian adiabatic configuration 001 (stretched-tilted) (former AHEH):
  if [ "$CODE_JOB" = 'GM_FCST_HYD_EUL_VFD_ADIAB_TL030S' ]                             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD euler adiab TL030L15c2.4; no DFI                                                            "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_EUL_VFD_ADIAB_TL030S' ]                             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD euler adiab TL030L15c2.4; DFI                                                               "  ; fi

  # - Hydrostatic SL3TL semi-Lagrangian adiabatic configuration 001 (stretched-tilted) (former AHSH):
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL3_VFD_ADIAB_TL030S' ]                             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl3tl adiab TL030L15c2.4; no DFI                                                            "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL3_VFD_ADIAB_TL030S' ]                             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl3tl adiab TL030L15c2.4; DFI                                                               "  ; fi

  # - Hydrostatic SL2TL semi-Lagrangian adiabatic configuration 001 (stretched-tilted) (former AHLH):
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_EXTCLA_VESL_TL030S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; classic extrapol; VESL; VFD                               "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFD_ADIAB_EXTCLA_VESL_TL030S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; classic extrapol; VESL; VFD                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_VESL_TL030S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; SETTLS; VESL; VFD                                         "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFD_ADIAB_SETTLS_VESL_TL030S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; SETTLS; VESL; VFD                                            "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_EXTCLA_XIDT_TL030S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; classic extrapol; XIDT; VFD                               "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFD_ADIAB_EXTCLA_XIDT_TL030S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; classic extrapol; XIDT; VFD                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_TL030S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; SETTLS; XIDT; VFD                                         "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_TL030S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; SETTLS; XIDT; VFD                                            "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_RW2TLFF_TL030S' ]         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; SETTLS; XIDT; VFD; RW2TLFF=1                              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_RW2TLFF_TL030S' ]         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; SETTLS; XIDT; VFD; RW2TLFF=1                                 "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFE_ADIAB_SETTLS_NDEC_TL030S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; SETTLS; VFE                                               "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ADIAB_SETTLS_NDEC_TL030S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; SETTLS; VFE                                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_RVFE_ADIAB_SETTLS_NDEC_TL030S' ]                ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; SETTLS; RVFE                                              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_RVFE_ADIAB_SETTLS_NDEC_TL030S' ]                ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; SETTLS; RVFE                                                 "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_NDPSFI_TL030S' ]          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; SETTLS; XIDT; VFD; NDPSFI=1                               "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_NDPSFI_TL030S' ]          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; SETTLS; XIDT; VFD; NDPSFI=1                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_SPRTSPQ_TL030S' ]         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; SETTLS; XIDT; VFD; SPRTSPQ                                "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_SPRTSPQ_TL030S' ]         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; SETTLS; XIDT; VFD; SPRTSPQ                                   "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_SPRTGPQ_TL030S' ]         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; SETTLS; XIDT; VFD; SPRTGPQ                                "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_SPRTGPQ_TL030S' ]         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; SETTLS; XIDT; VFD; SPRTGPQ                                   "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_MSLHD_TL030S' ]           ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; SETTLS; XIDT; VFD; MSLHD                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_MSLHD_TL030S' ]           ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; SETTLS; XIDT; VFD; MSLHD                                     "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_SSLHD_TL030S' ]           ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; SETTLS; XIDT; VFD; SSLHD                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_SSLHD_TL030S' ]           ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; SETTLS; XIDT; VFD; SSLHD                                     "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_OSLHD_TL030S' ]           ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; SETTLS; XIDT; VFD; old SLHD                               "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_OSLHD_TL030S' ]           ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; SETTLS; XIDT; VFD; old SLHD                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_SLHD_TL030S' ]            ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; SETTLS; XIDT; VFD; SLHD                                   "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFD_ADIAB_SETTLS_XIDT_SLHD_TL030S' ]            ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; SETTLS; XIDT; VFD; SLHD                                      "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_PCF_NDEC_TL030S' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; FullPc; VFD                                               "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFD_ADIAB_PCF_NDEC_TL030S' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; FullPc; VFD                                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFE_ADIAB_SETTLS_NDEC_RW2TLFF_RFRIC_TL030S' ]   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; no DFI; SETTLS; VFE; RW2TLFF=1; RFRIC                             "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ADIAB_SETTLS_NDEC_RW2TLFF_RFRIC_TL030S' ]   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab TL030L15c2.4; DFI; SETTLS; VFE; RW2TLFF=1; RFRIC                                "  ; fi

  # - Hydrostatic eulerian diabatic configuration 001 (stretched-tilted) (former MHEH)
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_EUL_VFD_ARPPHYISBA_TL030S' ]                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD euler diab TL030L15c2.4; DFI                                                                "  ; fi

  # - Hydrostatic SL3TL semi-Lagrangian diabatic configuration 001 (stretched-tilted) (former MHSH):
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL3_VFD_ARPPHYISBA_TL030S' ]                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl3tl diab TL030L15c2.4; DFI                                                                "  ; fi

  # - Hydrostatic SL2TL semi-Lagrangian diabatic configuration 001 (stretched-tilted) (former MHLH):
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ARPPHYISBA_SETTLS_NDEC_TL030S' ]            ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl diab TL030L15c2.4; DFI; SETTLS; VFE                                                   "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2RK_VFE_ARPPHYISBA_TL107U' ]                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl diab TL107L70c1; no DFI; VFE; no SLHD; RK4                                            "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFE_ARPPHYISBA_WENO_TL107U' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl diab TL107L70c1; no DFI; VFE; no SLHD; WENO options                                   "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFE_ARPPHYISBA_WENO_CONS_TL107U' ]              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl diab TL107L70c1; no DFI; VFE; no SLHD; WENO and LQM3DCONS=.TRUE.                      "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFD_ARPPHYISBA_SETTLS_XIDT_NDPSFI_TL030S' ]     ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl diab TL030L15c2.4; DFI; SETTLS; XIDT; VFD; NDPSFI=1                                   "  ; fi

  # - IFS Hydrostatic SL2TL semi-Lagrangian diabatic configuration 001 (unstretched) :
  if [ "$CODE_JOB" = 'GE_FCST_HYD_SL2_VFD_ECPHY_SI_TCO399' ]                          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf IFS 001HYD sl2tl diab TCO399; no DFI; VFD; no SLHD                                                 "  ; fi
  if [ "$CODE_JOB" = 'GE_FCST_HYD_SL2_VFE_ECPHY_SLRK_TCO399' ]                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf IFS 001HYD sl2tl diab TCO399; no DFI; VFE; no SLHD; SLRK                                           "  ; fi
  if [ "$CODE_JOB" = 'GE_FCST_HYD_SL2_VFE_ECPHY_SLXYZ_TCO399' ]                       ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf IFS 001HYD sl2tl diab TCO399; no DFI; VFE; no SLHD; SLXYZ standard IFS                             "  ; fi
  if [ "$CODE_JOB" = 'GE_FCST_HYD_SL2_VFD_ECPHY_NCOR_TCO399' ]                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf IFS 001HYD sl2tl diab TCO399; no DFI; VFD; no SLHD; NCOR                                           "  ; fi
  if [ "$CODE_JOB" = 'GE_FCST_HYD_SL2_VFD_ADIAB_SLXYZ_SPLIT_TCO399' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf IFS 001HYD sl2tl adiab TCO399; no DFI; VFD; no SLHD; LVERTFE=.FALSE., LSLONDEM_SPLIT=.true.        "  ; fi

  # - NHEE Non-hydrostatic eulerian adiabatic configuration 001 (stretched-tilted) (former ANEY):
  if [ "$CODE_JOB" = 'GM_FCST_NHE_EUL_VFD_ADIAB_SI_TL030S' ]                          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE euler adiab TL030L15c2.4; no DFI; SI; VFD                                                   "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_EUL_VFD_ADIAB_SI_TL030S' ]                          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE euler adiab TL030L15c2.4; DFI; SI; VFD                                                      "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_EUL_VFD_ADIAB_PCF_TL030S' ]                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE euler adiab TL030L15c2.4; no DFI; FullPc; VFD                                               "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_EUL_VFD_ADIAB_PCF_TL030S' ]                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE euler adiab TL030L15c2.4; DFI; FullPc; VFD                                                  "  ; fi

  # - NHQE Non-hydrostatic eulerian adiabatic configuration 001 (stretched-tilted) (former ANEY):
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_EUL_VFD_ADIAB_SI_TL030S' ]                          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ euler adiab TL030L15c2.4; no DFI; SI; VFD                                                   "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_EUL_VFD_ADIAB_SI_TL030S' ]                          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ euler adiab TL030L15c2.4; DFI; SI; VFD                                                      "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_EUL_VFD_ADIAB_PCF_TL030S' ]                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ euler adiab TL030L15c2.4; no DFI; FullPc; VFD                                               "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_EUL_VFD_ADIAB_PCF_TL030S' ]                         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ euler adiab TL030L15c2.4; DFI; FullPc; VFD                                                  "  ; fi

  # - NHEE Non-hydrostatic SL3TL semi-Lagrangian adiabatic configuration 001 (stretched-tilted) (former ANSY):
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL3_VFD_ADIAB_RDBBC2_TL030S' ]                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl3tl adiab TL030L15c2.4; no DFI; SI; RDbbc; VFD                                            "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_SL3_VFD_ADIAB_RDBBC2_TL030S' ]                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl3tl adiab TL030L15c2.4; DFI; SI; RDbbc; VFD                                               "  ; fi

  # - NHQE Non-hydrostatic SL3TL semi-Lagrangian adiabatic configuration 001 (stretched-tilted) (former ANSY):
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL3_VFD_ADIAB_RDBBC2_TL030S' ]                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl3tl adiab TL030L15c2.4; no DFI; SI; RDbbc; VFD                                            "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_SL3_VFD_ADIAB_RDBBC2_TL030S' ]                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl3tl adiab TL030L15c2.4; DFI; SI; RDbbc; VFD                                               "  ; fi

  # - NHEE Non-hydrostatic SL2TL semi-Lagrangian adiabatic configuration 001 (stretched-tilted) (former ANLY):
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_RDBBC2_SI_TL030S' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; no DFI; SI; RDbbc; ND4SYS=2; VFD                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_SL2_VFD_ADIAB_RDBBC2_SI_TL030S' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; DFI; SI; RDbbc; ND4SYS=2; VFD                                     "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_RDBBC2_PCF_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; no DFI; FullPc; RDbbc; ND4SYS=2; VFD                              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_SL2_VFD_ADIAB_RDBBC2_PCF_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; DFI; FullPc; RDbbc; ND4SYS=2; VFD                                 "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_RDBBC2_PCC_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; no DFI; CheapPc; RDbbc; ND4SYS=2; VFD                             "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_SL2_VFD_ADIAB_RDBBC2_PCC_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; DFI; CheapPc; RDbbc; ND4SYS=2; VFD                                "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_GWADV2_SI_TL030S' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; no DFI; SI; GWadv; ND4SYS=2; VFD                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_GWADV5_SI_TL030S' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; no DFI; SI; GWadv; NVDVAR=5, ND4SYS=2; VFD                        "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_SL2_VFD_ADIAB_GWADV2_SI_TL030S' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; DFI; SI; GWadv; ND4SYS=2; VFD                                     "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCF_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; no DFI; FullPc; GWadv; ND4SYS=2; VFD                              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_SL2_VFD_ADIAB_GWADV2_PCF_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; DFI; FullPc; GWadv; ND4SYS=2; VFD                                 "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCC_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; no DFI; CheapPc; GWadv; ND4SYS=2; VFD                             "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_SL2_VFD_ADIAB_GWADV2_PCC_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; DFI; CheapPc; GWadv; ND4SYS=2; VFD                                "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFE_ADIAB_GWADV2_PCF_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; no DFI; FullPc; GWadv; ND4SYS=2; VFE                              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_SL2_VFE_ADIAB_GWADV2_PCF_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; DFI; FullPc; GWadv; ND4SYS=2; VFE                                 "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFE_ADIAB_GWADV2_PCC_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; no DFI; CheapPc; GWadv; ND4SYS=2; VFE                             "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_SL2_VFE_ADIAB_GWADV2_PCC_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; DFI; CheapPc; GWadv; ND4SYS=2; VFE                                "  ; fi

  # - Additional NHEE Non-hydrostatic SL2TL semi-Lagrangian adiabatic configuration 001 (stretched-tilted) (former ANLY):
  #   Use LNHEE_SVDLAPL_FIRST=T and LSI_NHEE=T, will replace their GWADV2 counterpart in the future.
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_SL2_VFD_ADIAB_NGWADV2_PCF_TL030S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; DFI; FullPc; GWadv; ND4SYS=2; VFD; modern version                 "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_SL2_VFE_ADIAB_NGWADV2_PCF_TL030S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab TL030L15c2.4; DFI; FullPc; GWadv; ND4SYS=2; VFE; modern version                 "  ; fi

  # - NHQE Non-hydrostatic SL2TL semi-Lagrangian adiabatic configuration 001 (stretched-tilted) (former ANLY):
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFD_ADIAB_RDBBC2_SI_TL030S' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; no DFI; SI; RDbbc; ND4SYS=2; VFD                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_SL2_VFD_ADIAB_RDBBC2_SI_TL030S' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; DFI; SI; RDbbc; ND4SYS=2; VFD                                     "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFD_ADIAB_RDBBC2_PCF_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; no DFI; FullPc; RDbbc; ND4SYS=2; VFD                              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_SL2_VFD_ADIAB_RDBBC2_PCF_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; DFI; FullPc; RDbbc; ND4SYS=2; VFD                                 "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFD_ADIAB_RDBBC2_PCC_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; no DFI; CheapPc; RDbbc; ND4SYS=2; VFD                             "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_SL2_VFD_ADIAB_RDBBC2_PCC_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; DFI; CheapPc; RDbbc; ND4SYS=2; VFD                                "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFD_ADIAB_GWADV2_SI_TL030S' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; no DFI; SI; GWadv; ND4SYS=2; VFD                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_SL2_VFD_ADIAB_GWADV2_SI_TL030S' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; DFI; SI; GWadv; ND4SYS=2; VFD                                     "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFD_ADIAB_GWADV2_PCF_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; no DFI; FullPc; GWadv; ND4SYS=2; VFD                              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_SL2_VFD_ADIAB_GWADV2_PCF_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; DFI; FullPc; GWadv; ND4SYS=2; VFD                                 "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFD_ADIAB_GWADV2_PCC_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; no DFI; CheapPc; GWadv; ND4SYS=2; VFD                             "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_SL2_VFD_ADIAB_GWADV2_PCC_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; DFI; CheapPc; GWadv; ND4SYS=2; VFD                                "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFE_ADIAB_GWADV2_PCF_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; no DFI; FullPc; GWadv; ND4SYS=2; VFE                              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_SL2_VFE_ADIAB_GWADV2_PCF_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; DFI; FullPc; GWadv; ND4SYS=2; VFE                                 "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFE_ADIAB_GWADV2_PCC_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; no DFI; CheapPc; GWadv; ND4SYS=2; VFE                             "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_SL2_VFE_ADIAB_GWADV2_PCC_TL030S' ]                  ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl adiab TL030L15c2.4; DFI; CheapPc; GWadv; ND4SYS=2; VFE                                "  ; fi

  # - NHEE Non-hydrostatic eulerian diabatic configuration 001 (stretched-tilted) (former MNEY):
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_EUL_VFD_ARPPHYISBA_SI_TL030S' ]                     ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE euler diab TL030L15c2.4; DFI; SI; VFD                                                       "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_EUL_VFD_ARPPHYISBA_PCF_TL030S' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE euler diab TL030L15c2.4; DFI; FullPc; VFD                                                   "  ; fi

  # - NHQE Non-hydrostatic eulerian diabatic configuration 001 (stretched-tilted) (former MNEY):
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_EUL_VFD_ARPPHYISBA_SI_TL030S' ]                     ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ euler diab TL030L15c2.4; DFI; SI; VFD                                                       "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_EUL_VFD_ARPPHYISBA_PCF_TL030S' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ euler diab TL030L15c2.4; DFI; FullPc; VFD                                                   "  ; fi

  # - NHEE Non-hydrostatic SL3TL semi-Lagrangian diabatic configuration 001 (stretched-tilted) (former MNSY):
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_SL3_VFD_ARPPHYISBA_RDBBC2_TL030S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl3tl diab TL030L15c2.4; DFI; SI; RDbbc; VFD                                                "  ; fi

  # - NHQE Non-hydrostatic SL3TL semi-Lagrangian diabatic configuration 001 (stretched-tilted) (former MNSY):
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_SL3_VFD_ARPPHYISBA_RDBBC2_TL030S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl3tl diab TL030L15c2.4; DFI; SI; RDbbc; VFD                                                "  ; fi

  # - NHEE Non-hydrostatic SL2TL semi-Lagrangian diabatic configuration 001 (stretched-tilted) (former MNLY):
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_SL2_VFD_ARPPHYISBA_GWADV2_PCF_TL030S' ]             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl diab TL030L15c2.4; DFI; FullPc; GWadv; ND4SYS=2; VFD                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHE_SL2_VFD_ARPPHYISBA_GWADV2_PCC_TL030S' ]             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl diab TL030L15c2.4; DFI; CheapPc; GWadv; ND4SYS=2; VFD                                 "  ; fi

  # - NHQE Non-hydrostatic SL2TL semi-Lagrangian diabatic configuration 001 (stretched-tilted) (former MNLY):
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_SL2_VFD_ARPPHYISBA_GWADV2_PCF_TL030S' ]             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl diab TL030L15c2.4; DFI; FullPc; GWadv; ND4SYS=2; VFD                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_NHQ_SL2_VFD_ARPPHYISBA_GWADV2_PCC_TL030S' ]             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl diab TL030L15c2.4; DFI; CheapPc; GWadv; ND4SYS=2; VFD                                 "  ; fi

  # - Hydrostatic eulerian adiabatic configuration 501 (former 5HEY)
  if [ "$CODE_JOB" = 'GM_C501_HYD_EUL_VFD_ADIAB_TL031U' ]                             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 501HYD euler adiab TL031L15c1; no DFI; VFD; no SLHD                                                "  ; fi
  if [ "$CODE_JOB" = 'GM_C501_HYD_EUL_VFD_ADIAB_TL030S' ]                             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 501HYD euler adiab TL030L15c2.4; no DFI; VFD; no SLHD                                              "  ; fi

  # - Hydrostatic SL2TL semi-lagrangian adiabatic configuration 501 (former 5HLY and 5HLZ)
  if [ "$CODE_JOB" = 'GM_C501_HYD_SL2_VFE_ADIAB_TL031U' ]                             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 501HYD sl2tl adiab TL031L15c1; no DFI; VFE; no SLHD                                                "  ; fi
  if [ "$CODE_JOB" = 'GM_C501_HYD_SL2_VFE_ADIAB_TL030S' ]                             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 501HYD sl2tl adiab TL030L15c2.4; no DFI; VFE; no SLHD                                              "  ; fi
  if [ "$CODE_JOB" = 'GM_C501_HYD_SL2_VFE_ADIAB_SLHD_TL031U' ]                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 501HYD sl2tl adiab TL031L15c1; no DFI; VFE; SLHD                                                   "  ; fi
  if [ "$CODE_JOB" = 'GM_C501_HYD_SL2_VFE_ADIAB_SLHD_TL030S' ]                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 501HYD sl2tl adiab TL030L15c2.4; no DFI; VFE; SLHD                                                 "  ; fi

  # - Hydrostatic eulerian adiabatic configuration 401 (former 4HEY)
  if [ "$CODE_JOB" = 'GM_C401_HYD_EUL_VFD_ADIAB_TL031U' ]                             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 401HYD euler adiab TL031L15c1; no DFI; VFD; no SLHD                                                "  ; fi
  if [ "$CODE_JOB" = 'GM_C401_HYD_EUL_VFD_ADIAB_TL030S' ]                             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 401HYD euler adiab TL030L15c2.4; no DFI; VFD; no SLHD                                              "  ; fi

  # - Hydrostatic SL2TL semi-lagrangian adiabatic configuration 401 (former 4HLY and 4HLZ)
  if [ "$CODE_JOB" = 'GM_C401_HYD_SL2_VFE_ADIAB_TL031U' ]                             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 401HYD sl2tl adiab TL031L15c1; no DFI; VFE; no SLHD                                                "  ; fi
  if [ "$CODE_JOB" = 'GM_C401_HYD_SL2_VFE_ADIAB_TL030S' ]                             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 401HYD sl2tl adiab TL030L15c2.4; no DFI; VFE; no SLHD                                              "  ; fi
  if [ "$CODE_JOB" = 'GM_C401_HYD_SL2_VFE_ADIAB_SLHD_TL031U' ]                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 401HYD sl2tl adiab TL031L15c1; no DFI; VFE; SLHD                                                   "  ; fi
  if [ "$CODE_JOB" = 'GM_C401_HYD_SL2_VFE_ADIAB_SLHD_TL030S' ]                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 401HYD sl2tl adiab TL030L15c2.4; no DFI; VFE; SLHD                                                 "  ; fi

  # - Hydrostatic configuration 601 with Eulerian advection scheme (former 6HEX)
  if [ "$CODE_JOB" = 'GM_C601_HYD_EUL_VFD_ADIAB' ]                                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 601HYD euler adiab; no DFI; VFD; no SLHD                                                           "  ; fi
  if [ "$CODE_JOB" = 'GM_C601_HYD_EUL_VFD_VSIPHY' ]                                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 601HYD euler with very simplified physics; no DFI; VFD; no SLHD                                    "  ; fi

  # - Hydrostatic configuration 601 with SL2TL advection scheme (former 6HLX)
  if [ "$CODE_JOB" = 'GM_C601_HYD_SL2_VFE_ADIAB' ]                                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 601HYD sl2tl adiab; no DFI; VFE; no SLHD                                                           "  ; fi
  if [ "$CODE_JOB" = 'GM_C601_HYD_SL2_VFE_VSIPHY' ]                                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 601HYD sl2tl with very simplified physics; no DFI; VFE; no SLHD                                    "  ; fi

  # - DCMIP cases: hydrostatic SL2TL semi-Lagrangian adiabatic configuration 001 (unstretched-untilted):
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_DCMIP200TL239U' ]              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab DCMIP200 TL239L30c1; no DFI; SETTLS; VFD                                        "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_DCMIP400TL179U' ]              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab DCMIP400 TL179L31c1; no DFI; SETTLS; VFD                                        "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_DCMIP210TL319U' ]              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab DCMIP210 TL319L60c1; no DFI; SETTLS; VFD                                        "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_DCMIP410TL799U' ]              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab DCMIP410 TL799L137c1; no DFI; SETTLS; VFD                                       "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFD_ADIAB_SETTLS_DCMIP410TL2249U' ]             ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl adiab DCMIP410 TL2249L137c1; no DFI; SETTLS; VFD                                      "  ; fi

  # - DCMIP cases: NHEE non-hydrostatic SL2TL semi-Lagrangian adiabatic configuration 001 (unstretched-untilted):
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCC_DCMIP200TL239U' ]          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab DCMIP200 TL239L30c1; no DFI; CheapPc; GWadv; VFD                                "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCF_DCMIP200TL239U' ]          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab DCMIP200 TL239L30c1; no DFI; FullPc; GWadv; VFD                                 "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCC_DCMIP400TL179U' ]          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab DCMIP400 TL179L31c1; no DFI; CheapPc; GWadv; VFD                                "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCF_DCMIP400TL179U' ]          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab DCMIP400 TL179L31c1; no DFI; FullPc; GWadv; VFD                                 "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCC_DCMIP210TL319U' ]          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab DCMIP210 TL319L60c1; no DFI; CheapPc; GWadv; VFD                                "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCF_DCMIP210TL319U' ]          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab DCMIP210 TL319L60c1; no DFI; FullPc; GWadv; VFD                                 "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCC_DCMIP410TL799U' ]          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab DCMIP410 TL799L137c1; no DFI; CheapPc; GWadv; VFD                               "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCF_DCMIP410TL799U' ]          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab DCMIP410 TL799L137c1; no DFI; FullPc; GWadv; VFD                                "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCC_DCMIP410TL2249U' ]         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab DCMIP410 TL2249L137c1; no DFI; CheapPc; GWadv; VFD                              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ADIAB_GWADV2_PCF_DCMIP410TL2249U' ]         ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl adiab DCMIP410 TL2249L137c1; no DFI; FullPc; GWadv; VFD                               "  ; fi

  #---------------------------------------------------------------------------------------------------------------------
  # ===== Global model light validation ================================================================================
  #---------------------------------------------------------------------------------------------------------------------

  # - Hydrostatic eulerian diabatic configuration 501 (former 5HEX)
  if [ "$CODE_JOB" = 'GM_C501_HYD_EUL_VFD_SIM5PHYISBA' ]                              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 501HYD euler with simplified physics TL107L70c1; no DFI; VFD; no SLHD                              "  ; fi

  # - Hydrostatic SL2TL semi-lagrangian diabatic configuration 501 (former 5HLX)
  if [ "$CODE_JOB" = 'GM_C501_HYD_SL2_VFE_SIM5PHYISBA' ]                              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 501HYD sl2tl with simplified physics TL107L70c1; no DFI; VFE; no SLHD                              "  ; fi

  # - Hydrostatic eulerian diabatic configuration 401 (former 4HEX)
  if [ "$CODE_JOB" = 'GM_C401_HYD_EUL_VFD_SIM4PHYISBA' ]                              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 401HYD euler with simplified physics TL107L70c1; no DFI; VFD; no SLHD                              "  ; fi

  # - Hydrostatic SL2TL semi-lagrangian diabatic configuration 401 (former 4HLX)
  if [ "$CODE_JOB" = 'GM_C401_HYD_SL2_VFE_SIM4PHYISBA' ]                              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 401HYD sl2tl with simplified physics TL107L70c1; no DFI; VFE; no SLHD                              "  ; fi

  # - Off-line FULLPOS; 927-like; Hydrostatic model TL107c1 <-> TL798c2.4 (former FPFA and FPFB)
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SPGAUSS_L2H' ]                                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS L2H; CFPFMT=GAUSS; OFF-LINE                                                            "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SPGAUSS_H2L' ]                                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS H2L; CFPFMT=GAUSS; OFF-LINE                                                            "  ; fi

  # - Off-line Full-POS tests:
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_MODEL' ]                                            ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 903HYD FPOS; CFPFMT=MODEL; OFF-LINE                                                                "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_GPGAUSS' ]                                          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 903HYD FPOS; CFPFMT=GAUSS; OFF-LINE                                                                "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SPLELAM_COU' ]                                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS; E927-NFPOS2 COU; OFF-LINE                                                             "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SPLELAM_ARU' ]                                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS; E927-NFPOS2 ARU; OFF-LINE                                                             "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SPLELAM_CIE_LAM2' ]                                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 903HYD FPOS; LAM2=E927; LELAM=F; CFPFMT=LELAM; C+I+E; OFF-LINE                                     "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SURFLELAM' ]                                        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS; LAMARS; LELAM=F; CFPFMT=LELAM; C+I+E; OFF-LINE                                        "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_GPLALON_ARPPHYISBA' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS 5 domains; CFPFMT=LALON; OFF-LINE                                                      "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_NHE_GPLALON_ARPPHYISBA' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE FPOS 5 domains; CFPFMT=LALON; OFF-LINE                                                      "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_NHQ_GPLALON_ARPPHYISBA' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ FPOS 5 domains; CFPFMT=LALON; OFF-LINE                                                      "  ; fi

  # - In-line Full-POS tests (former FILA and FILB):
  if [ "$CODE_JOB" = 'GM_FPIN_HYD_GPLALON_ARPPHYISBA' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS 5 domains; CFPFMT=LALON; IN-LINE                                                       "  ; fi
  if [ "$CODE_JOB" = 'GM_FPIN_NHE_GPLALON_ARPPHYISBA' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE FPOS 5 domains; CFPFMT=LALON; IN-LINE                                                       "  ; fi
  if [ "$CODE_JOB" = 'GM_FPIN_NHQ_GPLALON_ARPPHYISBA' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ FPOS 5 domains; CFPFMT=LALON; IN-LINE                                                       "  ; fi

  # - Hydrostatic oper-type configuration 001 (2TLSL+oper physics) (former MHLI, MHLJ, MHLK)
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ARPPHYISBA_SLT_TL798S' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl TL798L70c2.4; DFI; ARPPHYISBA; Standard Legendre transforms;                          "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ARPPHYISBA_SLT_IOSV_TL798S' ]               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl TL798L70c2.4; DFI; ARPPHYISBA; Standard Legendre transforms; IO_SERVER                "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ARPPHYISBA_FLT_TL798S' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl TL798L70c2.4; DFI; ARPPHYISBA; Fast Legendre transforms;                              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ARPPHYISBA_FLT_IOSV_TL798S' ]               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl TL798L70c2.4; DFI; ARPPHYISBA; Fast Legendre transforms; IO_SERVER                    "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ARPPHYISBA_SLT_REST_TL798S' ]               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl TL798L70c2.4; DFI; ARPPHYISBA; Standard Legendre transforms; Restart                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ARPPHYSFEX_SLT_TL798S' ]                    ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl TL798L90c2.4; DFI; ARPPHYSFEX; Standard Legendre transforms;                          "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFE_PEARP_PHYSFEX_SLT_TL798S' ]                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl TL798L90c2.4; ARPPHYSFEX; Standard Legendre transforms; NO DFI; ecrad, CAPE, Tiedke   "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ARPPHYSFEX_WENO_TL798S' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl TL798L90c2.4; DFI; ARPPHYSFEX; Standard Legendre transforms; WENO                     "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ARPPHYSFEX_SLT_IOSV_TL798S' ]               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl TL798L90c2.4; DFI; ARPPHYSFEX; Standard Legendre transforms; IO_SERVER                "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ARPPHYSFEX_SLT_REST_TL798S' ]               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl TL798L90c2.4; DFI; ARPPHYSFEX; Standard Legendre transforms; Restart                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ARPPHYSFEX_SLT_RESTIOS_TL798S' ]            ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl TL798L90c2.4; DFI; ARPPHYSFEX; Standard Legendre transforms; Restart+IO_SERVER        "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ARPPHYSFEX_SLT_TL1198S' ]                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl TL1198L105c2.2; DFI; ARPPHYSFEX; Standard Legendre transforms;                        "  ; fi
  if [ "$CODE_JOB" = 'GM_FCTI_HYD_SL2_VFE_ARPPHYSFEX_SLT_IOSV_TL1198S' ]              ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl TL1198L105c2.2; DFI; ARPPHYSFEX; Standard Legendre transforms; IO_SERVER              "  ; fi

  # - Conf 923 / clim files preparation (former C923):
  if [ "$CODE_JOB" = 'GM_C923_TL798S' ]                                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 923; domain=ARP METROPOLE TL798c2.4; without SURFEX                                                "  ; fi
  if [ "$CODE_JOB" = 'GM_C923_SFEX_JAN_TL798S' ]                                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 923; domain=ARP METROPOLE TL798c2.4; with SURFEX                                                   "  ; fi

  # - Configuration 901 (MARS file towards ARPEGE file) (former C901):
  if [ "$CODE_JOB" = 'GE_C901' ]                                                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 901                                                                                                "  ; fi

  # - Off-line FULL-POS, "LALON": makes filtering matrices via FULL-POS setup (former FPMB and FPMC).
  if [ "$CODE_JOB" = 'GM_FPMF_HYD_GPLALON_INRD' ]                                     ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS (makes filtering matrices; input RD matrices); CFPFMT=LALON; OFF-LINE                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FPMF_HYD_GPLALON_CPRD' ]                                     ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS (makes filtering matrices; internal computation of RD matrices); CFPFMT=LALON; OFF-LINE"  ; fi

  #---------------------------------------------------------------------------------------------------------------------
  # ===== Global model addenda =========================================================================================
  #---------------------------------------------------------------------------------------------------------------------

  # - Transform files with a new set of vertical levels and test that these vertical levels can be used for LVFE_REGETA=T (former FPSU).
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_MODEL_CHANGELEVELS' ]                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS; change set of vertical levels; OFF-LINE                                               "  ; fi

  # - Add NH variables or grid-point q on files (former FPSV).
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_MODEL_ADDGPQ' ]                                     ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS; CFPFMT='MODEL'; add grid-point q; OFF-LINE                                            "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_MODEL_ADDNHVAR' ]                                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS; CFPFMT='MODEL'; add NH variables; OFF-LINE                                            "  ; fi

  # - Make dilatation/contraction matrices by former configuration 911 (former DILA):
  if [ "$CODE_JOB" = 'GM_DILA' ]                                                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Make dilatation-contraction matrices by former conf 911                                                 "  ; fi
  if [ "$CODE_JOB" = 'GM_DILA_HRES' ]                                                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Make dilatation-contraction matrices by former conf 911: high resolution                                "  ; fi

  # - Make reduced Gaussian grids via RGRID (former RGRI):
  if [ "$CODE_JOB" = 'GM_RGRI' ]                                                      ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Make reduced Gaussian grids                                                                             "  ; fi

  # - Make AROME OC0250 couplers from ARPEGE files:
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SPLELAM_OC0250' ]                                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD E927-NFPOS2; ARP TL1198 towards ARO OC0250 (coupling)                                       "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SURFLELAM_OC0250' ]                                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS LAMARS; ARP TL1198 towards ARO OC0250 (couplingsurf)                                   "  ; fi

  # - Make AROME OC0275 couplers from ARPEGE files:
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SPLELAM_OC0275' ]                                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD E927-NFPOS2; ARP TL1198 towards ARO OC0275 (coupling)                                       "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SURFLELAM_OC0275' ]                                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS LAMARS; ARP TL1198 towards ARO OC0275 (couplingsurf)                                   "  ; fi

  # - Make AROME OC0375 couplers from ARPEGE files:
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SPLELAM_OC0375' ]                                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD E927-NFPOS2; ARP TL1198 towards ARO OC0375 (coupling)                                       "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SURFLELAM_OC0375' ]                                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS LAMARS; ARP TL1198 towards ARO OC0375 (couplingsurf)                                   "  ; fi

  # - Make AROME OC0500 couplers from ARPEGE files:
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SPLELAM_OC0500' ]                                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD E927-NFPOS2; ARP TL1198 towards ARO OC0500 (coupling)                                       "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SURFLELAM_OC0500' ]                                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS LAMARS; ARP TL1198 towards ARO OC0500 (couplingsurf)                                   "  ; fi

  # - Make AROME OC0750 couplers from ARPEGE files:
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SPLELAM_OC0750' ]                                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD E927-NFPOS2; ARP TL1198 towards ARO OC0750 (coupling)                                       "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SURFLELAM_OC0750' ]                                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS LAMARS; ARP TL1198 towards ARO OC0750 (couplingsurf)                                   "  ; fi

  # - Make AROME OC1000 couplers from ARPEGE files:
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SPLELAM_OC1000' ]                                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD E927-NFPOS2; ARP TL1198 towards ARO OC1000 (coupling)                                       "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SURFLELAM_OC1000' ]                                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS LAMARS; ARP TL1198 towards ARO OC1000 (couplingsurf)                                   "  ; fi

  # - Make AROME OC1300 couplers from ARPEGE files:
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SPLELAM_OC1300' ]                                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD E927-NFPOS2; ARP TL1198 towards ARO OC1300 (coupling)                                       "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SURFLELAM_OC1300' ]                                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS LAMARS; ARP TL1198 towards ARO OC1300 (couplingsurf)                                   "  ; fi

  # - Make model climatologies with SURFEX for ARPEGE (TL798c2.4):
  if [ "$CODE_JOB" = 'GM_PGDI_TL798S' ]                                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD file for ARPEGE TL798c2.4                                                                      "  ; fi
  if [ "$CODE_JOB" = 'GM_C923_SFEX_TL798S' ]                                          ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 923; make clim with SURFEX for ARPEGE TL798c2.4                                                    "  ; fi
  if [ "$CODE_JOB" = 'GM_PGDS_TL798S' ]                                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "make PGD-S file for ARPEGE TL798c2.4                                                                    "  ; fi
  if [ "$CODE_JOB" = 'GM_PGDC_TL798S' ]                                               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "convert PGD LFI to FA for ARPEGE TL798c2.4                                                              "  ; fi

  # - Off-line FULLPOS; 927-like; Hydrostatic model TL1198c2.2 -> TL798c2.4: make initial files for forecasts with SURFEX
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SPGAUSS_TL798S' ]                                   ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS TL798S ALTI; ARP TL1198 towards ARP TL798 (upper-air)                                  "  ; fi
  if [ "$CODE_JOB" = 'GM_FPOF_HYD_SURFGAUSS_TL798S' ]                                 ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD FPOS TL798S LAMARS; ARP TL1198 towards ARP TL798 (surf)                                     "  ; fi

  # - HYD and NH ARPEGE 001 with physics (TL1198C064FR):
  if [ "$CODE_JOB" = 'GM_FCST_HYD_SL2_VFE_ARPPHYISBA_SI_TL1198C064FR' ]               ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001HYD sl2tl TL1198L105c6.4 France; no DFI; VFE; ARPPHYISBA; SI                                    "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ARPPHYISBA_RDBBC2_SI_TL1198C064FR' ]        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl TL1198L105c6.4 France; no DFI; VFD; ARPPHYISBA; SI; RDbbc; ND4SYS=2                   "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ARPPHYISBA_RDBBC2_PCC_TL1198C064FR' ]       ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl TL1198L105c6.4 France; no DFI; VFD; ARPPHYISBA; CheapPc; RDbbc; ND4SYS=2              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ARPPHYISBA_RDBBC2_PCF_TL1198C064FR' ]       ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl TL1198L105c6.4 France; no DFI; VFD; ARPPHYISBA; FullPc; RDbbc; ND4SYS=2               "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ARPPHYISBA_GWADV2_PCC_TL1198C064FR' ]       ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl TL1198L105c6.4 France; no DFI; VFD; ARPPHYISBA; CheapPc; GWadv; ND4SYS=2              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFD_ARPPHYISBA_GWADV2_PCF_TL1198C064FR' ]       ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl TL1198L105c6.4 France; no DFI; VFD; ARPPHYISBA; FullPc; GWadv; ND4SYS=2               "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFE_ARPPHYISBA_GWADV2_PCC_TL1198C064FR' ]       ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl TL1198L105c6.4 France; no DFI; VFE; ARPPHYISBA; CheapPc; GWadv; ND4SYS=2              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHE_SL2_VFE_ARPPHYISBA_GWADV2_PCF_TL1198C064FR' ]       ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHE sl2tl TL1198L105c6.4 France; no DFI; VFE; ARPPHYISBA; FullPc; GWadv; ND4SYS=2               "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFD_ARPPHYISBA_RDBBC2_SI_TL1198C064FR' ]        ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl TL1198L105c6.4 France; no DFI; VFD; ARPPHYISBA; SI; RDbbc; ND4SYS=2                   "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFD_ARPPHYISBA_RDBBC2_PCC_TL1198C064FR' ]       ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl TL1198L105c6.4 France; no DFI; VFD; ARPPHYISBA; CheapPc; RDbbc; ND4SYS=2              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFD_ARPPHYISBA_RDBBC2_PCF_TL1198C064FR' ]       ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl TL1198L105c6.4 France; no DFI; VFD; ARPPHYISBA; FullPc; RDbbc; ND4SYS=2               "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFD_ARPPHYISBA_GWADV2_PCC_TL1198C064FR' ]       ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl TL1198L105c6.4 France; no DFI; VFD; ARPPHYISBA; CheapPc; GWadv; ND4SYS=2              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFD_ARPPHYISBA_GWADV2_PCF_TL1198C064FR' ]       ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl TL1198L105c6.4 France; no DFI; VFD; ARPPHYISBA; FullPc; GWadv; ND4SYS=2               "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFE_ARPPHYISBA_GWADV2_PCC_TL1198C064FR' ]       ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl TL1198L105c6.4 France; no DFI; VFE; ARPPHYISBA; CheapPc; GWadv; ND4SYS=2              "  ; fi
  if [ "$CODE_JOB" = 'GM_FCST_NHQ_SL2_VFE_ARPPHYISBA_GWADV2_PCF_TL1198C064FR' ]       ; then ; set_job ${CODE_JOB}.pjob $CODE_JOB "Conf 001NHQ sl2tl TL1198L105c6.4 France; no DFI; VFE; ARPPHYISBA; FullPc; GWadv; ND4SYS=2               "  ; fi

done # End of Main loop


#---------------------------------------------------------------------------------------------------------
# 3. Launch - Start the chain of job submissions
#---------------------------------------------------------------------------------------------------------

# provisional end of chain
#
# launch first job of the chain
#
cd $JOB_DIR
echo "\n **M_INFO   ** Submit chainjob rank 0 \n" | tee -a ${LOG_MIT}

##neu $SUBMIT chainjob_000
cd $LOCAL_DIR
echo "\n **M_INFO   ** Create rank_last.x${MITRA_PID} with $seqn \n" | tee -a ${LOG_MIT}
echo $(( $seqn -1 )) > rank_last.x${MITRA_PID}
echo "\n **************************************************" | tee -a ${LOG_MIT}
echo " **M_INFO   ** END OF mitraillette.x ( id = ${MITRA_PID} )" | tee -a ${LOG_MIT}
echo " **************************************************\n" | tee -a ${LOG_MIT}

echo You can start the mitraillette chain by running test.x${MITRA_PID}
exit 0

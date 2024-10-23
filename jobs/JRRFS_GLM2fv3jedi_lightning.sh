#!/bin/bash

. ${GLOBAL_VAR_DEFNS_FP}
. $USHdir/source_util_funcs.sh

set -x 

# don't JEDI lightning on cold start
hour=${ATIME:8:2}
if [[ ${hour} -eq "03" ]] || [[ ${hour} -eq "15" ]]; then
  if [ ${FV3FCST_TYPE} == "spinup" ]; then
    exit 0
  fi
fi


GEO_FILE=${FIX_GSI}/${PREDEF_GRID_NAME}/fv3_grid_spec
modlopt=2
l_jedi=".true."
obserror=0.5
analysis_min=${ATIME:(-2):2}
analysis_sec=00
 
OBS_FDIR=${WORKDIR}/OBS # final output
  
# you may have error when running GSI if you set iskip and skip as 1
# this seem to be related with the memory issues in GSI.
#iskip=2 # intervals on x-axis(lon) to skip data (unit: gridpoint)
#jskip=2 # intervals on y-axis(lat) to skip data (unit: gridpoint)
#lev_keep=1000 # intervals on z-axis(hgt) to skip data (unit: meter)

ANAL_TIME=`echo ${ATIME} | cut -c1-12`
AYYYYMMDD=`echo ${ATIME} | cut -c1-8`
AHH=`echo ${ATIME} | cut -c9-10`
START_TIME=${ANAL_TIME}

#RADARDIR=${OBSPATH_NSSLMOSIAC}
LIGHTDIR=${OBSPATH_FED_GLM} #set in var_defns.sh
#exefile=/scratch1/NCEPDEV/nems/role.epic/spack-stack/spack-stack-1.6.0/envs/unified-env-rocky8/install/intel/2021.5.0/python-3.10.13-2p2rady/bin/python
exefile=/scratch1/BMC/acomp/Johana/miniconda/envs/interpol_esmpy/bin/python
SRC_LTGPY=${FIX_JEDIGLM}/ProcessGLM/

#exefile=process_CAPS_mosaic.exe
iodaconv='..'
#export MOSAICTILENUM=1

#Switch to (and create if needed) working directory (stmp/<cycle>))


if [ ! -d ${WORKDIR} ] ; then
    mkdir -p ${WORKDIR}
fi
cd ${WORKDIR}
rm -f *
pwd
### Process Mosaic
numtiles=${MOSAICTILENUM}

echo $START_TIME >STARTTIME

#====================================================================#
# Compute date & time components for the analysis time
ymd=`echo ${START_TIME} | cut -c1-8`
ymdh=`echo ${START_TIME} | cut -c1-10`
hh=`echo ${START_TIME} | cut -c9-10`
mn=`echo ${START_TIME} | cut -c11-12`
YYYYJJJHH00=`date +"%Y%j%H00" -d "${ymd} ${hh}"`
YYYYMMDDHH=`date +"%Y%m%d%H" -d "${ymd} ${hh}"`
YYYY=`date +"%Y" -d "${ymd} ${hh}"`
MM=`date +"%m" -d "${ymd} ${hh}"`
DD=`date +"%d" -d "${ymd} ${hh}"`
HH=`date +"%H" -d "${ymd} ${hh}"`
mm=`date +"%M" -d "${ymd} ${hh}"`
Ym1mn=`date -d "${YYYY}-${MM}-${DD} ${HH} -1 minute" +%Y`
Mm1mn=`date -d "${YYYY}-${MM}-${DD} ${HH} -1 minute" +%m`
Dm1mn=`date -d "${YYYY}-${MM}-${DD} ${HH} -1 minute" +%d`
Hm1mn=`date -d "${YYYY}-${MM}-${DD} ${HH} -1 minute" +%H`
#====================================================================#

# Directory for the Radar Mosaic input files (not needed?)
#cp ${SRC_RDRPROC}/prepobs_prep.bufrtable  ./prepobs_prep.bufrtable

#may not be needed, but leave for now
cp ${GEO_FILE} ./geo_em.d01.nc

# find grib2 MRMS files
#not needed for GLM but leave in case it is a useful reference
#case ${mn} in
#  '00')
#  minute=0
#  while [ ${minute} -le 3 ]; do
#   mm=`printf "%02i" ${minute}`
#   numgrib2=`ls ${RADARDIR}/*MergedReflectivityQC_*_${YYYY}${MM}${DD}-${HH}${mm}??.grib2 | wc -l`
#   if [ ${numgrib2} -eq 33 ]; then
#    thismin=${mm}
#    break
#   else
#    ((minute = minute + 1))
#   fi
#  done
#  ;;
#  '60')
#  minute=59
#  while [ ${minute} -ge 57 ]; do
#   mm=`printf "%02i" ${minute}`
#   numgrib2=`ls ${RADARDIR}/*MergedReflectivityQC_*_${YYYY}${MM}${DD}-${HH}${mm}??.grib2 | wc -l`
#   if [ ${numgrib2} -eq 33 ]; then
#    thismin=${mm}
#    break
#   else
#    ((minute = minute - 1))
#   fi
#  done
#  ;;
#  *)
#  min_list=(0 -1 1 -2 2 -3 3)
#  for minute in ${min_list[*]}; do
#   ((min2 = mn + minute))
#   mm=`printf "%02i" ${min2}`
#   numgrib2=`ls ${RADARDIR}/*MergedReflectivityQC_*_${YYYY}${MM}${DD}-${HH}${mm}??.grib2 | wc -l`
#   if [ ${numgrib2} -eq 33 ]; then
#    thismin=${mm}
#    break
#   fi
#  done
#  ;;
#esac

#thismin=${mm}
#echo "The minute for which files exist for SUB-HOURLY MINUTE=${mn} is ${thismin}"

#rm filelist_mrms
#ls ${RADARDIR}/*MergedReflectivityQC_*_${YYYY}${MM}${DD}-${HH}${thismin}??.grib2 > mrms_file_list

#module load wgrib2
#for MRMS_file in `cat mrms_file_list`; do
#   fname=`basename ${MRMS_file}`
#   # Reflectivity file names may be different between sources - when obtained direct from HPSS, the field below should be 3
#   # When the source is a joint data source from staged data for retros, you may need "2" instead
#   height=`echo ${fname} | cut -d '_' -f 2`
#   wgrib2 ${MRMS_file} -set_date ${TIME:0:10}${mn}00 -grib MRMS_reflectivity_${height}_${TIME:0:10}${mn}.grib2
#done
#ls MRMS_reflectivity_??.??_${TIME:0:10}${mn}.grib2 > filelist_mrms

#if [ -s filelist_mrms ]; then
#   numgrib2=`more filelist_mrms | wc -l`
#   echo "NSSL grib2 file level number = $numgrib2"
#else
#   numgrib2=0
#fi

#echo ${ymdh} > ./mosaic_cycle_date

#no namelists needed for python, but check to see if mosaic.namelist gets used later
cat << EOF > mosaic.namelist
 &setup
   tversion=${numtiles},
   analysis_time = ${ATIME},
   dataPath = './',
   l_latlon = .TRUE.,
   l_psot = .FALSE.,
   iskip = ${iskip},
   jskip = ${jskip},
   lev_keep = ${lev_keep},
   modlopt = ${modlopt},
   l_jedi = ${l_jedi},
 /
 &oneob
   l_latlon_psot = .FALSE.,
   olat = 100,
   olon = 150,
   olvl = 15,
   odbz = 75.0,
 /

 &jedi_setup
  obserror = ${obserror},
  analysis_min = ${analysis_min},
  analysis_sec = ${analysis_sec},
 /

EOF

#run IODA converter


###switch exefile with python call
echo "Running GLM IODA converter for cdate: ${CDATE}"
export CDATE=$CDATE
export WORKDIR=$WORKDIR
#srun ${exefile} -u ${SRC_LTGPY}/main.py 
${exefile} -u ${SRC_LTGPY}/main.py 

# move converter output to OBS_FDIR
mkdir -p ${OBS_FDIR}

set -x
if [[ "${l_jedi}" == ".true." ]]; then
 cp -r fed_glm_${AYYYYMMDD}${AHH}_${analysis_min}${analysis_sec}00_iodav3.nc ${OBS_FDIR}
 status=$?
else #leaving this here, but it shouldn't get used for this project
 echo "ERROR: GLM IODA driver code should't be executing this block"
 cp -r dbzbufr_mrmsg2 ${OBS_FDIR}/dbzbufr_mrmsg2.${ATIME}
 status=$?
fi

exit ${status}

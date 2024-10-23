#!/bin/bash


. ${GLOBAL_VAR_DEFNS_FP}
. $USHdir/source_util_funcs.sh

module load nco

CTIME=${ATIME:0:10}
source $USHdir/run_convert_UV.sh

#hack to keep JEDI-IC task from overwriting things while testing hofx and envar tasks
#echo 'Exiting after convert_UV.sh with nonzero error code to halt workflow during testing'
#echo 'Remove or comment out these lines near top of modify_ICs.sh to run normally'
#exit 1

# don't JEDI lightning on cold start
hour=${ATIME:8:2}
if [[ ${hour} -eq "03" ]] || [[ ${hour} -eq "15" ]]; then
  if [ ${CYCLE_TYPE} == "spinup" ]; then
    exit 0
  fi
fi

set -x

if [ ! -f ${JEDI_DIR}/convertstate/re-staggered_UV.fv_core.res.nc ]; then
  echo "Error: D-grid wind file missing"
  exit 1
fi

cd ${JEDI_DIR}

#Rename the y axis here because the jedi envar task returns the wrong name
ncrename -d yaxis_1,yaxis_2 -v yaxis_1,yaxis_2 ${PREFIX}.fv_core.res.nc
ncatted -a long_name,yaxis_2,o,c,yaxis_2 ${PREFIX}.fv_core.res.nc

#copy u,v from re-stagger file into lightning.fv_core.res.nc
ncks -v u,v convertstate/re-staggered_UV.fv_core.res.nc -O backup.re-stagger.fv_core.res.nc
ncks -A -v u,v backup.re-stagger.fv_core.res.nc ${PREFIX}.fv_core.res.nc

#processing below here mostly from radar DA script
yyyymmdd_hhmm=`date -d "${ATIME:0:8} ${ATIME:8:4}" +%Y%m%d.%H%M`
dyn_file=${JEDI_DIR}/${PREFIX}.fv_core.res.nc
phy_file=${JEDI_DIR}/${PREFIX}.fv_tracer.res.nc
phys_fields=(sphum ice_wat liq_wat rainwat snowwat graupel rain_nc)
#dyn_fields=(u v W T DELP ua va)
dyn_fields=(u v W T delp ua va)

if [ -f ${JEDI_DIR}/fv_core.temp.nc ]; then
   rm ${JEDI_DIR}/fv_core.temp.nc
fi

#ncrename -v .w,W -v .delp,DELP -v .t,T ${dyn_file} ${JEDI_DIR}/fv_core.temp.nc
ncrename -v .w,W -v .DELP,delp -v .t,T ${dyn_file} ${JEDI_DIR}/fv_core.temp.nc
err=$?
if [ ${err} -ne 0 ]; then
   echo "Error running ncrename on ${dyn_file}"
   exit ${err}
fi

for p in ${phys_fields[@]}; do
   ncatted -a checksum,${p},d,, -O ${phy_file}
   err=$?
   if [ ${err} -ne 0 ]; then
      echo "Error running ncatted on ${phy_file}"
      exit ${err}
   fi
done

for d in ${dyn_fields[@]}; do
   ncatted -a checksum,${d},d,, -O ${JEDI_DIR}/fv_core.temp.nc
   err=$?
   if [ ${err} -ne 0 ]; then
      echo "Error running ncatted on ${JEDI_DIR}/fv_core.temp.nc"
   fi
done

# None of t his should be needed anymore -- delete
#check_dir=${DEST_ROOT}/fcst_fv3lam_spinup/INPUT
#if [ -s ${check_dir}/fv_core.res.tile1.nc ]; then
#   dest_dir=${check_dir}
#elif [ -s ${DEST_ROOT}/fcst_fv3lam/INPUT/fv_core.res.tile1.nc ]; then
#   dest_dir=${DEST_ROOT}/fcst_fv3lam/INPUT
#else
#   echo "Could not find an existing dynamics file at the present cycle into which to place updated arrays"
#   exit 2
#fi
##### end delete

# This, however, is still needed
hour=${ATIME:8:2}
if [ ${CYCLE_TYPE} == "prod" ]; then
   DEST_ROOT=${DEST_DIR}/fcst_fv3lam/INPUT
   if [[ ${hour} == "09" ]] || [[ ${hour} == "21" ]]; then
      nwges_dir=${NWGES_ROOT_M1H}/fcst_fv3lam_spinup/RESTART
   else
      nwges_dir=${NWGES_ROOT_M1H}/fcst_fv3lam/RESTART
   fi
elif [ ${CYCLE_TYPE} == "spinup" ]; then
   DEST_ROOT=${DEST_DIR}/fcst_fv3lam_spinup/INPUT
   nwges_dir=${NWGES_ROOT_M1H}/fcst_fv3lam_spinup/RESTART
else
   echo "improper value for \$CYCLE_TYPE (must be either \"prod\" or \"spinup\""
   exit 3
fi

# Apply updates to dynamics file
ncks -x -v u,v,W,T,delp,ua,va ${nwges_dir}/${yyyymmdd_hhmm}00.fv_core.res.tile1.nc -O ${DEST_ROOT}/backup_core.nc
err=$?
if [ ${err} -ne 0 ]; then
   echo "ncks exited with error code ${err}"
   exit ${err}
fi
vlist=""
for d in ${dyn_fields[@]}; do
   vlist=${vlist}${d}","
done
ncks -v ${vlist::-1} ${JEDI_DIR}/fv_core.temp.nc -A ${DEST_ROOT}/backup_core.nc
#rm ${JEDI_DIR}/fv_core.temp.nc
mv ${DEST_ROOT}/backup_core.nc ${DEST_ROOT}/fv_core.res.tile1.nc

# Append variables to RRFS physics restart file (can't do this earlier because I need the $nwges_dir from 1 h prior from the above code first)
vlist=""
script=""
for p in ${phys_fields[@]}; do
   vlist=${vlist}${p}","
   script=${script}"$p=float(${p});"
done
# Change variable types from "double" to "float"
#probably not needed now: throws a warning about type mismatch when uncommented. 
ncap2  -O -s "${script::-1}" ${phy_file} ${phy_file}

#copy updated physics data to final tracer file
ncks -A -v ${vlist::-1} ${phy_file} ${DEST_ROOT}/fv_tracer.res.tile1.nc

if [ ${err} -ne 0 ]; then
   echo "ncks exited with error code ${err}"
   exit ${err}
fi

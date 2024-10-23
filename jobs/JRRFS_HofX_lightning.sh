#!/bin/bash

. ${GLOBAL_VAR_DEFNS_FP}
. $USHdir/source_util_funcs.sh

source ${MODULE_FILE}


# don't JEDI lightning on cold start
hour=${ANL_TIME:8:2}
if [[ ${hour} -eq "03" ]] || [[ ${hour} -eq "15" ]]; then
  if [ ${FV3FCST_TYPE} == "spinup" ]; then
    echo "Cold start - exiting."
    exit 0
  fi
fi

set -x
if [ ! -d ${WORK_DIR} ]; then
   mkdir -p ${WORK_DIR}
fi
cd ${WORK_DIR}
rm logfile.000000.out


if [[ ${FV3FCST_TYPE} == "spinup" ]]; then
  task_name_det="fcst_fv3lam_spinup"
else
  task_name_det="fcst_fv3lam"
fi


# What is this for??????
#if [[ ${FV3FCST_TYPE} != "spinup" && '${ANL_TIME:10:2}' != '09' && '${ANL_TIME:10:2}' != '21' ]]; then
#   task_name_det="fcst_fv3lam"
#elif [[  ${FV3FCST_TYPE} != "spinup" && ( '${ANL_TIME:10:2}' == '09' || '${ANL_TIME:10:2}' == '21' ) ]]; then
#   task_name_det="fcst_fv3lam_spinup"
#elif [ ${FV3FCST_TYPE} == "spinup" ]; then
#   task_name_det="fcst_fv3lam_spinup"
#fi

echo "bkg_root: ${BKG_ROOT}"
echo "task_name: ${task_name}"
BKG_DIR_DET=${BKG_ROOT}/${task_name_det}/INPUT

FV3NAMELIST=${WORK_DIR}/GSL_fv3input_for_lightning.nml
sed "s/LX,LY/${LX},${LY}/1" ${FIX_JEDIGLM}/${NML_TMP} > ${FV3NAMELIST}

if [ ! -d ${WORK_DIR}/LOG ]; then
   mkdir -p ${WORK_DIR}/LOG
fi

# Setup YAML file variables
WINDOW_TIME_STR=`date -d "${ANL_TIME::8} ${ANL_TIME:8:4} -1 hour" +%Y-%m-%dT%H:%M:00Z`
ANL_TIME_STR=`date -d "${ANL_TIME::8} ${ANL_TIME:8:4}" +%Y-%m-%dT%H:%M:00Z`
YYYYMMDD_HHMM=`date -d "${ANL_TIME::8} ${ANL_TIME:8:4}" +%Y%m%d_%H%M`

#echo "bkg_dir=${bkg_dir}"
sed "s/WINDOW_TIME/${WINDOW_TIME_STR}/g" ${FIX_JEDIGLM}/hofx_nomodel_fed.yaml_template | \
   sed "s+EXPT_ROOT+${FIX_JEDIGLM}+g" | \
   sed "s+FV3NAMELIST+${FV3NAMELIST}+g" | \
   sed "s/ANALYSIS_TIME/${ANL_TIME_STR}/g" | \
   sed "s@BKG_DIR@${BKG_DIR_DET}@g" | \
   sed "s+GLM_OUT_FN+${GLM_OBS_FN}+g" | \
   sed "s+HOFX_OUT_FN+${HOFX_FED_OUT_FN}+g" > hofx_nomodel_fed.yaml

ln -sf ${FIX_JEDIGLM} ./INPUT  # link grid info to work_dir

cat hofx_nomodel_fed.yaml
pwd
srun --export=ALL ${FV3JEDI_BINDIR}/fv3jedi_hofx_nomodel.x hofx_nomodel_fed.yaml ${WORK_DIR}/LOG/LOG_HOFX_FED_BKG

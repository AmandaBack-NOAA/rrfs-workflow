#!/bin/bash

. ${GLOBAL_VAR_DEFNS_FP}
. $USHdir/source_util_funcs.sh

source ${MODULE_FILE}

# don't JEDI lightning on cold start
hour=${ANL_TIME:8:2}
if [[ ${hour} -eq "03" ]] || [[ ${hour} -eq "15" ]]; then
  if [ ${FV3FCST_TYPE} == "spinup" ]; then
    exit 0
  fi
fi

if [ ! -d ${WORK_DIR} ]; then
   mkdir -p ${WORK_DIR}
fi
cd ${WORK_DIR}
# clean up
unlink INPUT
rm logfile.000000.out

FV3NAMELIST=${WORK_DIR}/GSL_fv3input_for_lightning.nml
sed "s/LX,LY/${LX},${LY}/1" < ${FIX_JEDIGLM}/${NML_TMP} > ${FV3NAMELIST}

#if [[ ${FV3FCST_TYPE} != "spinup" && '${ANL_TIME:10:2}' != '09' && '${ANL_TIME:10:2}' != '21' ]]; then
#   task_name_det="fcst_fv3lam"
#elif [[  ${FV3FCST_TYPE} != "spinup" && ( '${ANL_TIME:10:2}' == '09' || '${ANL_TIME:10:2}' == '21' ) ]]; then
#   task_name_det="fcst_fv3lam_spinup"
#elif [ ${FV3FCST_TYPE} == "spinup" ]; then
#   task_name_det="fcst_fv3lam_spinup"
#fi

if [[ ${FV3FCST_TYPE} == "spinup" ]]; then
  task_name_det="fcst_fv3lam_spinup"
else
  task_name_det="fcst_fv3lam"
fi


#task_name_ens="fcst_fv3lam_spinup"
task_name_ens="fcst_fv3lam"

#if [[ ${FV3FCST_TYPE} != "spinup" && '${ANL_TIME:10:2}' != '07' && '${ANL_TIME:10:2}' != '19' ]]; then
#   task_name_ens="fcst_fv3lam"
#elif [[  ${FV3FCST_TYPE} != "spinup" && ( '${ANL_TIME:10:2}' == '07' || '${ANL_TIME:10:2}' == '19' ) ]]; then
#   task_name_ens="fcst_fv3lam_spinup"
#elif [[ ${FV3FCST_TYPE} == "spinup" && '${ANL_TIME:10:2}' != '07' && '${ANL_TIME:10:2}' != '19' ]]; then
#   task_name_ens="fcst_fv3lam"
#elif [[ ${FV3FCST_TYPE} == "spinup" && ( '${ANL_TIME:10:2}' == '07' || '${ANL_TIME:10:2}' == '19') ]]; then
#   task_name_ens="fcst_fv3lam_spinup"
#fi

echo "bkg_root: ${BKG_ROOT}"
BKG_DIR=${BKG_ROOT}/${task_name_det}/INPUT


if [ ! -d ${WORK_DIR}/LOG ]; then
   mkdir -p ${WORK_DIR}/LOG
fi

ln -sf ${FIX_JEDIGLM} ./INPUT  # link grid info to work_dir
ln -sf ${FIX_JEDIGLM}/BUMP ./BUMP

set -x
# Setup YAML file variables
WINDOW_TIME_STR=`date -d "${ANL_TIME::8} ${ANL_TIME:8:4} -1 hour" +%Y-%m-%dT%H:%M:00Z`
ANL_TIME_STR=`date -d "${ANL_TIME::8} ${ANL_TIME:8:4}" +%Y-%m-%dT%H:%M:00Z`
YYYYMMDD_HHMM=`date -d "${ANL_TIME::8} ${ANL_TIME:8:4}" +%Y%m%d.%H%M`

sed "s/WINDOW_TIME/${WINDOW_TIME_STR}/g" < ${FIX_JEDIGLM}/fv3jedi_envar_lightning.yaml_template | \
   sed "s+EXPT_ROOT+${FIX_JEDIGLM}+g" | \
   sed "s+FV3NAMELIST+${FV3NAMELIST}+g" | \
   sed "s/ANALYSIS_TIME/${ANL_TIME_STR}/g" | \
   sed "s+BKG_DIR+${BKG_DIR}+g" | \
   sed "s/YYYYMMDD.HHMMSS/${YYYYMMDD_HHMM}00/g" | \
   sed "s+HOFX_OUT_FN+${HOFX_FED_OUT_FN}+g" | \
   sed "s+ENS_ROOT+${RRFSE_BKG_ROOT}+g" | \
   sed "s/FV3FCST_TYPE/${task_name_ens}/g" | \
   sed "s+FV3JEDI_DIAG_FN+${WORK_DIR}/${FV3JEDI_DIAG_FN}+g" | \
   sed "s+OUT_DIR+${WORK_DIR}+g" | \
   sed "s/DESC/${FV3JEDI_LIGHTNING_DESC}/g" > ${WORK_DIR}/fv3jedi_envar_lightning.yaml

cat ${WORK_DIR}/fv3jedi_envar_lightning.yaml
srun --export=ALL ${FV3JEDI_BINDIR}/fv3jedi_var.x fv3jedi_envar_lightning.yaml ${WORK_DIR}/LOG/LOG_VAR_LIGHTNING

#!/bin/bash

source /scratch2/BMC/zrtrr/bjallen/OUCAPS/modulefile.skylab6.rocky8-spack1.6.0
set -x

#cd /scratch2/BMC/zrtrr/bjallen/OUCAPS/CAPS_JEDI_lightning_testing

exec_dir=${FV3JEDI_BINDIR}
YAML=convert_UV.yaml
OUT_DIR=${JEDI_DIR}/convertstate

if [ ! -d ${OUT_DIR} ]; then
  mkdir -p ${OUT_DIR}
fi

cd ${OUT_DIR}

ANL_TIME_STR=`date -d "${ATIME::8} ${ATIME:8:4}" +%Y-%m-%dT%H:%M:00Z`

sed 's/LX,LY/2,2/1' < ${FIX_JEDIGLM}/GSL_fv3input_for_lightning_template > ${OUT_DIR}/GSL_fv3input_for_lightning_convert_UV.nml
cat GSL_fv3input_for_lightning_convert_UV.nml | grep -i "layout"

sed "s/CTIME/${CTIME}/g" < ${FIX_JEDIGLM}/convert_UV.yaml_template | \
   sed "s/ANALYSIS_TIME/${ANL_TIME_STR}/g" | \
   sed "s#EXPT_ROOT#${CYCLE_BASEDIR}#g" | \
   sed "s/CYCLE_TYPE/${CYCLE_TYPE}/g" > ${OUT_DIR}/${YAML}

cat convert_UV.yaml
ln -sf ${FIX_JEDIGLM} ./INPUT

srun --export=ALL ${FV3JEDI_BINDIR}/fv3jedi_convertstate.x ${OUT_DIR}/${YAML} ${OUT_DIR}/LOG_CONVERT_UV

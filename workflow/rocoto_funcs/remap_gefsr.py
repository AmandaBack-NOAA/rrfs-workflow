#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of ungrib_ic --------------------------------------------------------


def remap_gefsr(xmlFile, expdir, do_ensemble=True):
    meta_id = 'remap_gefsr'
    cycledefs = 'ic,lbc'
    #
    extrn_source_basedir = os.getenv('IC_EXTRN_MDL_BASEDIR', 'IC_PREFIX_not_defined')
    offset = int(os.getenv('LBC_OFFSET', '3'))
    gefsr_basedir = os.getenv('GEFSR_BASEDIR', '')
    degrees = os.getenv('DEGREES','25')
    # Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'EXT_DIR': f'{gefsr_basedir}',
        'EXT_INIT_TIME': f'<cyclestr offset="-{offset}:00:00">@Y@m@d@H</cyclestr>',
        'REMAP_DIR': f'<cyclestr offset="-{offset}:00:00">{extrn_source_basedir}</cyclestr>',
        'DEGREES':f'{degrees}',
    }
    #
    if not do_ensemble:
        metatask = False
        task_id = f'{meta_id}'
        meta_bgn = ""
        meta_end = ""
        ensindexstr = ""
    else:
        metatask = True
        task_id = f'{meta_id}_m#ens_index#'
        ensindexstr = "_m#ens_index#"
        dcTaskEnv['ENS_INDEX'] = "#ens_index#"
        ens_size = int(os.getenv('ENS_SIZE', '2'))
        ens_indices = ''.join(f'{i:03d} ' for i in range(1, int(ens_size) + 1)).strip()
        meta_bgn = f'''
<metatask name="{meta_id}">
<var name="ens_index">{ens_indices}</var>'''
        meta_end = f'\
</metatask>\n'
        ensindexstr = "_m#ens_index#"
    # dependencies
    timedep=""
    dependencies = f'''
  <dependency>
    <and>{timedep}
      <taskdep task="get_gefsr{ensindexstr}"/>
    </and>
  </dependency>'''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies,
             metatask, meta_id, meta_bgn, meta_end, "REMAP_GEFSR")
# end of remap_gefsr --------------------------------------------------------

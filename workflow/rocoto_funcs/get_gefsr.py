#!/usr/bin/env python
import os
from rocoto_funcs.base import xml_task, get_cascade_env

# begin of get_gefsr --------------------------------------------------------


def get_gefsr(xmlFile, expdir, do_ensemble=False):
    meta_id = 'get_gefsr'
    cycledefs = 'ic,lbc'
    #
    offset = int(os.getenv('LBC_OFFSET', '3'))
    length = int(os.getenv('LBC_LENGTH', '24'))
    gefsr_basedir = os.getenv('GEFSR_BASEDIR', '')

# Task-specific EnVars beyond the task_common_vars
    dcTaskEnv = {
        'EXT_DIR': f'{gefsr_basedir}',
        'EXT_INIT_TIME': f'<cyclestr offset="-{offset}:00:00">@Y@m@d@H</cyclestr>',
        'FCST_LENGTH': f'{length}',
        'OFFSET': f'{offset}',
        'LANDSFC_GRIB': f'{gefsr_basedir}/landsfc.pgrb2.0p50',
    }

    if not do_ensemble:
        meta_bgn = ""
        meta_end = ""
    #
    else:  # ensemble
        # metatask (support nested metatasks)
        metatask = True
        task_id = f'{meta_id}_m#ens_index#'
        dcTaskEnv['ENS_INDEX'] = "#ens_index#"
        ens_size = int(os.getenv('ENS_SIZE', '2'))
        ens_indices = ''.join(f'{i:03d} ' for i in range(1, int(ens_size) + 1)).strip()
        meta_bgn = f'''

<metatask name="{meta_id}">
<var name="ens_index">{ens_indices}</var>'''
        meta_end = f'\
</metatask>\n'
        ensindexstr = "_m#ens_index#"
    dependencies = f''
    #
    xml_task(xmlFile, expdir, task_id, cycledefs, dcTaskEnv, dependencies, True, meta_id, meta_bgn, meta_end, "GET_GEFSR")
# end of get_gefsr --------------------------------------------------------

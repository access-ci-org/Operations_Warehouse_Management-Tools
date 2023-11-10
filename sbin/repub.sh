#!/bin/bash

### RePublish Tool
APP_HOME=%APP_HOME%

# Override in shell environment
if [ -z "$PYTHON_BASE" ]; then
    PYTHON_BASE=%PYTHON_BASE%
fi

PYTHON_BIN=python3
export LD_LIBRARY_PATH=${PYTHON_BASE}/lib
source ${APP_HOME}/python/bin/activate

export PYTHONPATH=${APP_HOME}/PROS/lib:${WAREHOUSE_DJANGO}
export DJANGO_CONF=${APP_HOME}/conf/django_prod_router.conf
export DJANGO_SETTINGS_MODULE=Operations_Warehouse_Django.settinge

${PYTHON_BIN} ${APP_HOME}/PROD/bin/repub.py -c ${APP_HOME}/conf/repub.conf -r dummy.test.access-ci.org -i $@
RETVAL=$?
echo rc=$RETVAL
exit $RETVAL

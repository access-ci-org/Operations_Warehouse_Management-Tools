#!/bin/bash

###
# Run %APP_NAME%: Database backup
###

APP_NAME=database_backup
APP_HOME=%APP_HOME%

DBNAME1=warehouse2
DBHOST1=opsdb-dev.cluster-clabf5kcvwmz.us-east-2.rds.amazonaws.com
DBUSER1=info_django

DBNAME2=warehouse3
DBHOST2=opsdb-dev.cluster-clabf5kcvwmz.us-east-2.rds.amazonaws.com
DBUSER2=info_django

DBNAME3=warehouse_stg
DBHOST3=opsdb-dev.cluster-clabf5kcvwmz.us-east-2.rds.amazonaws.com
DBUSER3=info_django

S3DIR=s3://backup.operations.access-ci.org/operations-api.access-ci.org/rds.backup/

# Override in shell environment
if [ -z "$PYTHON_BASE" ]; then
    PYTHON_BASE=%PYTHON_BASE%
fi

####### Everything else should be standard #######

PYTHON_BIN=python3
export LD_LIBRARY_PATH=${PYTHON_BASE}/lib
source ${APP_HOME}/python/bin/activate

BACKUP_DIR=${APP_HOME}/backups/
[ ! -d ${BACKUP_DIR} ] && mkdir ${BACKUP_DIR}

exec 1>> ${BACKUP_DIR}/${APP_NAME}.log 2>&1
echo Starting at `date`

DATE=`date +'%s'`

### DATABASE 1 ###

DUMPNAME=django.${DBNAME1}.dump.${DATE}
pg_dump -h ${DBHOST1} -U ${DBUSER1} -n info_django -d ${DBNAME1} \
  --exclude-table=info_django.resource_v4_resourcev4 \
  --exclude-table=info_django.resource_v4_resourcev4local \
  --exclude-table=info_django.resource_v4_resourcev4relation \
  >${BACKUP_DIR}/${DUMPNAME}
gzip -9 ${BACKUP_DIR}/${DUMPNAME}
aws s3 cp ${BACKUP_DIR}/${DUMPNAME}.gz ${S3DIR} --only-show-errors --profile newbackup

# Minimum backup without history for development environments
MINDUMPNAME=django.${DBNAME1}.mindump.${DATE}
pg_dump -h ${DBHOST1} -U ${DBUSER1} -n info_django -d ${DBNAME1} \
  --exclude-table=info_django.resource_v4_resourcev4 \
  --exclude-table=info_django.resource_v4_resourcev4local \
  --exclude-table=info_django.resource_v4_resourcev4relation \
  --exclude-table=info_django.glue2_entityhistory \
  --exclude-table=info_django.warehouse_state_processingerror \
  >${BACKUP_DIR}/${MINDUMPNAME}
gzip -9 ${BACKUP_DIR}/${MINDUMPNAME}
aws s3 cp ${BACKUP_DIR}/${MINDUMPNAME}.gz ${S3DIR} --only-show-errors --profile newbackup

### DATABASE 2 ###

DUMPNAME=django.${DBNAME2}.dump.${DATE}
pg_dump -h ${DBHOST2} -U ${DBUSER2} -n info_django -n info -d ${DBNAME2} \
  --exclude-table=info_django.resource_v4_resourcev4 \
  --exclude-table=info_django.resource_v4_resourcev4local \
  --exclude-table=info_django.resource_v4_resourcev4relation \
  >${BACKUP_DIR}/${DUMPNAME}
gzip -9 ${BACKUP_DIR}/${DUMPNAME}
aws s3 cp ${BACKUP_DIR}/${DUMPNAME}.gz ${S3DIR} --only-show-errors --profile newbackup

# Minimum backup without history for development environments
MINDUMPNAME=django.${DBNAME2}.mindump.${DATE}
pg_dump -h ${DBHOST2} -U ${DBUSER2} -n info_django -n info -d ${DBNAME2} \
  --exclude-table=info_django.resource_v4_resourcev4 \
  --exclude-table=info_django.resource_v4_resourcev4local \
  --exclude-table=info_django.resource_v4_resourcev4relation \
  --exclude-table=info_django.glue2_entityhistory \
  --exclude-table=info_django.warehouse_state_processingerror \
  >${BACKUP_DIR}/${MINDUMPNAME}
gzip -9 ${BACKUP_DIR}/${MINDUMPNAME}
aws s3 cp ${BACKUP_DIR}/${MINDUMPNAME}.gz ${S3DIR} --only-show-errors --profile newbackup

### DATABASE 3 ###

DUMPNAME=django.${DBNAME3}.dump.${DATE}
pg_dump -h ${DBHOST3} -U ${DBUSER3} -n info_django -n info -d ${DBNAME3} \
  --exclude-table=info_django.resource_v4_resourcev4 \
  --exclude-table=info_django.resource_v4_resourcev4local \
  --exclude-table=info_django.resource_v4_resourcev4relation \
  >${BACKUP_DIR}/${DUMPNAME}
gzip -9 ${BACKUP_DIR}/${DUMPNAME}
aws s3 cp ${BACKUP_DIR}/${DUMPNAME}.gz ${S3DIR} --only-show-errors --profile newbackup

# Minimum backup without history for development environments

MINDUMPNAME=django.${DBNAME3}.mindump.${DATE}
pg_dump -h ${DBHOST3} -U ${DBUSER3} -n info_django -n info -d ${DBNAME3} \
  --exclude-table=info_django.resource_v4_resourcev4 \
  --exclude-table=info_django.resource_v4_resourcev4local \
  --exclude-table=info_django.resource_v4_resourcev4relation \
  --exclude-table=info_django.glue2_entityhistory \
  --exclude-table=info_django.warehouse_state_processingerror \
  >${BACKUP_DIR}/${MINDUMPNAME}
gzip -9 ${BACKUP_DIR}/${MINDUMPNAME}
aws s3 cp ${BACKUP_DIR}/${MINDUMPNAME}.gz ${S3DIR} --only-show-errors --profile newbackup

#aws s3 ls s3://xci.xsede.org/info.xsede.org/rds.backup/\*.${DATE} --profile newbackup

#Cleanup backups older than 2 days
find ${BACKUP_DIR} -mtime +2 -name \*dump\* -exec rm {} \;

# Delete s3 files older than seven days
let maxage=60*60*24*7
aws s3 ls ${S3DIR} --profile newbackup | awk '{print $4}' | while read filename
do
    fileepoch="$(cut -d'.' -f3 <<<"${filename}")"
    if [ -n "${fileepoch}" ] && [ "${fileepoch}" -eq "${fileepoch}" ] 2>/dev/null; then
        let fileage=${DATE}-${fileepoch}
        if [ "${fileage}" -gt "${maxage}" ]; then
            echo "s3 rm ${S3DIR}/${filename}"
            aws s3 rm ${S3DIR}/${filename} --profile newbackup
        fi
    fi
done

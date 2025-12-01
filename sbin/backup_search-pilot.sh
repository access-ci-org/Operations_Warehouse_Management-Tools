#!/bin/bash

###
# Run %APP_NAME%: Search Pilot databases backup
###

APP_NAME=search-pilot
APP_HOME=/soft/applications-2.0/warehouse_management

DBNAME1=ed_dgpf
DBHOST1=opsdb-dev.cluster-clabf5kcvwmz.us-east-2.rds.amazonaws.com
DBUSER1=ed_dgpf1user

S3DIR=s3://backup.operations.access-ci.org/search-pilot.operations.access-ci.org/rds.backup/

# Override in shell environment
if [ -z "$PYTHON_BASE" ]; then
    PYTHON_BASE=/usr
fi

####### Everything else should be standard #######

PYTHON_BIN=python3
export LD_LIBRARY_PATH=${PYTHON_BASE}/lib
source ${APP_HOME}/python/bin/activate

BACKUP_DIR=${APP_HOME}/backups/${APP_NAME}
[ ! -d ${BACKUP_DIR} ] && mkdir -p ${BACKUP_DIR}

exec 1>> ${BACKUP_DIR}/${APP_NAME}.log 2>&1
echo Starting at `date`

DATE=`date +'%s'`

DUMPNAME=django.${DBNAME1}.dump.${DATE}
pg_dump -h ${DBHOST1} -U ${DBUSER1} -n ed_dgpf1 -d ${DBNAME1} \
  >${BACKUP_DIR}/${DUMPNAME}
gzip -9 ${BACKUP_DIR}/${DUMPNAME}
aws s3 cp ${BACKUP_DIR}/${DUMPNAME}.gz ${S3DIR} --only-show-errors --profile newbackup

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

#!/bin/bash

###
# Run %APP_NAME%: Database backup
###

APP_NAME=database_backup
APP_HOME=%APP_HOME%
DBNAME=warehouse2
DBHOST=opsdb-dev.cluster-clabf5kcvwmz.us-east-2.rds.amazonaws.com
DBUSER=info_django
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

exec 1>> ${BACKUP_DIR}/${APP_NAME}.log
echo Starting at `date`

DATE=`date +'%s'`

# Using OS installed PostgreSQL tools
pg_dump -h ${DBHOST} -U ${DBUSER} -n public -d ${DBNAME} \
  >${BACKUP_DIR}/django.dump.${DATE}

#zip all dumps to save disk
gzip -9 ${BACKUP_DIR}/django.dump.${DATE}

aws s3 cp ${BACKUP_DIR}/django.dump.${DATE}.gz ${S3DIR} --only-show-errors --profile newbackup

#aws s3 ls s3://xci.xsede.org/info.xsede.org/rds.backup/\*.${DATE} --profile newbackup

#Cleanup backups older than 2 days
find ${BACKUP_DIR} -mtime +2 -name \*dump\* -exec rm {} \;

# Delete s3 files older than seven days
let maxage=60*60*24*7
aws s3 ls ${S3DIR} --profile newbackup | awk '{print $4}' | while read filename
do
    echo "${filename}"
    fileepoch="$(cut -d'.' -f3 <<<"${filename}")"
    if [ -n "${fileepoch}" ] && [ "${fileepoch}" -eq "${fileepoch}" ] 2>/dev/null; then
        let fileage=${DATE}-${fileepoch}
        if [ "${fileage}" -gt "${maxage}" ]; then
            aws s3 rm ${S3DIR}/${filename} --profile newbackup
        fi
    fi
done

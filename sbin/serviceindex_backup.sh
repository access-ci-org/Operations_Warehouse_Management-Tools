#!/bin/bash

###
# Run warehouse_management: Database backup
###

APP_NAME=service-index
APP_HOME=/soft/applications-2.0/warehouse_management
DBNAME=serviceindex1
DBHOST=opsdb-dev.cluster-clabf5kcvwmz.us-east-2.rds.amazonaws.com
DBUSER=serviceindex_django
S3DIR=s3://backup.operations.access-ci.org/service-index.operations.access-ci.org/rds.backup/

# Override in shell environment
if [ -z "$PYTHON_BASE" ]; then
    PYTHON_BASE=/usr
fi

####### Everything else should be standard #######

PYTHON_BIN=python3
export LD_LIBRARY_PATH=${PYTHON_BASE}/lib
source ${APP_HOME}/python/bin/activate

BACKUP_DIR=${APP_HOME}/backups/serviceindex/
[ ! -d ${BACKUP_DIR} ] && mkdir -p ${BACKUP_DIR}

exec 1>> ${BACKUP_DIR}/${APP_NAME}.log
echo Starting at `date`

DATE=`date +'%s'`

# Using OS installed PostgreSQL tools
pg_dump -h ${DBHOST} -U ${DBUSER} -n public -d ${DBNAME} \
    -t serviceindex.availability -t serviceindex.site -t serviceindex.staff -t serviceindex.support \
    -t serviceindex.service -t serviceindex.host -t serviceindex.link -t serviceindex.logentry \
    -t serviceindex.event -t serviceindex.hosteventlog -t serviceindex.hosteventstatus \
    -t serviceindex.misc_urls \
  >${BACKUP_DIR}/django.dump.${DATE}

#pg_dump -h ${DBHOST} -U ${DBUSER} -n public -d ${DBNAME} \
#  >${BACKUP_DIR}/django.dump.${DATE}
# Minimum backup without history for development environments
#pg_dump -h ${DBHOST} -U ${DBUSER} -n public -d ${DBNAME} --exclude-table=public.glue2_entityhistory --exclude-table=public.warehouse_state_processingerror \
#  >${BACKUP_DIR}/django.mindump.${DATE}

#zip all dumps to save disk
gzip -9 ${BACKUP_DIR}/django.dump.${DATE}
#gzip -9 ${BACKUP_DIR}/django.mindump.${DATE}

aws s3 cp ${BACKUP_DIR}/django.dump.${DATE}.gz ${S3DIR} --only-show-errors --profile newbackup
#aws s3 cp ${BACKUP_DIR}/django.mindump.${DATE}.gz ${S3DIR} --only-show-errors --profile newbackup

#aws s3 ls s3://xci.xsede.org/info.xsede.org/rds.backup/\*.${DATE} --profile newbackup

#Cleanup backups older than 2 days
#find ${BACKUP_DIR} -mtime +2 -name \*dump\* -exec rm {} \;

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

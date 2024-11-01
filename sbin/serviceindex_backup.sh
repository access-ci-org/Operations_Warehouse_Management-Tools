#!/bin/bash

###
# Run warehouse_management: Service Index databases backup
###

APP_NAME=service-index
APP_HOME=/soft/applications-2.0/warehouse_management

DBNAME1=serviceindex1
DBHOST1=opsdb-dev.cluster-clabf5kcvwmz.us-east-2.rds.amazonaws.com
DBUSER1=serviceindex_django

DBNAME2=serviceindex2
DBHOST2=${DBHOST1}
DBUSER2=${DBUSER1}

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

DUMPNAME=django.${DBNAME1}.dump.${DATE}
pg_dump -h ${DBHOST1} -U ${DBUSER1} -n public -d ${DBNAME1} \
    -t serviceindex.availability -t serviceindex.site -t serviceindex.staff -t serviceindex.support \
    -t serviceindex.service -t serviceindex.host -t serviceindex.link -t serviceindex.logentry \
    -t serviceindex.event -t serviceindex.hosteventlog -t serviceindex.hosteventstatus \
    -t serviceindex.misc_urls \
  >${BACKUP_DIR}/${DUMPNAME}
gzip -9 ${BACKUP_DIR}/${DUMPNAME}
aws s3 cp ${BACKUP_DIR}/${DUMPNAME}.gz ${S3DIR} --only-show-errors --profile newbackup

DUMPNAME=django.${DBNAME2}.dump.${DATE}
pg_dump -h ${DBHOST2} -U ${DBUSER2} -n public -d ${DBNAME2} \
    -t serviceindex.availability -t serviceindex.site -t serviceindex.staff -t serviceindex.support \
    -t serviceindex.service -t serviceindex.host -t serviceindex.link -t serviceindex.logentry \
    -t serviceindex.event -t serviceindex.hosteventlog -t serviceindex.hosteventstatus \
    -t serviceindex.misc_urls \
  >${BACKUP_DIR}/${DUMPNAME}
gzip -9 ${BACKUP_DIR}/${DUMPNAME}
aws s3 cp ${BACKUP_DIR}/${DUMPNAME}.gz ${S3DIR} --only-show-errors --profile newbackup

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

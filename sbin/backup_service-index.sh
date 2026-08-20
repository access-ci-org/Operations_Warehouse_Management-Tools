 #!/bin/bash

###
# Run %APP_NAME%: Service Index databases backup
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

####### Everything else should be standard #######

AWS_COMMAND="/usr/local/bin/uv run --project ${APP_HOME} aws"

BACKUP_DIR=${APP_HOME}/backups/${APP_NAME}
[ ! -d ${BACKUP_DIR} ] && mkdir -p ${BACKUP_DIR}

exec 1>> ${BACKUP_DIR}/${APP_NAME}.log 2>&1
echo Starting at `date`

DATE=`date +'%s'`
DUMPNAME=django.${DBNAME1}.dump.${DATE}
pg_dump -h ${DBHOST1} -U ${DBUSER1} -n serviceindex_django -d ${DBNAME1} \
  >${BACKUP_DIR}/${DUMPNAME}
gzip -9 ${BACKUP_DIR}/${DUMPNAME}
${AWS_COMMAND} s3 cp ${BACKUP_DIR}/${DUMPNAME}.gz ${S3DIR} --only-show-errors --profile newbackup

DATE=`date +'%s'`
DUMPNAME=django.${DBNAME2}.dump.${DATE}
pg_dump -h ${DBHOST2} -U ${DBUSER2} -n serviceindex_django -d ${DBNAME2} \
  >${BACKUP_DIR}/${DUMPNAME}
gzip -9 ${BACKUP_DIR}/${DUMPNAME}
${AWS_COMMAND} s3 cp ${BACKUP_DIR}/${DUMPNAME}.gz ${S3DIR} --only-show-errors --profile newbackup

#Cleanup backups older than 2 days
find ${BACKUP_DIR} -mtime +2 -name \*dump\* -exec rm {} \;

# Delete s3 files older than seven days
let maxage=60*60*24*7
${AWS_COMMAND} s3 ls ${S3DIR} --profile newbackup | awk '{print $4}' | while read filename
do
    fileepoch="$(cut -d'.' -f4 <<<"${filename}")"
    if [ -n "${fileepoch}" ] && [ "${fileepoch}" -eq "${fileepoch}" ] 2>/dev/null; then
        let fileage=${DATE}-${fileepoch}
        if [ "${fileage}" -gt "${maxage}" ]; then
            fqfile="${S3DIR%/}/${filename}"
            echo "s3 rm ${fqfile}"
            ${AWS_COMMAND} s3 rm ${fqfile} --profile newbackup
        fi
    fi
done

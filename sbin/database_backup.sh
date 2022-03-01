#!/bin/bash
MY_BASE=/soft/warehouse-apps-1.0/Management-Tools

PYTHON=python3
PYTHON_BASE=/soft/python/python-3.8.11-base
export LD_LIBRARY_PATH=${PYTHON_BASE}/lib
PYTHON_ROOT=/soft/awscli/python
source ${PYTHON_ROOT}/bin/activate

BACKUP_DIR=${MY_BASE}/backups/
[ ! -d ${BACKUP_DIR} ] && mkdir ${BACKUP_DIR}

exec 1>> ${BACKUP_DIR}/database_backup.log
echo Starting at `date`

DBHOST=information-warehouse-prod-cluster.cluster-clabf5kcvwmz.us-east-2.rds.amazonaws.com
DATE=`date +'%s'`

/usr/pgsql-13/bin/pg_dump -h ${DBHOST} -U django_owner -n django -d warehouse \
  >${BACKUP_DIR}/django.dump.${DATE}

/usr/pgsql-13/bin/pg_dump -h ${DBHOST} -U xcsr_owner -n xcsr -d warehouse \
  >${BACKUP_DIR}/xcsr.dump.${DATE}

/usr/pgsql-13/bin/pg_dump -h ${DBHOST} -U glue2_owner -n glue2 -d warehouse --exclude-table-data=glue2_db_entityhistory \
  >${BACKUP_DIR}/glue2.dump.${DATE}

#zip all dumps to save disk
gzip -9 ${BACKUP_DIR}/django.dump.${DATE}
gzip -9 ${BACKUP_DIR}/xcsr.dump.${DATE}
gzip -9 ${BACKUP_DIR}/glue2.dump.${DATE}

aws s3 cp ${BACKUP_DIR}/django.dump.${DATE}.gz s3://xci.xsede.org/info.xsede.org/rds.backup/ --only-show-errors --profile newbackup
aws s3 cp ${BACKUP_DIR}/xcsr.dump.${DATE}.gz s3://xci.xsede.org/info.xsede.org/rds.backup/ --only-show-errors --profile newbackup
aws s3 cp ${BACKUP_DIR}/glue2.dump.${DATE}.gz s3://xci.xsede.org/info.xsede.org/rds.backup/ --only-show-errors --profile newbackup

#aws s3 ls s3://xci.xsede.org/info.xsede.org/rds.backup/\*.${DATE} --profile newbackup

#Cleanup backups older than 2 days
find ${BACKUP_DIR} -mtime +2 -name \*dump\* -exec rm {} \;

# Delete s3 files older than seven days
let maxage=60*60*24*7
aws s3 ls s3://xci.xsede.org/info.xsede.org/rds.backup/ --profile newbackup | awk '{print $4}' | while read filename
do
    echo "${filename}"
    fileepoch="$(cut -d'.' -f3 <<<"${filename}")"
    if [ -n "${fileepoch}" ] && [ "${fileepoch}" -eq "${fileepoch}" ] 2>/dev/null; then
        let fileage=${DATE}-${fileepoch}
        if [ "${fileage}" -gt "${maxage}" ]; then
            aws s3 rm s3://xci.xsede.org/info.xsede.org/rds.backup/${filename} --profile newbackup
        fi
    fi
done

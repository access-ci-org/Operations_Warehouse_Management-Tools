#!/bin/bash
OUTDIR=/var/cache/database_backup/
exec 1>> ${OUTDIR}/database_backup.log
echo Starting at `date`

LD_LIBRARY_PATH=/soft/python/python-3.8.11-base/lib
export LD_LIBRARY_PATH

DBHOST=information-warehouse-prod-cluster.cluster-clabf5kcvwmz.us-east-2.rds.amazonaws.com

DATE=`date +'%s'`


/usr/pgsql-13/bin/pg_dump -h ${DBHOST} -U django_owner -n django  -d warehouse \
  >$OUTDIR/django.dump.$DATE

/usr/pgsql-13/bin/pg_dump -h ${DBHOST} -U xcsr_owner -n xcsr  -d warehouse \
  >$OUTDIR/xcsr.dump.$DATE

/usr/pgsql-13/bin/pg_dump -h ${DBHOST} -U glue2_owner -n glue2  -d warehouse --exclude-table-data=glue2_db_entityhistory \
  >$OUTDIR/glue2.dump.$DATE

#zip all dumps to save disk
gzip -9 $OUTDIR/django.dump.$DATE
gzip -9 $OUTDIR/xcsr.dump.$DATE
gzip -9 $OUTDIR/glue2.dump.$DATE

. /soft/python-pipenv/python-3.8.11-awscli/bin/activate

aws s3 cp $OUTDIR/django.dump.$DATE.gz s3://xci.xsede.org/info.xsede.org/rds.backup/ --profile newbackup
aws s3 cp $OUTDIR/xcsr.dump.$DATE.gz s3://xci.xsede.org/info.xsede.org/rds.backup/ --profile newbackup
aws s3 cp $OUTDIR/glue2.dump.$DATE.gz s3://xci.xsede.org/info.xsede.org/rds.backup/ --profile newbackup

#Cleanup backups older than 2 days
find /var/cache/database_backup -mtime +2 -name \*dump\* -exec rm {} \;

# Delete s3 files older than seven days
let maxage=60*60*24*7
aws s3 ls s3://xci.xsede.org/info.xsede.org/rds.backup/ --profile newbackup | awk '{print $4}' | while read filename
do
    #echo "${filename}"
    fileepoch="$(cut -d'.' -f3 <<<"${filename}")"
    if [ -n "${fileepoch}" ] && [ "${fileepoch}" -eq "${fileepoch}" ] 2>/dev/null; then
        let fileage=${DATE}-${fileepoch}
        if [ "${fileage}" -gt "${maxage}" ]; then
            aws s3 rm s3://xci.xsede.org/info.xsede.org/rds.backup/${filename} --profile newbackup
        fi
    fi
done

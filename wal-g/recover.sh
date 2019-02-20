#!/bin/bash

if [ $(id -u) == "0" ] ; then
  echo "this command must be run as the postgres user."
  exit 1
fi

set -e

if [ -z ${PGDATA+x} ]; then
  export PGDATA=/var/lib/postgresql/data/pgsql
fi

# fetch most recent full backup
wal-g backup-fetch $PGDATA LATEST

# enable recovery mode, disable remote connections and archive mode
cp /wal-g/recovery.conf $PGDATA/
mv $PGDATA/pg_hba.conf $PGDATA/pg_hba.conf.orig
cp /wal-g/pg_hba.conf $PGDATA/pg_hba.conf
sed -i -e 's/^archive_mode = on/archive_mode = off/' $PGDATA/postgresql.conf

PG_VERSION=$(ls /usr/lib/postgresql/)

/usr/lib/postgresql/$PG_VERSION/bin/pg_ctl start -D $PGDATA

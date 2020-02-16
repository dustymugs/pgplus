#!/bin/bash

set -e

if [ -z ${PGDATA+x} ]; then
  export PGDATA=/var/lib/postgresql/data/pgsql
fi

export PG_VERSION=$(ls /usr/lib/postgresql/)

# disable recovery mode, re-enable remote connections and archive mode
mv $PGDATA/pg_hba.conf.orig $PGDATA/pg_hba.conf
mv $PGDATA/postgresql.conf.orig $PGDATA/postgresql.conf
sed -i -e 's/^archive_mode = off/archive_mode = on/' $PGDATA/postgresql.conf

cat <<EOF
******************
* Recovery mode complete; postgresql is shutting down.
* You should now restart the server container in normal mode to resume
* regular operation.
******************
EOF

bash -c "sleep 3 && /usr/lib/postgresql/$PG_VERSION/bin/pg_ctl stop -D $PGDATA" &


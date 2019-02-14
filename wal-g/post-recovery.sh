#!/bin/bash

set -e

export DATA=/var/lib/postgresql/data/pgsql
export PG_VERSION=$(ls /usr/lib/postgresql/)

# disable recovery mode, re-enable remote connections and archive mode
mv $DATA/pg_hba.conf.orig $DATA/pg_hba.conf
sed -i -e 's/^archive_mode = off/archive_mode = on/' $DATA/postgresql.conf

cat <<EOF
******************
* Recovery mode complete; postgresql is shutting down.
* You should now restart the server container in normal mode to resume
* regular operation.
******************
EOF

bash -c "sleep 3 && /usr/lib/postgresql/$PG_VERSION/bin/pg_ctl stop -D $DATA" &


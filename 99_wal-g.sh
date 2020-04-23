#!/bin/bash

set -e

# modify $PGDATA/postgresql.conf
mkdir -p $PGDATA/conf.d
echo "include_dir = 'conf.d'" >> $PGDATA/postgresql.conf

if [ -n "$POSTGRES_IS_STANDBY" -a -z "$POSTGRES_PRIMARY_CONNINFO" ]; then
	echo "POSTGRES_PRIMARY_CONNINFO required if POSTGRES_IS_STANDBY set"
	exit 1
fi

# add replication auth
echo "host   replication     ${POSTGRES_USER}                                     md5" > $PGDATA/pg_hbda.conf

# add wal-e.conf
cat << EOF > $PGDATA/conf.d/wal-e.conf
wal_level = replica

archive_mode = on
archive_command = 'wal-g wal-push "%p"'
archive_timeout = 60

restore_command = 'wal-g wal-fetch "%f" "%p"'

wal_keep_segments = 60

primary_conninfo = '${POSTGRES_PRIMARY_CONNINFO}'
EOF

if [ -n "$POSTGRES_IS_STANDBY" ]; then
	# pull most recent full backup
	wal-g backup-fetch $PGDATA LATEST

	# indicate that this instance is to be a standby
	touch $PGDATA/standby.signal
fi

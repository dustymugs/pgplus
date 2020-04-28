#!/bin/bash

set -e

POSTGRES_UNIX_SOCKET_DIRECTORIES=${POSTGRES_UNIX_SOCKET_DIRECTORIES:-/var/run/postgresql}

# modify $PGDATA/postgresql.conf
mkdir -p $PGDATA/conf.d
echo "include_dir = 'conf.d'" >> $PGDATA/postgresql.conf

# add local.conf
cat << EOF > $PGDATA/conf.d/local.conf
port = ${POSTGRES_PORT}
unix_socket_directories = '${POSTGRES_UNIX_SOCKET_DIRECTORIES}'

ssl = on
ssl_cert_file = '/etc/ssl/certs/pgplus.pem'
ssl_key_file = '/etc/ssl/private/pgplus.key'

wal_level = replica

checkpoint_timeout = 60

archive_mode = ${POSTGRES_ARCHIVE_MODE}
archive_command = 'wal-g wal-push "%p"'
archive_timeout = 60

restore_command = 'wal-g wal-fetch "%f" "%p"'

wal_keep_segments = 60

primary_conninfo = '${POSTGRES_PRIMARY_CONNINFO}'
EOF

# add replication auth
echo "host    replication    ${POSTGRES_USER}    0.0.0.0/0    md5" >> $PGDATA/pg_hba.conf
echo "host    replication    ${POSTGRES_USER}    ::0/0    md5" >> $PGDATA/pg_hba.conf

if [ -n "$POSTGRES_IS_STANDBY" ]; then
	# indicate that this instance is to be a standby
	touch $PGDATA/standby.signal
fi

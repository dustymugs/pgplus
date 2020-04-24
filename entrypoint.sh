#!/bin/bash

set -e

POSTGRES_USER=${POSTGRES_USER:-postgres}

if [ -n "$POSTGRES_RESTORE" ]; then

	# shouldn't exist, but just in case
	if [ -s "$PGDATA/PG_VERSION" ]; then
		mv "$PGDATA" "${PGDATA}.old"
	fi

	# download latest base-backup
	gosu postgres wal-g backup-fetch $PGDATA LATEST

	# update primary_conninfo if value provided
	if [ -n "$POSTGRES_PRIMARY_CONNINFO" ]; then
		sed -i "s~^primary_conninfo = .*~primary_conninfo = '${POSTGRES_PRIMARY_CONNINFO}'~" "$PGDATA/conf.d/wal-e.conf"
	fi

	if [ -n "$POSTGRES_IS_STANDBY" ]; then
		# indicate that this instance is to be a standby
		touch "$PGDATA/standby.signal"
	fi
fi

# create certs
if [ ! -f /etc/ssl/private/pgplus.key ]; then
	openssl req -new -subj "/C=US/ST=Ohio/L=Columbus/O=PGPlus/OU=PGPlus/CN=pgplus.local" -x509 -days 365 -nodes -out /etc/ssl/certs/pgplus.pem -keyout /etc/ssl/private/pgplus.key
	chmod 644 /etc/ssl/certs/pgplus.pem
	chmod 600 /etc/ssl/private/pgplus.key
	chown postgres:postgres /etc/ssl/certs/pgplus.pem /etc/ssl/private/pgplus.key
fi

# create /etc/pgbouncer/local.ini config
if [ ! -f /etc/pgbouncer/local.ini ]; then
	cat << EOF > /etc/pgbouncer/local.ini
[databases]
* = host=localhost

[pgbouncer]

logfile = $PGBOUNCER_LOGFILE
pidfile = $PGBOUNCER_PIDFILE

listen_addr = $PGBOUNCER_LISTEN_ADDR
listen_port = $PGBOUNCER_LISTEN_PORT

unix_socket_dir = ${POSTGRES_UNIX_SOCKET_DIRECTORIES:-/var/run/postgresql}

client_tls_sslmode = $PGBOUNCER_CLIENT_TLS_SSLMODE
client_tls_key_file = $PGBOUNCER_CLIENT_TLS_KEY_FILE
client_tls_cert_file = $PGBOUNCER_CLIENT_TLS_CERT_FILE

server_tls_sslmode = $PGBOUNCER_SERVER_TLS_SSLMODE

auth_type = $PGBOUNCER_AUTH_TYPE
auth_user = $POSTGRES_USER

admin_users = $POSTGRES_USER

pool_mode = $PGBOUNCER_POOL_MODE

max_client_conn = $PGBOUNCER_MAX_CLIENT_CONN
default_pool_size = $PGBOUNCER_DEFAULT_POOL_SIZE
min_pool_size = $PGBOUNCER_MIN_POOL_SIZE
reserve_pool_size = $PGBOUNCER_RESERVE_POOL_SIZE
reserve_pool_timeout = $PGBOUNCER_RESERVE_POOL_TIMEOUT
max_db_connections = $PGBOUNCER_MAX_DB_CONNECTIONS
max_user_connections = $PGBOUNCER_MAX_USER_CONNECTIONS
EOF
	chown postgres:postgres /etc/pgbouncer/local.ini

	MD5HASH=`echo -n "${POSTGRES_PASSWORD}${POSTGRES_USER}" | md5sum | awk 'BEGIN {FS=" "};{print $1}'`
	echo "\"${POSTGRES_USER}\" \"md5${MD5HASH}\"" > /etc/pgbouncer/userlist.txt
fi

# start pgbouncer
(/etc/init.d/pgbouncer start || true)

# run postgresql's entrypoint script
exec /docker-entrypoint.sh "$@"

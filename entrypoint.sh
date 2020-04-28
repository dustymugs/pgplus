#!/bin/bash

POSTGRES_USER=${POSTGRES_USER:-postgres}

PODINFO_LABELS="/etc/podinfo/labels"

if [ -z "$POSTGRES_PRIMARY_CONNINFO" -a -n "$POSTGRES_MASTER_DNS_NAME" ]; then
	export POSTGRES_PRIMARY_CONNINFO="host=${POSTGRES_MASTER_DNS_NAME} port=${POSTGRES_PORT} user=${POSTGRES_USER} password=${POSTGRES_PASSWORD}"
fi

# k8s labels
if [ -f "$PODINFO_LABELS" ]; then
	echo "$PODINFO_LABELS found"
	finished=`cat "$PODINFO_LABELS" | grep "^done=\".+\"" | wc -l`
	while [ finished -ne 1 ]; do
		sleep 5
		finished=`cat "$PODINFO_LABELS" | grep "^done=\".+\"" | wc -l`
		echo "Pod config *NOT* done"
	done

	echo "Pod config done"

	export POSTGRES_IS_STANDBY=$(grep "^is_standby=" "$PODINFO_LABELS" | awk 'BEGIN{FS="="};{print $2}' | sed --expression 's~"~~g')

	export POSTGRES_RESTORE=$(grep "^restore=" "$PODINFO_LABELS" | awk 'BEGIN{FS="="};{print $2}' | sed --expression 's~"~~g')

	# TODO add watcher daemon to monitor k8s label changes
fi

if [ -n "$POSTGRES_IS_STANDBY" -a -z "$POSTGRES_PRIMARY_CONNINFO" ]; then
	echo "POSTGRES_PRIMARY_CONNINFO required if POSTGRES_IS_STANDBY set"
	exit 1
fi

if [ -n "$POSTGRES_RESTORE" ]; then
	# shouldn't exist, but just in case
	if [ -s "$PGDATA/PG_VERSION" ]; then
		mv "$PGDATA" "${PGDATA}.old"
	fi

	# download latest base-backup
	while :; do
		echo -n "Downloading latest base-backup... "
		gosu postgres wal-g backup-fetch $PGDATA LATEST
		result="$?"
		if [ "$result" = "0" ]; then
			echo "success"
			break
		fi
		echo "failed"
		sleep 60
	done

	# update primary_conninfo if value provided
	if [ -n "$POSTGRES_PRIMARY_CONNINFO" ]; then
		sed -i "s~^primary_conninfo = .*~primary_conninfo = '${POSTGRES_PRIMARY_CONNINFO}'~" "$PGDATA/conf.d/wal-e.conf"
	fi

	if [ -n "$POSTGRES_IS_STANDBY" ]; then
		# indicate that this instance is to be a standby
		touch "$PGDATA/standby.signal"
	fi
fi

set -e

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
* =

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

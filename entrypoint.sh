#!/bin/bash

set -e

if [ -z "$POSTGRES_PASSWORD" ]; then
	echo "Environment variable POSTGRES_PASSWORD required"
	exit 1
fi

# create certs
openssl req -new -subj "/C=US/ST=Ohio/L=Columbus/O=Acme Company/OU=Acme/CN=example.com" -x509 -days 365 -nodes -out /etc/ssl/certs/pgplus.pem -keyout /etc/ssl/private/pgplus.key
chmod 644 /etc/ssl/certs/pgplus.pem
chmod 600 /etc/ssl/private/pgplus.key
chown postgres:postgres /etc/ssl/certs/pgplus.pem /etc/ssl/private/pgplus.key

# update wal-g config

# create /etc/pgbouncer/local.ini config
cat << EOF > /etc/pgbouncer/local.ini
[databases]
* = host=localhost

[pgbouncer]

logfile = ${PGBOUNCER_LOGFILE:-/var/log/postgresql/pgbouncer.log}
pidfile = ${PGBOUNCER_PID_FILE:-/var/run/postgresql/pgbouncer.pid}

listen_addr = ${PGBOUNCER_LISTEN_ADDR:-*}
listen_port = ${PGBOUNCER_LISTEN_PORT:-6432}

client_tls_sslmode = ${PGBOUNCER_CLIENT_TLS_SSLMODE:-allow}
client_tls_key_file = ${PGBOUNCER_CLIENT_TLS_KEY_FILE:-/etc/ssl/private/pgplus.key}
client_tls_cert_file = ${PGBOUNCER_CLIENT_TLS_CERT_FILE:-/etc/ssl/certs/pgplus.pem}

server_tls_sslmode = ${PGBOUNCER_SERVER_TLS_SSLMODE:-allow}

auth_type = ${PGBOUNCER_AUTH_TYPE:-md5}
auth_user = $POSTGRES_USER

admin_users = $POSTGRES_USER

pool_mode = ${PGBOUNCER_POOL_MODE:-session}

max_client_conn = ${PGBOUNCER_MAX_CLIENT_CONN:-100}
default_pool_size = ${PGBOUNCER_DEFAULT_POOL_SIZE:-20}
min_pool_size = ${PGBOUNCER_MIN_POOL_SIZE:-0}
reserve_pool_size = ${PGBOUNCER_RESERVE_POOL_SIZE:-0}
reserve_pool_timeout = ${PGBOUNCER_RESERVE_POOL_TIMEOUT:-5}
max_db_connections = ${PGBOUNCER_MAX_DB_CONNECTIONS:-0}
max_user_connections = ${PGBOUNCER_MAX_USER_CONNECTIONS:-0}
EOF
chown postgres:postgres /etc/pgbouncer/local.ini

MD5HASH=`echo -n "${POSTGRES_PASSWORD}${POSTGRES_USER}" | md5sum | awk 'BEGIN {FS=" "};{print $1}'`
echo "\"${POSTGRES_USER}\" \"md5${MD5HASH}\"" > /etc/pgbouncer/userlist.txt

# start pgbouncer
#/etc/init.d/pgbouncer start

# let postgresql's take over
exec /docker-entrypoint.sh "$@"

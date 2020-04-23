#!/bin/bash

set -e

POSTGRES_USER=${POSTGRES_USER:-postgres}

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

logfile = $PGBOUNCER_LOGFILE
pidfile = $PGBOUNCER_PIDFILE

listen_addr = $PGBOUNCER_LISTEN_ADDR
listen_port = $PGBOUNCER_LISTEN_PORT

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

# start pgbouncer
/etc/init.d/pgbouncer start

# run postgresql's entrypoint script
exec /docker-entrypoint.sh "$@"

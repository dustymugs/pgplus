#
# docker build -f Dockerfile -t dustymugs/pgplus:12-3.0 . --build-arg POSTGIS_RELEASE=12-3.0
#
# docker run --rm -p 5432:5432 \
# 	-e POSTGRES_USER=myusername \
# 	-e POSTGRES_PASSWORD=mypassword \
# 	-e AWS_ACCESS_KEY_ID=myaccesskey \
# 	-e AWS_SECRET_ACCESS_KEY=mysecretaccesskey \
# 	-e AWS_ENDPOINT=myendpiont \
# 	-e WALG_S3_PREFIX=s3://my/path/to/ \
# 	-e POSTGRES_INITDB_ARGS="--data-checksums" \
# 	-e POSTGRES_PRIMARY_CONNINFO="host=master port=5432 user=myusername password=mypassword" \
# 	-d \
# 	dustymugs/pgplus:12-3.0
#

ARG POSTGIS_RELEASE=12-3.0

FROM postgis/postgis:$POSTGIS_RELEASE

ARG WALG_RELEASE=v0.2.14
ARG PGBOUNCER_RELEASE=1.12.0

ARG PGBOUNCER_LOGFILE=/var/log/postgresql/pgbouncer.log
ARG PGBOUNCER_PIDFILE=/var/run/postgresql/pgbouncer.pid
ARG PGBOUNCER_LISTEN_ADDR=*
ARG PGBOUNCER_LISTEN_PORT=6432
ARG PGBOUNCER_CLIENT_TLS_SSLMODE=allow
ARG PGBOUNCER_CLIENT_TLS_KEY_FILE=/etc/ssl/private/pgplus.key
ARG PGBOUNCER_CLIENT_TLS_CERT_FILE=/etc/ssl/certs/pgplus.pem
ARG PGBOUNCER_SERVER_TLS_SSLMODE=allow
ARG PGBOUNCER_AUTH_TYPE=md5
ARG PGBOUNCER_POOL_MODE=transaction
ARG PGBOUNCER_MAX_CLIENT_CONN=100
ARG PGBOUNCER_DEFAULT_POOL_SIZE=20
ARG PGBOUNCER_MIN_POOL_SIZE=0
ARG PGBOUNCER_RESERVE_POOL_SIZE=0
ARG PGBOUNCER_RESERVE_POOL_TIMEOUT=5
ARG PGBOUNCER_MAX_DB_CONNECTIONS=0
ARG PGBOUNCER_MAX_USER_CONNECTIONS=0

# if not empty, wal-g will fetch latest base backup and restore to $PGDATA
ENV POSTGRES_RESTORE=""

# if not empty, we touch the empty file $PGDATA/standby.signal
ENV POSTGRES_IS_STANDBY=""

# https://www.postgresql.org/docs/12/libpq-connect.html#LIBPQ-CONNSTRING
# if POSTGRES_IS_STANDBY is not empty, this must be provided
ENV POSTGRES_PRIMARY_CONNINFO=""

ENV PGBOUNCER_LOGFILE=$PGBOUNCER_LOGFILE
ENV PGBOUNCER_PIDFILE=$PGBOUNCER_PIDFILE
ENV PGBOUNCER_LISTEN_ADDR=$PGBOUNCER_LISTEN_ADDR
ENV PGBOUNCER_LISTEN_PORT=$PGBOUNCER_LISTEN_PORT
ENV PGBOUNCER_CLIENT_TLS_SSLMODE=$PGBOUNCER_CLIENT_TLS_SSLMODE
ENV PGBOUNCER_CLIENT_TLS_KEY_FILE=$PGBOUNCER_CLIENT_TLS_KEY_FILE
ENV PGBOUNCER_CLIENT_TLS_CERT_FILE=$PGBOUNCER_CLIENT_TLS_CERT_FILE
ENV PGBOUNCER_SERVER_TLS_SSLMODE=$PGBOUNCER_SERVER_TLS_SSLMODE
ENV PGBOUNCER_AUTH_TYPE=$PGBOUNCER_AUTH_TYPE
ENV PGBOUNCER_POOL_MODE=$PGBOUNCER_POOL_MODE
ENV PGBOUNCER_MAX_CLIENT_CONN=$PGBOUNCER_MAX_CLIENT_CONN
ENV PGBOUNCER_DEFAULT_POOL_SIZE=$PGBOUNCER_DEFAULT_POOL_SIZE
ENV PGBOUNCER_MIN_POOL_SIZE=$PGBOUNCER_MIN_POOL_SIZE
ENV PGBOUNCER_RESERVE_POOL_SIZE=$PGBOUNCER_RESERVE_POOL_SIZE
ENV PGBOUNCER_RESERVE_POOL_TIMEOUT=$PGBOUNCER_RESERVE_POOL_TIMEOUT
ENV PGBOUNCER_MAX_DB_CONNECTIONS=$PGBOUNCER_MAX_DB_CONNECTIONS
ENV PGBOUNCER_MAX_USER_CONNECTIONS=$PGBOUNCER_MAX_USER_CONNECTIONS

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -qq && \
    apt-get install -qqy curl ca-certificates libsodium23 vim && \
    cd /usr/local/bin && curl -L https://github.com/wal-g/wal-g/releases/download/$WALG_RELEASE/wal-g.linux-amd64.tar.gz | tar xzf - 

COPY wal-g /wal-g

RUN apt-get install -qqy pgbouncer && \
		echo "%include /etc/pgbouncer/local.ini" >> /etc/pgbouncer/pgbouncer.ini && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /pgplus-docker-entrypoint.sh
RUN chmod a+x /pgplus-docker-entrypoint.sh

COPY 99_wal-g.sh /docker-entrypoint-initdb.d
RUN chmod a+x /docker-entrypoint-initdb.d/99_wal-g.sh

ENTRYPOINT ["/pgplus-docker-entrypoint.sh"]
CMD ["postgres"]

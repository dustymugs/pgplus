## This repo started as a fork of [koehn's postgres-wal-g docker image](https://gitlab.koehn.com/docker/postgres-wal-g)

# PGPlus

This image builds upon the stock [PostGIS Image](https://hub.docker.com/postgis/postgis/)
and adds [WAL-G](https://github.com/wal-g/wal-g) and [pgBouncer](https://github.com/pgbouncer/pgbouncer)

## Versions
Only PostgreSQL 12 and greater will be supported. This is due to the removal of `recovery.conf` with respective config parameters added to `postgresql.conf` and use the use of `standby.signal`.

## Environment

### PostgreSQL Environmental Variables

- `POSTGRES_RESTORE` (default is an empty string) if value is set (not empty string), container is instructed to to download the latest base backup with WAL-G
- `POSTGRES_IS_STANDBY` (default is an empty string) if value is set (not empty string), container is instructed to make sure the file `$PGDATA/standby.signal` exists. This signals that this PostgreSQL instance is a standby server
- `POSTGRES_PRIMARY_CONNINFO` (default is an empty string) a valid PostgreSQL connection string [PostgreSQL documentation](https://www.postgresql.org/docs/12/libpq-connect.html#LIBPQ-CONNSTRING). Autogenerated if not provided

### pgBouncer Environmental Variables

- `PGBOUNCER_LOGFILE` (default `/var/log/postgresql/pgbouncer.log`) path to pgBouncer log file
- `PGBOUNCER_PIDFILE` (default `/var/run/postgresql/pgbouncer.pid`) path to pgBouncer pid file
- `PGBOUNCER_LISTEN_ADDR` (default `*`) IP address to listen on
- `PGBOUNCER_LISTEN_PORT` (default `6432`) IP Port to listen on
- `PGBOUNCER_CLIENT_TLS_SSLMODE` (default `allow`) allow clients to use SSL when connecting to pgBouncer?
- `PGBOUNCER_CLIENT_TLS_KEY_FILE` (default `/etc/ssl/private/pgplus.key` autogenerated per container creation) SSL private key to use when interacting with clients
- `PGBOUNCER_CLIENT_TLS_CERT_FILE` (default `/etc/ssl/certs/pgplus.pem` autogenerated per container creation)  SSL certificate to provide to clients
- `PGBOUNCER_SERVER_TLS_SSLMODE` (default `allow`) allow connections to PostgreSQL server to use SSL?
- `PGBOUNCER_AUTH_TYPE` (default `md5`) authentication type
- `PGBOUNCER_POOL_MODE` (default `session`) connection pooling mode
- `PGBOUNCER_MAX_CLIENT_CONN` (default `100`)  maximum number of client connections
- `PGBOUNCER_DEFAULT_POOL_SIZE` (default `20`) default number of client connections per pool
- `PGBOUNCER_MIN_POOL_SIZE` (default `0`) minimum number of client connections per pool
- `PGBOUNCER_RESERVE_POOL_SIZE` (default `0`) number of connections in the reserve pool
- `PGBOUNCER_RESERVE_POOL_TIMEOUT` (default `5`) number of seconds where a client is waiting for a connection before a connection from the reserve pool is provided
- `PGBOUNCER_MAX_DB_CONNECTIONS` (default `0`) maximum number of connections allowed per database
- `PGBOUNCER_MAX_USER_CONNECTIONS` (default `0`) maximum number of connections allowed per user

Complete details for pgBouncer config parameters can be found in the [pgBouncer documention](https://www.pgbouncer.org/config.html)

### WAL-G Environmental Variables

These are probably the most important variables to set...

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_ENDPOINT`

Additional WAL-G config parameters can be found in the [WAL-G documentation](https://github.com/wal-g/wal-g)

## Usage

To launch a container from the image, an example workflow may be:

1. Create an S3-compatible bucket and appropriate `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` with read/write priviges available. For this example:

```
bucket = mybucket
AWS_ACCESS_KEY_ID = myaccesskey
AWS_SECRET_ACCESS_KEY = mysecretkey
```

2. If you're not using AWS, determine the value for WAL-G's AWS_ENDPOINT. For this example:

```
AWS_ENDPOINT = https://sfo2.digitaloceanspaces.com/
```

3. Determine the S3 Prefix for WAL-G. For this example:

```
WALG_S3_PREFIX = s3://mybucket/my/custom/prefix/
```

3. Determine what pgBouncer environmental variables you wish to use. For this example:

```
PGBOUNCER_POOL_MODE = transaction
```

4. Create a bridge network given we will have launch two containers for a master PostgreSQL instance and a standby PostgreSQL instance


```
docker network create -d bridge --subnet 10.100.0.0/24 --gateway 10.100.0.1 mybridge
```

5. Launch the primary PostgreSQL instance

```
docker run \
  --name db-master \
  --network=mybridge
  -p 5432:5432 \
  -p 6432:6432 \
  -e POSTGRES_PRIMARY_CONNINFO="host=db-master port=5432 user=postgres password=mypassword" \
  -e POSTGRES_PASSWORD=mypassword \
  -e AWS_ACCESS_KEY_ID=myaccesskey \
  -e AWS_SECRET_ACCESS_KEY=mysecretkey \
  -e AWS_ENDPOINT=https://sfo2.digitaloceanspaces.com/ \
  -e WALG_S3_PREFIX=s3://mybucket/my/custom/prefix \
  -d dustymugs/pgplus:12-3.0
```

6. Create a base backup with WAL-G

```
docker exec db-master gosu postgres wal-g backup-push /var/lib/postgresql/data
```

Replace `/var/lib/postgresql/data` if you are not using the default path for `$PGDATA`

7. Launch the standby PostgreSQL instance

```
docker run \
  --name db-standby \
  --network=mybridge \
  -p 5433:5432 \
  -p 6433:6432 \
  -e POSTGRES_RESTORE=1 \
  -e POSTGRES_IS_STANDBY=1 \
  -e POSTGRES_PRIMARY_CONNINFO="host=db-master port=5432 user=postgres password=mypassword" \
  -e POSTGRES_PASSWORD=mypassword \
  -e AWS_ACCESS_KEY_ID=myaccesskey \
  -e AWS_SECRET_ACCESS_KEY=mysecretkey \
  -e AWS_ENDPOINT=https://sfo2.digitaloceanspaces.com/ \
  -e WALG_S3_PREFIX=s3://mybucket/my/custom/prefix \
  -d dustymugs/pgplus:12-3.0
```

The only changes here are:

- name of the Container (`--name db-standby`)
- port mappings for the host (`-p 5433:5432` and `-p 6433:6432`)
- set `-e POSTGRES_RESTORE=1` to a non-empty value
- set `-e POSTGRES_IS_STANDBY=1` to a non-empty value

8. After a minute or so, run the following:

```
docker exec db-master gosu psql -U postgres -c "SELECT * FROM pg_stat_replication"
```

We expect one row in the query resultset

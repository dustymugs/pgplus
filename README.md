# Postgres WAL-G

This image extends the stock [Postgres Image](https://hub.docker.com/_/postgres/)
and adds [WAL-G](https://github.com/wal-g/wal-g) support, along with some
helpful scripts. It allows you to simply and easily create continuous 
archives of Postgres databases in S3-compatible storage. 

## Environment
To use the image, you'll need to configure a bucket on your favorite S3-
compatible provider, and set a few environment variables:

* `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` that can read/write files
to your bucket
* `AWS_ENDPOINT` (et al) to tell WAL-G where to archive (see 
[WAL-G documentation](https://github.com/wal-g/wal-g) for details)
* `WALG_S3_PREFIX` to tell WAL-G which bucket and prefix you'd like to use

## Configuration
In your `/varlib/postgresql/data/pgsql/postgresql.conf` file, set your [archive
settings](https://www.postgresql.org/docs/9.1/continuous-archiving.html). 
Importantly, you should set `archive_mode = on` and 
`archive_command = 'wal-g wal-push %p'`. This will
tell Postgres to have WAL-G send WAL files to S3.

## Full Backups
To run a full backup, simply run `/wal-g/backup.sh`. 

## Continuous Backups
These will happen automatically once you've started Postgres with your edited
`postgresql.conf` file (see 
[Configuration](https://gitlab.koehn.com/docker/postgres-wal-g#configuration), above). 

## Recovery
Testing recovery is simple: run a new Docker container with the correct 
environment variables set and run `/wal-g/recover.sh`. It will:
1. Recover from the most recent full backup
2. Configure Postgres to not accept incoming connections or perform streaming
   backups until the recovery is complete (important for testing!)
3. Configure Postgres to apply all the WAL files
4. Shut down Postgres, re-enable incoming connections and streaming backups

At this point you should have high confidence that the recovery was successful.
If you start your recovered backup, be sure to turn `archive_mode = off` to avoid
pushing additional WAL files to S3!

## Postgres Versions
Currently I build for Postgres 9.6 and Postgres 11. Be advised that 9.6 is the
earliest version that WAL-G supports. 

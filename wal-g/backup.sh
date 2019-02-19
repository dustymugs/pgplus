#!/bin/bash

if [ -z ${PGDATA+x} ]; then
  export PGDATA=/var/lib/postgresql/data/pgsql
fi

wal-g backup-push "$PGDATA"

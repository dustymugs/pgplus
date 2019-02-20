ARG BASE

FROM postgres:$BASE

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update  -qq && \
    apt-get install -qqy curl ca-certificates vim && \
    cd /usr/local/bin && curl -L https://github.com/wal-g/wal-g/releases/download/v0.2.5/wal-g.linux-amd64.tar.gz | tar xzf - 

COPY wal-g /wal-g

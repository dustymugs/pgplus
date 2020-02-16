ARG BASE

FROM postgres:$BASE

ARG WALG_RELEASE=v0.2.14

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update  -qq && \
    apt-get install -qqy curl ca-certificates libsodium23 vim && \
    cd /usr/local/bin && curl -L https://github.com/wal-g/wal-g/releases/download/$WALG_RELEASE/wal-g.linux-amd64.tar.gz | tar xzf - 

COPY wal-g /wal-g

#
# docker build -f Dockerfile -t dustymugs/pgplus:12-3.0-0.2.14 . --build-arg BASE=12-3.0
#
# docker run --rm -p 5432:5432 -e POSTGRES_PASSWORD=mypassword -e AWS_ACCESS_KEY_ID=myaccesskey -e AWS_SECRET_ACCESS_KEY=mysecretaccesskey -e AWS_ENDPOINT=myendpiont -e WALG_S3_PREFIX=s3://my/path/to/ -d dustymugs/pgplus
#

ARG BASE

FROM postgis/postgis:$BASE

ARG WALG_RELEASE=v0.2.14

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -qq && \
    apt-get install -qqy curl ca-certificates libsodium23 vim && \
    cd /usr/local/bin && curl -L https://github.com/wal-g/wal-g/releases/download/$WALG_RELEASE/wal-g.linux-amd64.tar.gz | tar xzf - 

COPY wal-g /wal-g

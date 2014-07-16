#!/bin/bash

source vars.sh

echo "nameserver ${dns01}" > /etc/resolvconf/resolv.conf.d/head
resolvconf -u

apt-get update
apt-get install -y python-software-properties
apt-add-repository -y ppa:reddit/ppa
cat <<HERE > /etc/apt/preferences.d/reddit
Package: *
Pin: release o=LP-PPA-reddit
Pin-Priority: 600
HERE

apt-get update
apt-get -y install sutro gunicorn git geoip-bin geoip-database python-geoip python-flask

cat > /etc/sutro.ini <<SUTRO
[app:main]
paste.app_factory = sutro.app:make_app

amqp.host = reddit-rabbitmq01.$domain
amqp.port = 5672
amqp.vhost = /
amqp.username = reddit
amqp.password = reddit

web.allowed_origins = $REDDIT_DOMAIN
web.mac_secret = YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXowMTIzNDU2Nzg5
web.ping_interval = 300

stats.host =
stats.port = 0

[server:main]
use = egg:gunicorn#main
worker_class = sutro.socketserver.SutroWorker
workers = 1
worker_connections = 250
host = 0.0.0.0
port = 8002
graceful_timeout = 5
forward_allow_ips = 127.0.0.1

[loggers]
keys = root

[handlers]
keys = syslog

[formatters]
keys = generic
[logger_root]
level = INFO
handlers = syslog

[handler_syslog]
class = handlers.SysLogHandler
args = ("/dev/log", "local7")
formatter = generic
level = NOTSET

[formatter_generic]
format = [%(name)s] %(message)s
SUTRO

cat > /etc/init/sutro.conf << UPSTART_SUTRO
description "sutro websocket server"

stop on runlevel [!2345]
start on runlevel [2345]

respawn
respawn limit 10 5
kill timeout 15

limit nofile 65535 65535

exec gunicorn_paster /etc/sutro.ini
UPSTART_SUTRO

groupadd -r $REDDIT_GROUP
useradd -r -g $REDDIT_GROUP -m -b $REDDIT_HOME_BASE $REDDIT_USER
mkdir $REDDIT_HOME/src
cd $REDDIT_HOME/src
git clone https://github.com/reddit/reddit.git

cat > /etc/gunicorn.d/geoip.conf <<GEOIP
CONFIG = {
    "mode": "wsgi",
    "working_dir": "$REDDIT_HOME/src/reddit/scripts",
    "user": "$REDDIT_USER",
    "group": "$REDDIT_USER",
    "args": (
        "--bind=0.0.0.0:5000",
        "--workers=1",
         "--limit-request-line=8190",
         "geoip_service:application",
    ),
}
GEOIP

service gunicorn start
start sutro

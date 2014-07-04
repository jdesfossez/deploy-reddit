#!/bin/bash

source vars.sh

apt-get update
apt-get install -y python-software-properties
apt-add-repository -y ppa:reddit/ppa
cat <<HERE > /etc/apt/preferences.d/reddit
Package: *
Pin: release o=LP-PPA-reddit
Pin-Priority: 600
HERE

apt-get update
apt-get -y install haproxy stunnel ssl-cert

cat > /etc/default/haproxy <<DEFAULT
ENABLED=1
DEFAULT

cat > /etc/haproxy/haproxy.cfg <<HAPROXY
global
    maxconn 350

frontend frontend
    mode http

    bind 0.0.0.0:80
    bind 127.0.0.1:8080

    timeout client 24h
    option forwardfor except 127.0.0.1
    option httpclose

    # make sure that requests have x-forwarded-proto: https iff tls
    reqidel ^X-Forwarded-Proto:.*
    acl is-ssl dst_port 8080
    reqadd X-Forwarded-Proto:\ https if is-ssl

    # send websockets to sutro
    acl is-websocket hdr(Upgrade) -i WebSocket
    use_backend sutro if is-websocket

    # send media stuff to the local nginx
    acl is-media path_beg /media/
    use_backend media if is-media

    default_backend reddit

backend reddit
    mode http
    timeout connect 4000
    timeout server 30000
    timeout queue 60000
    balance roundrobin

    server app01-8001 reddit-app01.${domain}:8001 maxconn 1

backend sutro
    mode http
    timeout connect 4s
    timeout server 24h
    balance roundrobin

    server sutro reddit-sutro01.${domain}:8002 maxconn 250

backend media
    mode http
    timeout connect 4000
    timeout server 30000
    timeout queue 60000
    balance roundrobin

    server nginx reddit-nginx01.${domain}:9000 maxconn 20
HAPROXY

cat > /etc/stunnel/stunnel.conf <<STUNNELCONF
foreground = no

; replace these with real certificates
cert = /etc/ssl/certs/ssl-cert-snakeoil.pem
key = /etc/ssl/private/ssl-cert-snakeoil.key

; protocol version and ciphers
sslVersion = all
ciphers = ECDHE-RSA-RC4-SHA:ECDHE-ECDSA-RC4-SHA:ECDH-RSA-RC4-SHA:ECDH-ECDSA-RC4-SHA:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:SRP-DSS-AES-256-CBC-SHA:SRP-RSA-AES-256-CBC-SHA:DHE-DSS-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA256:DHE-RSA-AES256-SHA:DHE-DSS-AES256-SHA:DHE-RSA-CAMELLIA256-SHA:DHE-DSS-CAMELLIA256-SHA:ECDH-RSA-AES256-GCM-SHA384:ECDH-ECDSA-AES256-GCM-SHA384:ECDH-RSA-AES256-SHA384:ECDH-ECDSA-AES256-SHA384:ECDH-RSA-AES256-SHA:ECDH-ECDSA-AES256-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA:CAMELLIA256-SHA:PSK-AES256-CBC-SHA:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:SRP-DSS-AES-128-CBC-SHA:SRP-RSA-AES-128-CBC-SHA:DHE-DSS-AES128-GCM-SHA256:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES128-SHA256:DHE-DSS-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA:DHE-RSA-SEED-SHA:DHE-DSS-SEED-SHA:DHE-RSA-CAMELLIA128-SHA:DHE-DSS-CAMELLIA128-SHA:ECDH-RSA-AES128-GCM-SHA256:ECDH-ECDSA-AES128-GCM-SHA256:ECDH-RSA-AES128-SHA256:ECDH-ECDSA-AES128-SHA256:ECDH-RSA-AES128-SHA:ECDH-ECDSA-AES128-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:SEED-SHA:CAMELLIA128-SHA:PSK-AES128-CBC-SHA:RC4-SHA:DES-CBC3-SHA:RC4-MD5
options = NO_SSLv2
options = DONT_INSERT_EMPTY_FRAGMENTS
options = CIPHER_SERVER_PREFERENCE

; security
chroot = /var/lib/stunnel4/
setuid = stunnel4
setgid = stunnel4
pid = /stunnel4.pid

; performance
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

; logging
output = /var/log/stunnel4/stunnel.log
syslog = no

[https]
accept = 443
connect = 8080
TIMEOUTclose = 0
sslVersion = all
; this requires a patched version of stunnel which is in the reddit ppa
xforwardedfor = yes
STUNNELCONF

sed -i s/ENABLED=0/ENABLED=1/ /etc/default/stunnel4

make-ssl-cert generate-default-snakeoil –force-overwrite

#!/bin/bash

source vars.sh

echo "nameserver ${dns01}" > /etc/resolvconf/resolv.conf.d/head
resolvconf -u

apt-get update
apt-get -y install memcached
sed -i 's/-l 127.0.0.1/-l 0.0.0.0/' /etc/memcached.conf

service memcached restart

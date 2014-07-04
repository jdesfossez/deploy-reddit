#!/bin/bash

source vars.sh

apt-get update
apt-get -y install memcached
sed -i 's/-l 127.0.0.1/-l 0.0.0.0/' /etc/memcached.conf

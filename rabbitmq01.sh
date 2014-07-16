#!/bin/bash

source vars.sh

echo "nameserver ${dns01}" > /etc/resolvconf/resolv.conf.d/head
resolvconf -u

apt-get update
apt-get -y install rabbitmq-server
sudo rabbitmqctl add_user reddit reddit
sudo rabbitmqctl set_permissions -p / reddit ".*" ".*" ".*"

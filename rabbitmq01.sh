#!/bin/bash

source vars.sh

apt-get update
apt-get -y install rabbitmq-server
sudo rabbitmqctl add_user reddit reddit
sudo rabbitmqctl set_permissions -p / reddit ".*" ".*" ".*"

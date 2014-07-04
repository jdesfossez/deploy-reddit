#!/bin/bash

# basic infos
export domain="dev.efficios.com"
export net_base="192.168.122"
export netmask=255.255.255.0
export gateway=${net_base}.1
export network="${net_base}.0/24"
export templatevm="template-12.04"
export imgpath="/var/lib/libvirt/images/"
export templateip=${net_base}.2
export templatehostname=ubuntu
export uplinkdns="8.8.8.8"
export setupssh="ssh -oBatchMode=yes -oStrictHostKeyChecking=no -l root "

# hosts we deploy
export tracevisor=${net_base}.3
export dns01=${net_base}.10
export postgres01=${net_base}.11
export cassandra01=${net_base}.12
export rabbitmq01=${net_base}.13
export memcached01=${net_base}.14
export haproxy01=${net_base}.15
export nginx01=${net_base}.16
export sutro01=${net_base}.17
export app01=${net_base}.18

# reddit config
export REDDIT_USER=reddit
export REDDIT_GROUP=reddit
export REDDIT_DOMAIN=reddit.efficios.com
export REDDIT_HOME_BASE=/opt
export REDDIT_HOME=$REDDIT_HOME_BASE/reddit

#!/bin/bash

# Destroy all reddit VMs

source vars.sh

function destroy_vm() {
	virsh destroy $1
	virsh undefine $1
	sudo rm -rf $imgpath/${1}.img
}

destroy_vm reddit-dns01
destroy_vm reddit-postgres01
destroy_vm reddit-cassandra01
destroy_vm reddit-rabbitmq01
destroy_vm reddit-memcached01
destroy_vm reddit-nginx01
destroy_vm reddit-sutro01
destroy_vm reddit-haproxy01
destroy_vm reddit-app01

# work-around a bug that prevent from cloning a VM that has already existed
sudo /etc/init.d/libvirt-bin restart

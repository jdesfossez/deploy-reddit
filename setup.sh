#!/bin/bash

# Install reddit from git with 1 VM per service

# PREREQUISITES :
# - a template VM with ubuntu 12.04 up-to-date with a fixed IP
# - setup the vars.sh file
# - the current user can ssh as root without password into the template
# - libvirt
# - a /24 IPv4 network that can be reached by the host and all the VMs
# - enough disk space for 9 clones of the template

source vars.sh

function boot_wait() {
	# $1 IP
	ok=0
	until test $ok = 1; do
		ping -c1 -W1 ${1} >/dev/null
		if test $? = 0; then
			ok=1
		fi
	done

	ok=0
	until test $ok = 1; do
		$setupssh ${1} "uname -a" 2>/dev/null
		if test $? = 0; then
			ok=1
		fi
	done
}

function clone_vm() {
	# $1 = VM name
	ping -c1 -W1 ${templateip} >/dev/null
	if test $? = 0; then
		echo "Template already started"
		exit 1
	fi
	sudo virt-clone -o $templatevm -n $1 -f $imgpath/${1}.img
	virsh start $1
	echo "Waiting for $1 to boot"
	boot_wait ${templateip}
	echo "$1 ready"
}

function sethostnameandnetwork() {
	# $1 = hostname, $2 = IP
	$setupssh ${templateip} "echo $1 >/etc/hostname"
	$setupssh ${templateip} "sed -i 's/${templatehostname}/${1}/' /etc/hosts"

	$setupssh ${templateip} "cat <<EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address $2
    netmask $netmask
    gateway $gateway
    dns-nameservers $dns01
EOF"
}

function sendandrunsetupscript() {
	# $1 IP, $2 scriptname

	$setupssh ${1} "mkdir /tmp/setup"
	scp vars.sh root@${1}:/tmp/setup/
	scp $2 root@${1}:/tmp/setup/
	$setupssh ${1} "cd /tmp/setup; ./$2"
}

function pre-reboot-dns-hook() {
	# for the dns server, we have to override the default dns config
	$setupssh ${templateip} "sed -i \"s/dns-nameservers $dns01/dns-nameservers ${uplinkdns}/\" /etc/network/interfaces"
}

function basic_setup() {
	# $1 name, $2 IP, $3 setup-script, optional $4 pre-reboot hook
	ping -c1 -W1 ${2} >/dev/null
	if test $? = 0; then
		echo "$1 already started"
		exit 1
	fi

	clone_vm $1
	sethostnameandnetwork $1 $2
	if ! test -z $4; then
		$4
	fi
	$setupssh ${templateip} "reboot; exit"
	boot_wait $2
	sendandrunsetupscript $2 $3
	$setupssh ${2} "reboot; exit"
	boot_wait $2
	echo "$1 ready"
}

basic_setup reddit-dns01 $dns01 dns01.sh pre-reboot-dns-hook
basic_setup reddit-postgres01 $postgres01 postgres01.sh
basic_setup reddit-cassandra01 $cassandra01 cassandra01.sh
basic_setup reddit-rabbitmq01 $rabbitmq01 rabbitmq01.sh
basic_setup reddit-memcached01 $memcached01 memcached01.sh
basic_setup reddit-nginx01 $nginx01 nginx01.sh
basic_setup reddit-sutro01 $sutro01 sutro01.sh
basic_setup reddit-haproxy01 $haproxy01 haproxy01.sh
basic_setup reddit-app01 $app01 app01.sh

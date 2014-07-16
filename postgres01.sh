#!/bin/bash

source vars.sh

echo "nameserver ${dns01}" > /etc/resolvconf/resolv.conf.d/head
resolvconf -u

apt-get update
apt-get -y install git postgresql

cd /root
git clone https://github.com/reddit/reddit.git
sudo -u postgres psql -qAt -c "SELECT 'connected ok, superuser: ' || (select usesuper from pg_user where usename = CURRENT_USER)||', version: '||version()"|grep "superuser: true"
if test $? != 0; then
	echo "Postgresql setup failed"
	exit 1
fi
sudo -u postgres createdb -E utf8 reddit
echo "CREATE USER reddit WITH PASSWORD 'password';" | sudo -u postgres psql reddit
cd reddit
sudo -u postgres psql reddit < sql/functions.sql
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/9.1/main/postgresql.conf
echo "host    all     reddit  $network        md5" >>/etc/postgresql/9.1/main/pg_hba.conf
/etc/init.d/postgresql restart

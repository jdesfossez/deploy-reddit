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
apt-get -y install cassandra
sed -i s/-Xss128k/-Xss228k/ /etc/cassandra/cassandra-env.sh
sed -i 's/rpc_address: localhost/rpc_address: 0.0.0.0/' /etc/cassandra/cassandra.yaml
service cassandra restart

echo "create keyspace reddit;" | cassandra-cli -h localhost -B
cat <<CASS | cassandra-cli -B -h localhost -k reddit || true
create column family permacache with column_type = 'Standard' and
                                     comparator = 'BytesType';
CASS

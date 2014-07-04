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
apt-get -y install cassandra
sed -i s/-Xss128k/-Xss228k/ /etc/cassandra/cassandra-env.sh
service cassandra start
service cassandra stop
service cassandra start
echo "create keyspace reddit;" | cassandra-cli -h localhost -B
cat <<CASS | cassandra-cli -B -h localhost -k reddit || true
create column family permacache with column_type = 'Standard' and
                                     comparator = 'BytesType';
CASS
sed -i 's/rpc_address: localhost/rpc_address: 0.0.0.0/' /etc/cassandra/cassandra.yaml
sed -i 's/listen_address: localhost/listen_address: 0.0.0.0/' /etc/cassandra/cassandra.yaml

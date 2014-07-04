#!/bin/bash

source vars.sh

apt-get update
apt-get -y install bind9

mkdir /var/cache/bind/master/
cat <<EOF > /var/cache/bind/master/db.$domain
\$ORIGIN .
\$TTL 3600   ; 1 hour
$domain      IN SOA  ns.${domain}. contact.${domain}. (
                2014070302 ; serial
                3600       ; refresh (1 hour)
                900        ; retry (15 minutes)
                604800     ; expire (1 week)
                43200      ; minimum (12 hours)
                )
            IN  NS  reddit-dns01.${domain}.

\$ORIGIN ${domain}.

reddit-dns01            IN A    $dns01
reddit-postgres01       IN A    $postgres01
reddit-cassandra01       IN A    $cassandra01
reddit-rabbitmq01       IN A    $rabbitmq01
reddit-memcached01       IN A    $memcached01
reddit-haproxy01       IN A    $haproxy01
reddit-nginx01       IN A    $nginx01
reddit-sutro01       IN A    $sutro01
reddit-app01       IN A    $app01
EOF

cat <<EOF >> /etc/bind/named.conf.local
zone "${domain}" {
        type master;
        file "master/db.${domain}";
        allow-transfer { 127.0.0.1; };
};
EOF
rndc reload

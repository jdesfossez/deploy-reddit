#!/bin/bash

source vars.sh

echo "nameserver ${dns01}" > /etc/resolvconf/resolv.conf.d/head
resolvconf -u

apt-get update
apt-get -y install nginx

groupadd -r $REDDIT_GROUP
useradd -r -g $REDDIT_GROUP -m -b $REDDIT_HOME_BASE $REDDIT_USER
mkdir -p /srv/www/media
chown $REDDIT_USER:$REDDIT_GROUP /srv/www/media

cat > /etc/nginx/sites-available/reddit-media <<MEDIA
server {
    listen 9000;

    expires max;

    location /media/ {
        alias /srv/www/media/;
    }
}
MEDIA

rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/reddit-media /etc/nginx/sites-enabled/

service nginx start

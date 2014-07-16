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
apt-get -y install netcat-openbsd git-core python-dev python-setuptools python-routes python-pylons python-boto python-tz python-crypto python-babel cython python-sqlalchemy python-beautifulsoup python-chardet python-psycopg2 python-pycassa python-imaging python-pycaptcha python-amqplib python-pylibmc python-bcrypt python-snudown python-l2cs python-lxml python-zope.interface python-kazoo python-stripe python-tinycss2 python-flask geoip-bin geoip-database python-geoip nodejs node-less gettext make optipng jpegoptim postgresql-client openjdk-6-jre-headless node-uglify

groupadd -r $REDDIT_GROUP
useradd -r -g $REDDIT_GROUP -m -b $REDDIT_HOME_BASE $REDDIT_USER
mkdir $REDDIT_HOME/src
chown $REDDIT_USER $REDDIT_HOME/src
cd $REDDIT_HOME/src

function clone_reddit_repo {
    local destination=$REDDIT_HOME/src/${1}
    local repository_url=https://github.com/${2}.git

    if [ ! -d $destination ]; then
        sudo -u $REDDIT_USER git clone $repository_url $destination
    fi

    if [ -d $destination/upstart ]; then
        cp $destination/upstart/* /etc/init/
    fi
}

function clone_reddit_plugin_repo {
    clone_reddit_repo $1 reddit/reddit-plugin-$1
}

clone_reddit_repo reddit reddit/reddit
clone_reddit_repo i18n reddit/reddit-i18n
clone_reddit_plugin_repo about
clone_reddit_plugin_repo liveupdate
clone_reddit_plugin_repo meatspace

function install_reddit_repo {
    cd $REDDIT_HOME/src/$1
    sudo -u $REDDIT_USER python setup.py build
    python setup.py develop --no-deps
}

install_reddit_repo reddit/r2
install_reddit_repo i18n
install_reddit_repo about
install_reddit_repo liveupdate
install_reddit_repo meatspace

# generate binary translation files from source
cd $REDDIT_HOME/src/i18n/
sudo -u $REDDIT_USER make

# this builds static files and should be run *after* languages are installed
# so that the proper language-specific static files can be generated and after
# plugins are installed so all the static files are available.
cd $REDDIT_HOME/src/reddit/r2
sudo -u $REDDIT_USER make

cat > development.update <<DEVELOPMENT
# after editing this file, run "make ini" to
# generate a new development.ini

[DEFAULT]
debug = true

disable_ads = true
disable_captcha = true
disable_ratelimit = true
disable_require_admin_otp = true

page_cache_time = 0

domain = $REDDIT_DOMAIN

plugins = about, liveupdate, meatspace

media_provider = filesystem
media_fs_root = /srv/www/media
media_fs_base_url_http = http://%(domain)s/media/
media_fs_base_url_https = https://%(domain)s/media/

[server:main]
port = 8001
DEVELOPMENT
chown $REDDIT_USER development.update

sudo -u $REDDIT_USER make ini

cat > /usr/local/bin/reddit-run <<REDDITRUN
#!/bin/bash
exec paster --plugin=r2 run $REDDIT_HOME/src/reddit/r2/run.ini "\$@"
REDDITRUN

cat > /usr/local/bin/reddit-shell <<REDDITSHELL
#!/bin/bash
exec paster --plugin=r2 shell $REDDIT_HOME/src/reddit/r2/run.ini
REDDITSHELL

chmod 755 /usr/local/bin/reddit-run /usr/local/bin/reddit-shell

CONSUMER_CONFIG_ROOT=$REDDIT_HOME/consumer-count.d

if [ ! -f /etc/default/reddit ]; then
    cat > /etc/default/reddit <<DEFAULT
export REDDIT_ROOT=$REDDIT_HOME/src/reddit/r2
export REDDIT_INI=$REDDIT_HOME/src/reddit/r2/run.ini
export REDDIT_USER=$REDDIT_USER
export REDDIT_GROUP=$REDDIT_GROUP
export REDDIT_CONSUMER_CONFIG=$CONSUMER_CONFIG_ROOT
alias wrap-job=$REDDIT_HOME/src/reddit/scripts/wrap-job
alias manage-consumers=$REDDIT_HOME/src/reddit/scripts/manage-consumers
DEFAULT
fi

mkdir -p $CONSUMER_CONFIG_ROOT

function set_consumer_count {
    if [ ! -f $CONSUMER_CONFIG_ROOT/$1 ]; then
        echo $2 > $CONSUMER_CONFIG_ROOT/$1
    fi
}

set_consumer_count log_q 0
set_consumer_count cloudsearch_q 0
set_consumer_count scraper_q 1
set_consumer_count commentstree_q 1
set_consumer_count newcomments_q 1
set_consumer_count vote_link_q 1
set_consumer_count vote_comment_q 1

chown -R $REDDIT_USER:$REDDIT_GROUP $CONSUMER_CONFIG_ROOT/

initctl emit reddit-start


if [ ! -f /etc/cron.d/reddit ]; then
    cat > /etc/cron.d/reddit <<CRON
0    3 * * * root /sbin/start --quiet reddit-job-update_sr_names
30  16 * * * root /sbin/start --quiet reddit-job-update_reddits
0    * * * * root /sbin/start --quiet reddit-job-update_promos
*/5  * * * * root /sbin/start --quiet reddit-job-clean_up_hardcache
*/2  * * * * root /sbin/start --quiet reddit-job-broken_things
*/2  * * * * root /sbin/start --quiet reddit-job-rising
0    * * * * root /sbin/start --quiet reddit-job-trylater

# liveupdate
*    * * * * root /sbin/start --quiet reddit-job-liveupdate_activity

# jobs that recalculate time-limited listings (e.g. top this year)
PGPASSWORD=password
*/15 * * * * $REDDIT_USER $REDDIT_HOME/src/reddit/scripts/compute_time_listings link year '("hour", "day", "week", "month", "year")'
*/15 * * * * $REDDIT_USER $REDDIT_HOME/src/reddit/scripts/compute_time_listings comment year '("hour", "day", "week", "month", "year")'

# disabled by default, uncomment if you need these jobs
#*    * * * * root /sbin/start --quiet reddit-job-email
#0    0 * * * root /sbin/start --quiet reddit-job-update_gold_users
CRON
fi

cat > $REDDIT_HOME/src/reddit/r2/run.ini << EOF
# YOU DO NOT NEED TO EDIT THIS FILE
# This is a generated file. To update the configuration,
# edit the *.update file of the same name, and then
# run 'make ini'
# Configuration settings in the *.update file will override
# or be added to the base 'example.ini' file.

[DEFAULT]
short_description = open source is awesome
site_lang = en
default_header_url = reddit.com.header.png
domain = $REDDIT_DOMAIN
shortdomain = 
domain_prefix = 
reserved_subdomains = www, ssl
offsite_subdomains = 
https_endpoint = 
payment_domain = https://pay.reddit.local/
ad_domain = http://reddit.local
websocket_host = %(domain)s
system_user = reddit
default_sr = reddit.com
admin_message_acct = reddit
takedown_sr = _takedowns
trending_sr = 
automatic_reddits = 
lounge_reddit = 
static_domain = 
static_secure_domain = 
static_pre_gzipped = false
static_secure_pre_gzipped = false
subreddit_stylesheets_static = false
trust_local_proxies = false
diff3_temp_location = 
tracker_url = /static/pixel.png
adtracker_url = /static/pixel.png
adframetracker_url = /static/pixel.png
clicktracker_url = /static/pixel.png
uitracker_url = /static/pixel.png
fetch_trackers_url = http://reddit.local/fetch-trackers
googleanalytics = 
tracking_secret = abcdefghijklmnopqrstuvwxyz0123456789
wiki_page_privacy_policy = privacypolicy
wiki_page_user_agreement = useragreement
wiki_page_registration_info = registration_info
wiki_page_gold_bottlecaps = gold_bottlecaps
disable_ads = true
disable_captcha = true
disable_ratelimit = true
disable_require_admin_otp = true
disable_wiki = false
debug = false
template_debug = false
reload_templates = true
uncompressedJS = false
sqlprinting = false
profile_directory = 
timed_templates = Reddit, Link, Comment, LinkListing, NestedListing, SubredditTopBar
plugins = about, liveupdate, meatspace
about_sr_quotes = about_quotes
about_sr_images = about_images
about_images_count = 50
about_images_min_score = 1
liveupdate_pixel_domain = %(domain)s
liveupdate_invite_quota = 5
log_start = true
amqp_logging = false
error_reporters = 
media_provider = filesystem
S3KEY_ID = 
S3SECRET_KEY = 
s3_media_buckets = 
s3_media_direct = true
media_fs_root = /srv/www/media
media_fs_base_url_http = http://%(domain)s/media/
media_fs_base_url_https = https://%(domain)s/media/
media_domain = localhost
read_only_mode = false
heavy_load_mode = false
lang_override = 
db_create_tables = True
disallow_db_writes = False
css_killswitch = False
useragent = Mozilla/5.0 (compatible; redditbot/1.0; +http://www.reddit.com/feedback)
embedly_api_key = 
autoexpand_media_types = liveupdate
sr_banned_quota = 10000
sr_moderator_invite_quota = 10000
sr_contributor_quota = 10000
sr_wikibanned_quota = 10000
sr_wikicontributor_quota = 10000
sr_quota_time = 7200
sr_invite_limit = 25
new_link_share_delay = 30 seconds
max_sr_images = 50
ENFORCE_RATELIMIT = false
RL_SITEWIDE_ENABLED = true
RL_RESET_MINUTES = 10
RL_AVG_REQ_PER_SEC = 0.5
RL_OAUTH_SITEWIDE_ENABLED = true
RL_OAUTH_RESET_MINUTES = 10
RL_OAUTH_AVG_REQ_PER_SEC = 0.5
agents = 
MIN_RATE_LIMIT_KARMA = 10
MIN_RATE_LIMIT_COMMENT_KARMA = 1
QUOTA_THRESHOLD = 5
MIN_UP_KARMA = 1
ARCHIVE_AGE = 180 days
min_membership_create_community = 30
HOT_PAGE_AGE = 1000
rising_period = 12 hours
num_comments = 100
max_comments = 500
max_comments_gold = 2500
num_default_reddits = 10
num_serendipity = 250
sr_dropdown_threshold = 15
comment_visits_period = 600
wiki_keep_recent_days = 7
wiki_max_page_length_bytes = 262144
wiki_max_page_name_length = 128
wiki_max_page_separators = 3
CLOUDSEARCH_SEARCH_API = 
CLOUDSEARCH_DOC_API = 
CLOUDSEARCH_SUBREDDIT_SEARCH_API = 
CLOUDSEARCH_SUBREDDIT_DOC_API = 
num_mc_clients = 5
memcaches = reddit-memcached01.$domain:11211
memoizecaches = reddit-memcached01.$domain:11211
lockcaches = reddit-memcached01.$domain:11211
rendercaches = reddit-memcached01.$domain:11211
pagecaches = reddit-memcached01.$domain:11211
permacache_memcaches = reddit-memcached01.$domain:11211
srmembercaches = reddit-memcached01.$domain:11211
stalecaches = 
ratelimitcaches = reddit-memcached01.$domain:11211
locale = C
timezone = UTC
display_timezone = MST
static_path = /static/
words_file = /usr/dict/words
case_sensitive_domains = i.imgur.com, youtube.com
import_private = false
geoip_location = http://reddit-sutro01.$domain:5000
authentication_provider = cookie
bcrypt_work_factor = 12
login_cookie = reddit_session
admin_cookie = reddit_admin
otp_cookie = reddit_otp
ADMIN_COOKIE_TTL = 32400
ADMIN_COOKIE_MAX_IDLE = 900
OTP_COOKIE_TTL = 604800
cassandra_seeds = reddit-cassandra01.$domain:9160
cassandra_pool_size = 5
cassandra_rcl = ONE
cassandra_wcl = ONE
cassandra_default_pool = main
amqp_host = reddit-rabbitmq01.$domain:5672
amqp_user = reddit
amqp_pass = reddit
amqp_virtual_host = /
zookeeper_connection_string = 
zookeeper_username = 
zookeeper_password = 
smtp_server = localhost
nerds_email = nerds@reddit.com
share_reply = noreply@reddit.com
feedback_email = reddit@gmail.com
db_user = reddit
db_pass = password
db_port = 5432
db_pool_size = 3
db_pool_overflow_size = 3
databases = main, comment, vote, email, authorize, award, hc, traffic
main_db = reddit,   reddit-postgres01.$domain, *,    *,    *,    *,    *
comment_db = reddit,   reddit-postgres01.$domain, *,    *,    *,    *,    *
comment2_db = reddit,   reddit-postgres01.$domain, *,    *,    *,    *,    *
vote_db = reddit,   reddit-postgres01.$domain, *,    *,    *,    *,    *
email_db = reddit,   reddit-postgres01.$domain, *,    *,    *,    *,    *
authorize_db = reddit,   reddit-postgres01.$domain, *,    *,    *,    *,    *
award_db = reddit,   reddit-postgres01.$domain, *,    *,    *,    *,    *
hc_db = reddit,   reddit-postgres01.$domain, *,    *,    *,    *,    *
traffic_db = reddit,   reddit-postgres01.$domain, *,    *,    *,    *,    *
hardcache_categories = *:hc:hc
db_app_name = reddit
type_db = main
rel_type_db = main
hardcache_db = main
db_table_link = thing
db_table_account = thing
db_table_message = thing
db_table_comment = thing
db_table_subreddit = thing
db_table_srmember = relation, subreddit, account
db_table_friend = relation, account, account
db_table_vote_account_link = relation, account, link
db_table_vote_account_comment = relation, account, comment
db_table_inbox_account_comment = relation, account, comment
db_table_inbox_account_message = relation, account, message
db_table_moderatorinbox = relation, subreddit, message
db_table_report_account_link = relation, account, link
db_table_report_account_comment = relation, account, comment
db_table_report_account_message = relation, account, message
db_table_report_account_subreddit = relation, account, subreddit
db_table_award = thing
db_table_trophy = relation, account, award
db_table_jury_account_link = relation, account, link
db_table_ad = thing
db_table_adsr = relation, ad, subreddit
db_table_flair = relation, subreddit, account
db_table_promocampaign = thing
db_servers_link = main, main
db_servers_account = main
db_servers_message = main
db_servers_comment = comment
db_servers_subreddit = comment
db_servers_srmember = comment
db_servers_friend = comment
db_servers_vote_account_link = vote
db_servers_vote_account_comment = vote
db_servers_inbox_account_comment = main
db_servers_inbox_account_message = main
db_servers_moderatorinbox = main
db_servers_report_account_link = main
db_servers_report_account_comment = comment
db_servers_report_account_message = main
db_servers_report_account_subreddit = main
db_servers_award = award
db_servers_trophy = award
db_servers_jury_account_link = main
db_servers_ad = main
db_servers_adsr = main
db_servers_flair = main
db_servers_promocampaign = main
gold_month_price = 3.99
gold_year_price = 29.99
PAYPAL_BUTTONID_ONETIME_BYMONTH = 
PAYPAL_BUTTONID_ONETIME_BYYEAR = 
PAYPAL_BUTTONID_AUTORENEW_BYMONTH = 
PAYPAL_BUTTONID_AUTORENEW_BYYEAR = 
PAYPAL_BUTTONID_CREDDITS_BYMONTH = 
PAYPAL_BUTTONID_CREDDITS_BYYEAR = 
STRIPE_MONTHLY_GOLD_PLAN = 
STRIPE_YEARLY_GOLD_PLAN = 
COINBASE_BUTTONID_ONETIME_1MO = 
COINBASE_BUTTONID_ONETIME_2MO = 
COINBASE_BUTTONID_ONETIME_3MO = 
COINBASE_BUTTONID_ONETIME_4MO = 
COINBASE_BUTTONID_ONETIME_5MO = 
COINBASE_BUTTONID_ONETIME_6MO = 
COINBASE_BUTTONID_ONETIME_7MO = 
COINBASE_BUTTONID_ONETIME_8MO = 
COINBASE_BUTTONID_ONETIME_9MO = 
COINBASE_BUTTONID_ONETIME_10MO = 
COINBASE_BUTTONID_ONETIME_11MO = 
COINBASE_BUTTONID_ONETIME_1YR = 
COINBASE_BUTTONID_ONETIME_2YR = 
COINBASE_BUTTONID_ONETIME_3YR = 
selfserve_support_email = selfservesupport@mydomain.com
MAX_CAMPAIGNS_PER_LINK = 100
cpm_selfserve = 1.00
cpm_selfserve_geotarget_country = 1.25
cpm_selfserve_geotarget_metro = 2.00
authorizenetapi = 
default_promote_bid = 50
min_promote_bid = 20
max_promote_bid = 9999
min_promote_future = 2
max_promote_future = 93
TRAFFIC_ACCESS_KEY = 
TRAFFIC_SECRET_KEY = 
RAW_LOG_DIR = 
PROCESSED_DIR = 
AGGREGATE_DIR = 
AWS_LOG_DIR = 
TRAFFIC_SRC_DIR = 
TRAFFIC_LOG_HOSTS = 
shard_link_vote_queues = false
shard_commentstree_queues = false
querycache_prune_chance = 0.05
page_cache_time = 0
commentpane_cache_time = 120

[secrets]
SECRET = YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXowMTIzNDU2Nzg5
FEEDSECRET = YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXowMTIzNDU2Nzg5
ADMINSECRET = YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXowMTIzNDU2Nzg5
websocket = YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXowMTIzNDU2Nzg5
true_ip = 
media_embed = YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXowMTIzNDU2Nzg5
stripe_webhook = 
stripe_public_key = 
stripe_secret_key = 
authorizenetname = 
authorizenetkey = 
paypal_webhook = 
coinbase_webhook = 
redditgifts_webhook = 

[server:main]
use = egg:Paste#http
host = 0.0.0.0
port = 8001

[app:main]
use = egg:r2
cache_dir = %(here)s/data
filter-with = gzip

[filter:gzip]
use = egg:r2#gzip
compress_level = 6
min_size = 800

[loggers]
keys = root

[logger_root]
level = WARNING
handlers = console

[handlers]
keys = console

[handler_console]
class = StreamHandler
args = (sys.stdout,)

[formatters]
keys = reddit

[formatter_reddit]
format = %(message)s

[live_config]
employees = reddit:admin
fastlane_links = 
announcement_message = 
sidebar_message = 
gold_sidebar_message = 
spotlight_interest_sub_p = .05
spotlight_interest_nosub_p = .1
comment_tree_version_weights = 1:1, 2:0, 3:0
frontend_logging = true
gold_revenue_goal = 0
listing_chooser_sample_multis = /user/reddit/m/hello, /user/reddit/m/world
listing_chooser_gold_multi = /user/reddit/m/gold
listing_chooser_explore_sr = 
discovery_srs = 
pennies_per_server_second = 1970/1/1:1
EOF

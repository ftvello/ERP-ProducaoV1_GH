#!/bin/bash

NNODES=${1}
MYSQLPASSWORD=${2:-""}
USERPASSWORD=${4:-$MYSQLPASSWORD}
IPPREFIX=${3:-"172.18.2."}
DEBPASSWORD=${5:-`date +%D%A%B | md5sum| sha256sum | base64| fold -w16| head -n1`}
IPLIST=`echo ""`
MYIP=`ip route get ${IPPREFIX}70 | awk 'NR==1 {print $NF}'`
MYNAME=`echo "Node$MYIP" | sed 's/$IPPREFIX.1/-/'`
FIRSTNODE=`echo "${IPPREFIX}$(( $NNODES + 9 ))"`

for (( n=1; n<=$NNODES; n++ ))
do
   IPLIST+=`echo "${IPPREFIX}$(( $n + 9 ))"`
   if [ "$n" -lt $NNODES ];
   then
        IPLIST+=`echo ","`
   fi
done

apt-get update > /dev/null
apt-get install -f -y > /dev/null

apt-get install lsb-release bc > /dev/null
REL=`lsb_release -sc`
DISTRO=`lsb_release -is | tr [:upper:] [:lower:]`

apt-get install -y --fix-missing python-software-properties > /dev/null
apt-get install software-properties-common 
if [ "$REL" = "trusty" ];
then
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
sudo add-apt-repository 'deb http://mirror.edatel.net.co/mariadb/repo/10.1/ubuntu trusty main'
else
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
sudo add-apt-repository 'deb http://mirror.edatel.net.co/mariadb/repo/10.1/ubuntu xenial main'
fi

apt-get update > /dev/null

echo "Installing MariaDB $NNODES on $DISTRO $REL ..."

DEBIAN_FRONTEND=noninteractive apt-get install -y rsync mariadb-server

echo "Configuring MariaDB"
# Remplace Debian maintenance config file

echo -e '# Automatically generated for Debian scripts. DO NOT TOUCH!
    [client]
    host     = localhost
    user     = debian-sys-maint
    password = '$DEBPASSWORD '
    socket   = /var/run/mysqld/mysqld.sock
    [mysql_upgrade]
    host     = localhost
    user     = debian-sys-maint
    password = '$DEBPASSWORD '
    socket   = /var/run/mysqld/mysqld.sock
    basedir  = /usr' > ~/debian.cnf 

mv ~/debian.cnf /etc/mysql/


# To create another MariaDB root user:
#CREATE USER '$MYSQLUSER'@'localhost' IDENTIFIED BY '$MYSQLUSERPASS';
#GRANT ALL PRIVILEGES ON *.* TO '$MYSQLUSER'@'localhost' WITH GRANT OPTION;
#CREATE USER '$MYSQLUSER'@'%' IDENTIFIED BY '$MYSQLUSERPASS';
#GRANT ALL PRIVILEGES ON *.* TO '$MYSQLUSER'@'%' WITH GRANT OPTION;

service mysql stop

# adjust my.cnf
# sed -i "s/#wsrep_on=ON/wsrep_on=ON/g" /etc/mysql/my.cnf

# create Galera config file

#wget https://raw.githubusercontent.com/pateixei/azure-nginx-php-mariadb-cluster/master/files/cluster.cnf > /dev/null
echo -e "
#
# These groups are read by MariaDB server.
# Use it for options that only the server (but not clients) should see
#
# See the examples of server my.cnf files in /usr/share/mysql/
#

# this is read by the standalone daemon and embedded servers
[server]

#Tunning
#innodb_buffer_pool_size=5120M
innodb_buffer_pool_size=14G
query_cache_type=0
max_connections = 1000
innodb_buffer_pool_instances=5
table_open_cache=400

innodb_flush_log_at_trx_commit=0
innodb_flush_method = O_DIRECT
innodb_old_blocks_time = 1000
innodb_io_capacity=600

sync_binlog=0
query_cache_size=0
query_cache_type=0
join_buffer_size=128

# key-buffer define quanto de memó serármazenado para
# # gravar dados de consultas do MySQL. Quanto maior a quantidade
# # de memó disponíl, melhor será desempenho do servidor
key_buffer=312M

# table_cache éuito importante, este nú deve ser o dobro
# # do nú definido pela variál max_connections
table_cache=2000

sort_buffer=1M
#record_buffer=1M
myisam_sort_buffer_size=64M

thread_cache=8
thread_concurrency=8

net_write_timeout=30
connect_timeout=2
wait_timeout=30

# this is only for the mysqld standalone daemon
[mysqld]
max_allowed_packet=50M
binlog_format=ROW
default-storage-engine=innodb
innodb_autoinc_lock_mode=2
query_cache_size=0
query_cache_type=0
bind-address=0.0.0.0

# this is only for embedded server
[embedded]

# This group is only read by MariaDB servers, not by MySQL.
# If you use the same .cnf file for MySQL and MariaDB,
# you can put MariaDB-only options here
[mariadb]

# This group is only read by MariaDB-10.0 servers.
# If you use the same .cnf file for MariaDB of different versions,
# use this group for options that older servers don't understand
[mariadb-10.0]" > ~/cluster.cnf 

mv ~/cluster.cnf /etc/mysql/conf.d/

sudo service mysql start > /dev/null

echo "MariaDB Cluster instalation finished"
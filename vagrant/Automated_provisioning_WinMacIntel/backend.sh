#!/bin/bash
DATABASE_PASS='admin123'

# Install dependencies
yum install epel-release -y
yum install memcached -y
yum install socat erlang wget -y

# Memcached setup
systemctl start memcached
systemctl enable memcached
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/sysconfig/memcached
systemctl restart memcached

# RabbitMQ setup
wget https://www.rabbitmq.com/releases/rabbitmq-server/v3.6.10/rabbitmq-server-3.6.10-1.el7.noarch.rpm
rpm --import https://www.rabbitmq.com/rabbitmq-release-signing-key.asc
rpm -Uvh rabbitmq-server-3.6.10-1.el7.noarch.rpm
systemctl start rabbitmq-server
systemctl enable rabbitmq-server
echo "[{rabbit, [{loopback_users, []}]}]." > /etc/rabbitmq/rabbitmq.config
rabbitmqctl add_user test test
rabbitmqctl set_user_tags test administrator
systemctl restart rabbitmq-server

# MySQL setup
yum install mariadb-server -y
sed -i 's/^127.0.0.1/0.0.0.0/' /etc/my.cnf
systemctl start mariadb
systemctl enable mariadb

# Database configuration
mysqladmin -u root password "$DATABASE_PASS"
mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User=''"
mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
mysql -u root -p"$DATABASE_PASS" -e "FLUSH PRIVILEGES"
mysql -u root -p"$DATABASE_PASS" -e "create database todo_db"
mysql -u root -p"$DATABASE_PASS" -e "grant all privileges on todo_db.* TO 'admin'@'localhost' identified by 'admin123'"
mysql -u root -p"$DATABASE_PASS" -e "grant all privileges on todo_db.* TO 'admin'@'%' identified by 'admin123'"
mysql -u root -p"$DATABASE_PASS" -e "FLUSH PRIVILEGES"

# Restart services
systemctl restart mariadb
systemctl restart memcached
systemctl restart rabbitmq-server
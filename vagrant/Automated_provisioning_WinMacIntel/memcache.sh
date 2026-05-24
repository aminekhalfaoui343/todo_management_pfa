#!/bin/bash
sudo dnf install epel-release -y
sudo dnf install memcached nc -y
sudo systemctl start memcached
sudo systemctl enable memcached

# Bind to all interfaces
sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/sysconfig/memcached
sudo systemctl restart memcached

# Configure firewall
sudo firewall-cmd --add-port=11211/tcp --permanent
sudo firewall-cmd --add-port=11211/udp --permanent
sudo firewall-cmd --reload

# Test memcached
echo "Testing memcached..."
echo "stats" | nc 192.168.56.14 11211
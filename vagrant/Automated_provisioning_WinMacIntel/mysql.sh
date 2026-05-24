#!/bin/bash
DATABASE_PASS='admin123'
sudo yum update -y
sudo yum install epel-release -y
sudo yum install git zip unzip -y
sudo yum install mariadb-server -y

# starting & enabling mariadb-server
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Secure installation and setup
sudo mysqladmin -u root password "$DATABASE_PASS"
sudo mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
sudo mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User=''"
sudo mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
sudo mysql -u root -p"$DATABASE_PASS" -e "FLUSH PRIVILEGES"

# Create database
sudo mysql -u root -p"$DATABASE_PASS" -e "create database todo_db"
sudo mysql -u root -p"$DATABASE_PASS" -e "grant all privileges on todo_db.* TO 'admin'@'localhost' identified by 'admin123'"
sudo mysql -u root -p"$DATABASE_PASS" -e "grant all privileges on todo_db.* TO 'admin'@'%' identified by 'admin123'"
sudo mysql -u root -p"$DATABASE_PASS" -e "FLUSH PRIVILEGES"

# Clone and import database
cd /tmp/
git clone -b main https://github.com/aminekhalfaoui343/todo_management_pfa.git
cd todo_management_pfa

# Import the SQL file
if [ -f "src/main/resources/script.sql" ]; then
    # Replace 'accounts' with 'todo_db' in the SQL file if needed
    sed -i 's/`accounts`/`todo_db`/g' src/main/resources/script.sql
    sed -i 's/accounts\./todo_db\./g' src/main/resources/script.sql
    sudo mysql -u root -p"$DATABASE_PASS" todo_db < src/main/resources/script.sql
    echo "Database imported successfully"
else
    echo "WARNING: script.sql not found"
fi

# Restart mariadb-server
sudo systemctl restart mariadb

# Configure firewall
sudo systemctl start firewalld
sudo systemctl enable firewalld
sudo firewall-cmd --zone=public --add-port=3306/tcp --permanent
sudo firewall-cmd --reload

# Verify database
echo "Verifying database setup..."
sudo mysql -u root -p"$DATABASE_PASS" -e "USE todo_db; SHOW TABLES;"
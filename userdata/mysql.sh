#!/bin/bash
DATABASE_PASS='admin123'

# Update system - Amazon Linux uses dnf or yum
if command -v dnf &> /dev/null; then
    sudo dnf update -y
    sudo dnf install epel-release -y
    sudo dnf install git zip unzip mariadb105-server -y
else
    sudo yum update -y
    sudo yum install epel-release -y
    sudo yum install git zip unzip mariadb-server -y
fi

# Starting & enabling mariadb-server
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Wait for MariaDB to fully start
sleep 5

# Secure installation and setup
sudo mysqladmin -u root password "$DATABASE_PASS" 2>/dev/null || echo "Root password already set"
sudo mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')" 2>/dev/null
sudo mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User=''" 2>/dev/null
sudo mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'" 2>/dev/null
sudo mysql -u root -p"$DATABASE_PASS" -e "FLUSH PRIVILEGES" 2>/dev/null

# Create database (drop if exists to avoid conflicts)
sudo mysql -u root -p"$DATABASE_PASS" -e "DROP DATABASE IF EXISTS todo_db"
sudo mysql -u root -p"$DATABASE_PASS" -e "CREATE DATABASE todo_db"
sudo mysql -u root -p"$DATABASE_PASS" -e "GRANT ALL PRIVILEGES ON todo_db.* TO 'admin'@'localhost' IDENTIFIED BY 'admin123'"
sudo mysql -u root -p"$DATABASE_PASS" -e "GRANT ALL PRIVILEGES ON todo_db.* TO 'admin'@'%' IDENTIFIED BY 'admin123'"
sudo mysql -u root -p"$DATABASE_PASS" -e "FLUSH PRIVILEGES"

# Clone and import database
cd /tmp/
# Remove existing directory if present
sudo rm -rf todo_management_pfa
git clone -b main https://github.com/aminekhalfaoui343/todo_management_pfa.git
cd todo_management_pfa

# Import the SQL file
if [ -f "src/main/resources/script.sql" ]; then
    # Create a temporary modified SQL file
    cp src/main/resources/script.sql /tmp/modified_script.sql
    
    # Replace 'accounts' with 'todo_db' in the SQL file if needed
    sed -i 's/`accounts`/`todo_db`/g' /tmp/modified_script.sql
    sed -i 's/accounts\./todo_db\./g' /tmp/modified_script.sql
    sed -i 's/`accounts`/`todo_db`/g' /tmp/modified_script.sql
    sed -i 's/ACCOUNTS/todo_db/g' /tmp/modified_script.sql
    
    # Import the modified SQL
    sudo mysql -u root -p"$DATABASE_PASS" todo_db < /tmp/modified_script.sql
    
    if [ $? -eq 0 ]; then
        echo "Database imported successfully"
    else
        echo "ERROR: Failed to import database"
        exit 1
    fi
else
    echo "WARNING: script.sql not found"
    echo "Creating sample tables for todo_db"
    
    # Create basic tables if SQL file doesn't exist
    sudo mysql -u root -p"$DATABASE_PASS" todo_db << EOF
    CREATE TABLE IF NOT EXISTS tasks (
        id INT AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        status VARCHAR(50) DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
EOF
fi

# Restart mariadb-server
sudo systemctl restart mariadb

# Configure firewall (Amazon Linux may not have firewalld by default)
if command -v firewall-cmd &> /dev/null; then
    sudo systemctl start firewalld 2>/dev/null || echo "Firewalld not available"
    sudo systemctl enable firewalld 2>/dev/null || echo "Firewalld not available"
    sudo firewall-cmd --zone=public --add-port=3306/tcp --permanent 2>/dev/null || echo "Firewall config skipped"
    sudo firewall-cmd --reload 2>/dev/null || echo "Firewall reload skipped"
else
    # For Amazon Linux, use iptables or just note that security group handles it
    echo "Note: Configure AWS Security Group to allow port 3306"
    
    # Alternative: Configure iptables if available
    if command -v iptables &> /dev/null; then
        sudo iptables -I INPUT -p tcp --dport 3306 -j ACCEPT
        sudo service iptables save 2>/dev/null || echo "iptables save skipped"
    fi
fi

# Verify database
echo "========================================="
echo "Verifying database setup..."
echo "========================================="
sudo mysql -u root -p"$DATABASE_PASS" -e "USE todo_db; SHOW TABLES;"

# Test admin user access
echo "========================================="
echo "Testing admin user access..."
echo "========================================="
sudo mysql -u admin -p"$DATABASE_PASS" -e "USE todo_db; SHOW TABLES;" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Admin user authentication successful"
else
    echo "⚠️  Admin user authentication failed - check permissions"
fi

# Display connection information
echo "========================================="
echo "Database Setup Complete!"
echo "========================================="
echo "Database Name: todo_db"
echo "Username: admin"
echo "Password: admin123"
echo "Port: 3306"
echo ""
echo "To connect from outside, ensure AWS Security Group allows inbound traffic on port 3306"
echo "Connection string: mysql -u admin -p'admin123' -h <EC2_PUBLIC_IP> todo_db"
#!/bin/bash
TOMURL="https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.26/bin/apache-tomcat-10.1.26.tar.gz"
dnf -y install java-17-openjdk java-17-openjdk-devel
dnf install git wget unzip zip nc -y
cd /tmp/
wget $TOMURL -O tomcatbin.tar.gz
EXTOUT=`tar xzvf tomcatbin.tar.gz`
TOMDIR=`echo $EXTOUT | cut -d '/' -f1`
useradd --shell /sbin/nologin tomcat
rsync -avzh /tmp/$TOMDIR/ /usr/local/tomcat/
chown -R tomcat.tomcat /usr/local/tomcat

rm -rf /etc/systemd/system/tomcat.service

cat <<EOT>> /etc/systemd/system/tomcat.service
[Unit]
Description=Tomcat
After=network.target

[Service]
User=tomcat
Group=tomcat
WorkingDirectory=/usr/local/tomcat
Environment=JAVA_HOME=/usr/lib/jvm/jre
Environment=CATALINA_PID=/var/tomcat/%i/run/tomcat.pid
Environment=CATALINA_HOME=/usr/local/tomcat
Environment=CATALINE_BASE=/usr/local/tomcat
ExecStart=/usr/local/tomcat/bin/catalina.sh run
ExecStop=/usr/local/tomcat/bin/shutdown.sh
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl start tomcat
systemctl enable tomcat

cd /tmp/
wget https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip
unzip -o apache-maven-3.9.9-bin.zip
mkdir -p /usr/local/maven3.9
cp -r apache-maven-3.9.9/* /usr/local/maven3.9/
export MAVEN_OPTS="-Xmx512m"
export PATH=$PATH:/usr/local/maven3.9/bin

# Clone the repository - using 'main' branch instead of 'local'
echo "Cloning repository..."
git clone -b main https://github.com/aminekhalfaoui343/todo_management_pfa.git

# Check if clone was successful
if [ ! -d "todo_management_pfa" ]; then
    echo "Failed to clone repository, trying without branch specification..."
    git clone https://github.com/aminekhalfaoui343/todo_management_pfa.git
fi

# Verify directory exists
if [ -d "todo_management_pfa" ]; then
    cd todo_management_pfa
    echo "Successfully entered todo_management_pfa directory"
    pwd
    ls -la
else
    echo "ERROR: todo_management_pfa directory not found!"
    exit 1
fi

# Fix database name in source code
echo "Updating database name in source code..."
find ./src -type f -name "*.properties" -exec sed -i 's/accounts/todo_db/g' {} \; 2>/dev/null || true
find ./src -type f -name "*.xml" -exec sed -i 's/accounts/todo_db/g' {} \; 2>/dev/null || true
find ./src -type f -name "*.java" -exec sed -i 's/accounts/todo_db/g' {} \; 2>/dev/null || true

# Build the application
echo "Building application with Maven..."
/usr/local/maven3.9/bin/mvn clean install -DskipTests

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "Maven build failed!"
    exit 1
fi

# Check if WAR file exists
if [ ! -f "target/todo-management.war" ]; then
    echo "WAR file not found! Checking target directory..."
    ls -la target/
    exit 1
fi

echo "WAR file found, proceeding with deployment..."

systemctl stop tomcat
sleep 10
rm -rf /usr/local/tomcat/webapps/ROOT*
rm -rf /usr/local/tomcat/webapps/todo-management*

# Copy WAR file
cp target/todo-management.war /usr/local/tomcat/webapps/ROOT.war
echo "WAR file copied successfully"

systemctl start tomcat
echo "Waiting for Tomcat to extract WAR file..."
sleep 30

# Copy application.properties
if [ -d "/usr/local/tomcat/webapps/ROOT/WEB-INF/classes/" ]; then
    if [ -f "/vagrant/application.properties" ]; then
        cp /vagrant/application.properties /usr/local/tomcat/webapps/ROOT/WEB-INF/classes/
        chown tomcat.tomcat /usr/local/tomcat/webapps/ROOT/WEB-INF/classes/application.properties
        echo "Application properties copied successfully"
    else
        echo "WARNING: application.properties not found in /vagrant/"
    fi
else
    echo "WARNING: ROOT/WEB-INF/classes/ directory not found yet"
    echo "Waiting additional 20 seconds..."
    sleep 20
    if [ -d "/usr/local/tomcat/webapps/ROOT/WEB-INF/classes/" ]; then
        if [ -f "/vagrant/application.properties" ]; then
            cp /vagrant/application.properties /usr/local/tomcat/webapps/ROOT/WEB-INF/classes/
            chown tomcat.tomcat /usr/local/tomcat/webapps/ROOT/WEB-INF/classes/application.properties
            echo "Application properties copied successfully"
        fi
    else
        echo "ERROR: ROOT directory still not found"
        ls -la /usr/local/tomcat/webapps/
    fi
fi

systemctl restart tomcat
sleep 10

# Disable firewall for testing
systemctl stop firewalld
systemctl disable firewalld

# Test the application
echo "Testing application locally..."
curl -I http://localhost:8080/ || echo "Application not yet ready, checking logs..."

# Check Tomcat logs
echo "=== Tomcat Logs ==="
tail -30 /usr/local/tomcat/logs/catalina.out
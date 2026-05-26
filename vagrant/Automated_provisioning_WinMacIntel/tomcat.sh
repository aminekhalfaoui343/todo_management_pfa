#!/bin/bash
# Use Tomcat 9 (compatible with JSP and javax.* packages)
TOMURL="https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.89/bin/apache-tomcat-9.0.89.tar.gz"

# Install dependencies
dnf -y install java-17-openjdk java-17-openjdk-devel
dnf install git wget unzip zip nc -y

# Download and install Tomcat 9
cd /tmp/
wget $TOMURL -O tomcatbin.tar.gz
tar xzvf tomcatbin.tar.gz
TOMDIR=`tar tzf tomcatbin.tar.gz | head -1 | cut -d '/' -f1`
useradd --shell /sbin/nologin tomcat
rsync -avzh /tmp/$TOMDIR/ /usr/local/tomcat/
chown -R tomcat.tomcat /usr/local/tomcat/

# Create systemd service
cat <<EOT > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat 9
After=network.target

[Service]
User=tomcat
Group=tomcat
WorkingDirectory=/usr/local/tomcat
Environment=JAVA_HOME=/usr/lib/jvm/jre
Environment=CATALINA_PID=/usr/local/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/usr/local/tomcat
Environment=CATALINA_BASE=/usr/local/tomcat
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

sleep 10

# Install Maven
cd /tmp/
wget https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip
unzip -o apache-maven-3.9.9-bin.zip
mkdir -p /usr/local/maven3.9
cp -r apache-maven-3.9.9/* /usr/local/maven3.9/
export PATH=$PATH:/usr/local/maven3.9/bin

# Clone and build
git clone https://github.com/aminekhalfaoui343/todo_management_pfa.git
cd todo_management_pfa

# Build WAR
/usr/local/maven3.9/bin/mvn clean package -DskipTests

# Deploy
systemctl stop tomcat
sleep 5
rm -rf /usr/local/tomcat/webapps/ROOT*
cp target/todo-management.war /usr/local/tomcat/webapps/ROOT.war

# Fix permissions
chown -R tomcat.tomcat /usr/local/tomcat/webapps/
chmod -R 755 /usr/local/tomcat/webapps/

# Disable SELinux
setenforce 0 2>/dev/null
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config 2>/dev/null

# Disable firewall
systemctl stop firewalld 2>/dev/null
systemctl disable firewalld 2>/dev/null

systemctl start tomcat

sleep 20

echo "Tomcat 9 deployment complete!"
curl -I http://localhost:8080/login
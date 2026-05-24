#!/bin/bash
sudo apt update
sudo apt upgrade -y
sudo apt install openjdk-17-jdk openjdk-17-jre git wget unzip maven -y

# Download and install Tomcat
cd /tmp/
wget https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.26/bin/apache-tomcat-10.1.26.tar.gz
tar xzvf apache-tomcat-10.1.26.tar.gz
sudo mv apache-tomcat-10.1.26 /usr/local/tomcat

# Create tomcat user
sudo useradd --shell /sbin/nologin tomcat
sudo chown -R tomcat.tomcat /usr/local/tomcat

# Clone and build application
git clone -b local https://github.com/aminekhalfaoui343/todo_management_pfa.git
cd todo_management_pfa
mvn clean install -DskipTests

# Deploy application
sudo systemctl stop tomcat 2>/dev/null || true
sleep 5
sudo rm -rf /usr/local/tomcat/webapps/ROOT*
sudo cp target/todo-management.war /usr/local/tomcat/webapps/ROOT.war

# Create systemd service
sudo cat <<EOT > /etc/systemd/system/tomcat.service
[Unit]
Description=Tomcat
After=network.target

[Service]
User=tomcat
Group=tomcat
WorkingDirectory=/usr/local/tomcat
Environment=JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
Environment=CATALINA_HOME=/usr/local/tomcat
ExecStart=/usr/local/tomcat/bin/catalina.sh run
ExecStop=/usr/local/tomcat/bin/shutdown.sh
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOT

sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat
sleep 30

# Copy application properties
if [ -d "/usr/local/tomcat/webapps/ROOT/WEB-INF/classes/" ]; then
    sudo cp /vagrant/application.properties /usr/local/tomcat/webapps/ROOT/WEB-INF/classes/
    sudo chown tomcat.tomcat /usr/local/tomcat/webapps/ROOT/WEB-INF/classes/application.properties
fi

sudo systemctl restart tomcat
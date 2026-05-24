#!/bin/bash
# adding repository and installing nginx		
apt update
apt install nginx curl -y

# Create nginx configuration
cat <<EOT > /etc/nginx/sites-available/todo_management
upstream todoapp {
    server app01:8080;
}

server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://todoapp;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOT

# Enable the site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/todo_management /etc/nginx/sites-enabled/todo_management

# Test nginx configuration
nginx -t

# Start nginx service
systemctl start nginx
systemctl enable nginx
systemctl restart nginx

# Test nginx
echo "Testing nginx configuration..."
curl -I http://localhost:80/
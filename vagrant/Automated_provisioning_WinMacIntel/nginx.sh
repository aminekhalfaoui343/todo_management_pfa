#!/bin/bash
# Update and install nginx
apt update
apt install nginx curl netcat-openbsd -y

# Test connectivity to Tomcat
echo "Testing connectivity to Tomcat VM..."
if nc -zv 192.168.56.12 8080 2>&1; then
    echo "✅ Tomcat is reachable on port 8080"
else
    echo "⚠️  Cannot reach Tomcat on 192.168.56.12:8080"
fi

# Create nginx configuration
cat <<EOT > /etc/nginx/sites-available/todo_management
upstream todoapp {
    server 192.168.56.12:8080;
    keepalive 32;
}

server {
    listen 80;
    server_name _;

    # Increase max body size
    client_max_body_size 10M;

    # Root redirect to login page
    location = / {
        return 302 /login;
    }

    location / {
        proxy_pass http://todoapp;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeout settings
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # Buffering settings
        proxy_buffering off;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Error pages
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOT

# Remove default site
rm -f /etc/nginx/sites-enabled/default

# Enable our site
ln -sf /etc/nginx/sites-available/todo_management /etc/nginx/sites-enabled/todo_management

# Test nginx configuration
echo "Testing nginx configuration..."
if nginx -t; then
    echo "✅ Nginx configuration is valid"
else
    echo "❌ Nginx configuration has errors"
    nginx -t 2>&1
    exit 1
fi

# Restart nginx
systemctl restart nginx

# Wait for nginx to be ready
sleep 3

# Test nginx
echo "Testing nginx proxy..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/login 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Application is working and accessible!"
    echo "Access the application at: http://192.168.56.11/"
elif [ "$HTTP_CODE" = "302" ]; then
    echo "✅ Application is redirecting correctly"
    echo "Access the application at: http://192.168.56.11/"
elif [ "$HTTP_CODE" = "404" ]; then
    echo "⚠️  Application returned 404"
    echo "Try accessing: http://192.168.56.11/login"
else
    echo "⚠️  Application responded with HTTP $HTTP_CODE"
fi

# Test direct connection to Tomcat
echo "=== Testing direct connection to Tomcat ==="
DIRECT_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.56.12:8080/login 2>/dev/null || echo "000")
if [ "$DIRECT_CODE" = "200" ]; then
    echo "✅ Tomcat is working and login page is accessible!"
elif [ "$DIRECT_CODE" = "404" ]; then
    echo "⚠️  Tomcat is running but login page not found"
else
    echo "❌ Cannot reach Tomcat directly (HTTP $DIRECT_CODE)"
fi

echo ""
echo "=== Setup Complete ==="
echo "Application URL: http://192.168.56.11/"
echo "Login Page: http://192.168.56.11/login"
echo "Direct Tomcat URL: http://192.168.56.12:8080/login"
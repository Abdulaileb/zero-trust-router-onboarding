#!/bin/sh
#
# HTTPS Captive Portal Setup Script
# Purpose: Configure TLS-enabled captive portal for credential injection
# Uses uhttpd (OpenWRT) or nginx with self-signed certificates
#

set -e

SCRIPT_NAME="https-portal-setup"
LOG_FILE="/var/log/${SCRIPT_NAME}.log"
PORTAL_DIR="/www/onboarding"
CERT_DIR="/etc/onboarding/certs"
PORTAL_IP="${PORTAL_IP:-192.168.1.1}"
PORTAL_DOMAIN="${PORTAL_DOMAIN:-onboarding.local}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting HTTPS captive portal setup..."

# Create directories
mkdir -p "$PORTAL_DIR"
mkdir -p "$CERT_DIR"
mkdir -p /tmp/onboarding

log "Created portal directories"

# Generate self-signed SSL certificate
log "Generating self-signed SSL certificate..."

openssl req -x509 -newkey rsa:4096 -nodes \
    -keyout "$CERT_DIR/key.pem" \
    -out "$CERT_DIR/cert.pem" \
    -days 365 \
    -subj "/C=US/ST=State/L=City/O=ZeroTrust/CN=$PORTAL_DOMAIN" \
    2>&1 | tee -a "$LOG_FILE"

chmod 600 "$CERT_DIR/key.pem"
chmod 644 "$CERT_DIR/cert.pem"

log "SSL certificate generated successfully"

# Create captive portal HTML page
log "Creating captive portal web interface..."

cat > "$PORTAL_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Router Onboarding - Zero Trust</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 12px;
            padding: 40px;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 28px;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 14px;
        }
        .status {
            background: #f0f4ff;
            border-left: 4px solid #667eea;
            padding: 15px;
            margin-bottom: 30px;
            border-radius: 4px;
        }
        .status-title {
            font-weight: 600;
            color: #667eea;
            margin-bottom: 5px;
        }
        .status-text {
            color: #555;
            font-size: 14px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 8px;
            color: #333;
            font-weight: 500;
            font-size: 14px;
        }
        input[type="text"],
        input[type="password"] {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 6px;
            font-size: 14px;
            transition: border-color 0.3s;
        }
        input[type="text"]:focus,
        input[type="password"]:focus {
            outline: none;
            border-color: #667eea;
        }
        .btn {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 6px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
        }
        .btn:active {
            transform: translateY(0);
        }
        .security-note {
            margin-top: 20px;
            padding: 15px;
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            border-radius: 4px;
            font-size: 13px;
            color: #856404;
        }
        .icon {
            font-size: 48px;
            text-align: center;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">🔒</div>
        <h1>Router Onboarding</h1>
        <p class="subtitle">Zero-Trust Security Framework</p>
        
        <div class="status">
            <div class="status-title">⚠️ WAN Access Blocked</div>
            <div class="status-text">Internet access is currently disabled. Please complete onboarding to activate your router.</div>
        </div>

        <form id="onboardingForm" action="/cgi-bin/onboard.sh" method="POST">
            <div class="form-group">
                <label for="device_id">Device ID</label>
                <input type="text" id="device_id" name="device_id" placeholder="Enter your device identifier" required>
            </div>
            
            <div class="form-group">
                <label for="api_key">API Key / Credential</label>
                <input type="password" id="api_key" name="api_key" placeholder="Enter your API key" required>
            </div>
            
            <div class="form-group">
                <label for="owner_email">Owner Email</label>
                <input type="text" id="owner_email" name="owner_email" placeholder="owner@example.com" required>
            </div>

            <button type="submit" class="btn">Activate Router</button>
        </form>

        <div class="security-note">
            🔐 <strong>Secure Connection:</strong> All credentials are transmitted over HTTPS and stored encrypted. This router follows zero-trust security principles.
        </div>
    </div>

    <script>
        document.getElementById('onboardingForm').addEventListener('submit', function(e) {
            e.preventDefault();
            
            const formData = new FormData(this);
            
            fetch('/cgi-bin/onboard.sh', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    alert('✅ Onboarding successful! WAN access is now enabled.');
                    window.location.href = '/success.html';
                } else {
                    alert('❌ Onboarding failed: ' + (data.error || 'Unknown error'));
                }
            })
            .catch(error => {
                alert('❌ Connection error: ' + error.message);
            });
        });
    </script>
</body>
</html>
EOF

log "Created captive portal HTML page"

# Create success page
cat > "$PORTAL_DIR/success.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Onboarding Complete</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 12px;
            padding: 40px;
            max-width: 500px;
            width: 100%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
        }
        .icon { font-size: 72px; margin-bottom: 20px; }
        h1 { color: #333; margin-bottom: 15px; }
        p { color: #666; line-height: 1.6; margin-bottom: 30px; }
        .info { background: #f0f9ff; padding: 15px; border-radius: 6px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">✅</div>
        <h1>Onboarding Complete!</h1>
        <p>Your router has been successfully configured and WAN access is now enabled.</p>
        <div class="info">
            <strong>Next Steps:</strong><br>
            You can now access the internet. The captive portal will be disabled in 30 seconds.
        </div>
    </div>
    <script>
        setTimeout(() => { window.location.href = 'http://www.google.com'; }, 30000);
    </script>
</body>
</html>
EOF

log "Created success page"

# Create CGI script directory
mkdir -p /www/cgi-bin

# Configure web server (uhttpd for OpenWRT)
if command -v uhttpd > /dev/null 2>&1; then
    log "Configuring uhttpd for HTTPS..."
    
    # Create uhttpd config for onboarding
    cat > /etc/config/uhttpd-onboarding << EOF
config uhttpd 'onboarding'
    option home '$PORTAL_DIR'
    option rfc1918_filter '0'
    option max_requests '10'
    option cert '$CERT_DIR/cert.pem'
    option key '$CERT_DIR/key.pem'
    list listen_https '0.0.0.0:443'
    list listen_http '0.0.0.0:80'
    option redirect_https '1'
    option cgi_prefix '/cgi-bin'
    option script_timeout '60'
    option network_timeout '30'
EOF
    
    /etc/init.d/uhttpd restart
    log "uhttpd configured and restarted"
    
elif command -v nginx > /dev/null 2>&1; then
    log "Configuring nginx for HTTPS..."
    
    cat > /etc/nginx/sites-available/onboarding << EOF
server {
    listen 80;
    listen [::]:80;
    server_name _;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    
    ssl_certificate $CERT_DIR/cert.pem;
    ssl_certificate_key $CERT_DIR/key.pem;
    
    root $PORTAL_DIR;
    index index.html;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location /cgi-bin/ {
        gzip off;
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /www/cgi-bin\$fastcgi_script_name;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/onboarding /etc/nginx/sites-enabled/
    nginx -s reload
    log "nginx configured and reloaded"
else
    log "WARNING: No supported web server found (uhttpd or nginx)"
fi

log "HTTPS captive portal setup complete"
log "Portal available at https://$PORTAL_IP/"

touch /tmp/https-portal-active
exit 0

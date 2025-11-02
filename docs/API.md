# API Documentation

## Overview

This document describes the APIs and interfaces for the Zero-Trust Router Onboarding Framework.

## REST API

### Onboarding Endpoint

**POST** `/cgi-bin/onboard.sh`

Submit credentials for router onboarding and WAN activation.

#### Request

**Content-Type:** `application/x-www-form-urlencoded`

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| device_id | string | Yes | Unique device identifier |
| api_key | string | Yes | API authentication key (min 8 chars) |
| owner_email | string | Yes | Owner email address |

**Example Request:**
```http
POST /cgi-bin/onboard.sh HTTP/1.1
Host: 192.168.1.1
Content-Type: application/x-www-form-urlencoded

device_id=router-abc123&api_key=secure-key-12345678&owner_email=user@example.com
```

**Example cURL:**
```bash
curl -X POST https://192.168.1.1/cgi-bin/onboard.sh \
  -k \
  -d "device_id=router-abc123" \
  -d "api_key=secure-key-12345678" \
  -d "owner_email=user@example.com"
```

#### Response

**Content-Type:** `application/json`

**Success Response (200 OK):**
```json
{
  "success": true,
  "message": "WAN access activated successfully",
  "device_id": "router-abc123"
}
```

**Error Response (400 Bad Request):**
```json
{
  "success": false,
  "error": "Invalid email format"
}
```

```json
{
  "success": false,
  "error": "Missing required parameters"
}
```

```json
{
  "success": false,
  "error": "Invalid API key format"
}
```

#### Status Codes

| Code | Description |
|------|-------------|
| 200 | Success - WAN activated |
| 400 | Bad Request - Invalid parameters |
| 500 | Internal Server Error |

---

## Script Interfaces

### setup.sh

Main orchestration script for system initialization.

**Usage:**
```bash
sudo ./scripts/setup.sh
```

**Environment Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| PORTAL_IP | 192.168.1.1 | Portal IP address |
| PORTAL_DOMAIN | onboarding.local | Portal domain name |

**Exit Codes:**
- `0` - Success
- `1` - Error (check logs)

**Outputs:**
- Logs to `/var/log/zero-trust-setup.log`
- Console output with colored status

---

### firewall-setup.sh

Configure firewall to block WAN access.

**Usage:**
```bash
sudo ./scripts/firewall-setup.sh
```

**Actions:**
- Sets DROP policy on FORWARD chain
- Allows LAN to router communication
- Blocks WAN forwarding
- Enables logging

**Files Created:**
- `/tmp/firewall-onboarding-mode` - Marker file

**Logs:**
- `/var/log/firewall-setup.log`

**Exit Codes:**
- `0` - Success
- `1` - Error

---

### dns-hijack.sh

Configure DNS hijacking for captive portal.

**Usage:**
```bash
sudo ./scripts/dns-hijack.sh
```

**Environment Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| PORTAL_IP | 192.168.1.1 | IP to redirect DNS queries to |

**Actions:**
- Creates dnsmasq configuration
- Redirects all DNS to portal
- Configures DHCP server
- Restarts dnsmasq

**Files Created:**
- `/etc/dnsmasq.d/onboarding.conf` - DNS hijack config
- `/tmp/dns-hijack-active` - Marker file

**Logs:**
- `/var/log/dns-hijack.log`

**Exit Codes:**
- `0` - Success
- `1` - Error (dnsmasq not running)

---

### https-portal-setup.sh

Setup HTTPS captive portal.

**Usage:**
```bash
sudo ./scripts/https-portal-setup.sh
```

**Environment Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| PORTAL_IP | 192.168.1.1 | Portal IP address |
| PORTAL_DOMAIN | onboarding.local | Portal domain |
| PORTAL_DIR | /www/onboarding | Portal web root |
| CERT_DIR | /etc/onboarding/certs | Certificate directory |

**Actions:**
- Generates self-signed SSL certificate
- Creates portal HTML pages
- Configures web server (uhttpd/nginx)
- Sets up CGI handler

**Files Created:**
- `/etc/onboarding/certs/cert.pem` - SSL certificate
- `/etc/onboarding/certs/key.pem` - Private key
- `/www/onboarding/index.html` - Portal page
- `/www/onboarding/success.html` - Success page
- `/tmp/https-portal-active` - Marker file

**Logs:**
- `/var/log/https-portal-setup.log`

**Exit Codes:**
- `0` - Success
- `1` - Error

---

### wan-activation.sh

Activate WAN access after credential verification.

**Usage:**
```bash
sudo ./scripts/wan-activation.sh <device_id> <api_key> <owner_email>
```

**Arguments:**

| Position | Parameter | Description |
|----------|-----------|-------------|
| 1 | device_id | Device identifier |
| 2 | api_key | API authentication key |
| 3 | owner_email | Owner email address |

**Example:**
```bash
./scripts/wan-activation.sh "router-abc123" "secure-key-12345678" "user@example.com"
```

**Actions:**
- Validates credentials
- Removes WAN blocking rules
- Enables NAT/masquerading
- Restores normal DNS
- Saves activation state

**Files Created:**
- `/etc/onboarding/credentials.enc` - Encrypted credentials
- `/etc/onboarding/state` - Activation state

**Files Removed:**
- `/tmp/firewall-onboarding-mode`
- `/tmp/dns-hijack-active`

**Logs:**
- `/var/log/wan-activation.log`

**Output:**
JSON formatted response to stdout

**Exit Codes:**
- `0` - Success
- `1` - Invalid parameters or validation failed

---

## State Files

### /etc/onboarding/state

Tracks onboarding activation status.

**Format:**
```bash
STATE=activated
DEVICE_ID=router-abc123
OWNER_EMAIL=user@example.com
ACTIVATION_TIME=2024-01-15T10:30:00Z
```

**Fields:**

| Field | Description |
|-------|-------------|
| STATE | Current state (activated/pending) |
| DEVICE_ID | Device identifier |
| OWNER_EMAIL | Owner email |
| ACTIVATION_TIME | ISO 8601 timestamp |

---

### /etc/onboarding/credentials.enc

Stores encrypted credentials.

**Format:**
```bash
DEVICE_ID=<base64_encoded>
API_KEY=<base64_encoded>
OWNER_EMAIL=<base64_encoded>
TIMESTAMP=2024-01-15T10:30:00Z
```

**Security:**
- File permissions: `600` (owner read/write only)
- Encoding: Base64 (replace with GPG/age in production)

---

## Marker Files

### /tmp/firewall-onboarding-mode

Indicates firewall is in onboarding mode (WAN blocked).

**Presence:** File exists = onboarding mode active

### /tmp/dns-hijack-active

Indicates DNS hijacking is active.

**Presence:** File exists = DNS hijack active

### /tmp/https-portal-active

Indicates HTTPS portal is running.

**Presence:** File exists = portal active

---

## Configuration Files

### /etc/dnsmasq.d/onboarding.conf

DNS hijacking configuration for dnsmasq.

**Key Directives:**
```
address=/#/192.168.1.1      # Hijack all domains
no-resolv                    # Disable upstream DNS
dhcp-range=...              # DHCP configuration
```

### configs/onboarding.conf

System configuration file.

**Example:**
```bash
PORTAL_IP=192.168.1.1
LAN_INTERFACE=br-lan
WAN_INTERFACE=wan
CERT_VALIDITY_DAYS=365
```

---

## Web Portal Pages

### /www/onboarding/index.html

Main captive portal page.

**Features:**
- Responsive design
- HTTPS form submission
- Client-side validation
- Mobile-friendly

**Form Fields:**
- Device ID (text input)
- API Key (password input)
- Owner Email (email input)

**Submit Action:**
POST to `/cgi-bin/onboard.sh`

### /www/onboarding/success.html

Post-activation success page.

**Features:**
- Confirmation message
- Auto-redirect after 30 seconds
- Success animation

---

## JavaScript API

### Portal Form Handler

**Location:** Embedded in `/www/onboarding/index.html`

**Function:**
```javascript
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
            window.location.href = '/success.html';
        } else {
            alert('Error: ' + data.error);
        }
    });
});
```

---

## Integration Examples

### Custom Credential Verification

Modify `wan-activation.sh` to integrate with external API:

```bash
# Add after credential parsing
verify_credentials() {
    local device_id="$1"
    local api_key="$2"
    
    response=$(curl -s -X POST "$API_ENDPOINT/verify" \
        -H "Content-Type: application/json" \
        -d "{\"device_id\":\"$device_id\",\"api_key\":\"$api_key\"}" \
        --max-time 10)
    
    if echo "$response" | grep -q '"valid":true'; then
        return 0
    else
        return 1
    fi
}

if ! verify_credentials "$DEVICE_ID" "$API_KEY"; then
    log "ERROR: Credential verification failed"
    echo '{"success": false, "error": "Invalid credentials"}'
    exit 1
fi
```

### Monitoring Integration

Add monitoring hooks:

```bash
# In wan-activation.sh, after successful activation
send_metric() {
    echo "router.onboarding.activated:1|c" | \
        nc -u -w1 metrics-server 8125
}

send_notification() {
    curl -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"event\":\"onboarding_complete\",\"device_id\":\"$DEVICE_ID\"}"
}

send_metric
send_notification
```

### LDAP Authentication

Replace basic validation with LDAP:

```bash
verify_ldap() {
    ldapsearch -x -H "$LDAP_SERVER" \
        -D "cn=$OWNER_EMAIL,dc=example,dc=com" \
        -w "$API_KEY" \
        -b "dc=example,dc=com" \
        "(uid=$DEVICE_ID)" > /dev/null 2>&1
    
    return $?
}
```

---

## Testing API

Run test suites:

```bash
# Test all components
cd tests
sudo ./test-firewall.sh
sudo ./test-dns-hijack.sh
sudo ./test-portal-access.sh
sudo ./test-wan-activation.sh

# Test onboarding flow end-to-end
curl -X POST https://192.168.1.1/cgi-bin/onboard.sh \
    -k \
    -d "device_id=test-router" \
    -d "api_key=test-key-12345678" \
    -d "owner_email=test@example.com" \
    -v
```

---

## Error Handling

### Common Error Codes

| Error | Description | Resolution |
|-------|-------------|------------|
| Missing parameters | Required field not provided | Check all form fields |
| Invalid email | Email format incorrect | Use valid email format |
| API key too short | Key < 8 characters | Use longer key |
| WAN activation script not found | Script missing or not executable | Check installation |
| dnsmasq not running | DNS service down | Restart dnsmasq |

### Debug Mode

Enable verbose logging:

```bash
export DEBUG=1
./scripts/setup.sh
```

Check logs:
```bash
tail -f /var/log/*.log
```

---

## Rate Limiting

To add rate limiting (not in prototype):

```bash
# In firewall-setup.sh
iptables -A INPUT -p tcp --dport 443 \
    -m state --state NEW \
    -m recent --set --name HTTPS_LIMIT

iptables -A INPUT -p tcp --dport 443 \
    -m state --state NEW \
    -m recent --update --seconds 60 --hitcount 20 \
    --name HTTPS_LIMIT -j DROP
```

---

## Security Headers

Add to web server config:

```nginx
add_header X-Frame-Options "DENY";
add_header X-Content-Type-Options "nosniff";
add_header X-XSS-Protection "1; mode=block";
add_header Content-Security-Policy "default-src 'self'";
add_header Strict-Transport-Security "max-age=31536000";
```

---

## Version History

### v1.0.0
- Initial release
- Basic onboarding flow
- HTTPS portal
- DNS hijacking
- Firewall configuration
- WAN activation

---

## Support

For API questions or issues:
- GitHub: https://github.com/Abdulaileb/zero-trust-router-onboarding/issues
- Documentation: See `docs/` directory

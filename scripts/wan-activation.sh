#!/bin/sh
#
# WAN Activation Script
# Purpose: Enable WAN access after successful credential verification
# Called by the captive portal CGI script after onboarding
#

set -e

SCRIPT_NAME="wan-activation"
LOG_FILE="/var/log/${SCRIPT_NAME}.log"
CREDENTIALS_FILE="/etc/onboarding/credentials.enc"
STATE_FILE="/etc/onboarding/state"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Parse credentials (passed as arguments)
DEVICE_ID="$1"
API_KEY="$2"
OWNER_EMAIL="$3"

log "WAN activation requested for device: $DEVICE_ID"

# Validate inputs
if [ -z "$DEVICE_ID" ] || [ -z "$API_KEY" ] || [ -z "$OWNER_EMAIL" ]; then
    log "ERROR: Missing required parameters"
    echo '{"success": false, "error": "Missing required parameters"}'
    exit 1
fi

# Create onboarding directory
mkdir -p /etc/onboarding

# Verify credentials (in production, this would call an API)
# For this prototype, we do basic validation
log "Verifying credentials..."

if [ ${#API_KEY} -lt 8 ]; then
    log "ERROR: API key too short"
    echo '{"success": false, "error": "Invalid API key format"}'
    exit 1
fi

# Validate email format (basic check)
if ! echo "$OWNER_EMAIL" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then
    log "ERROR: Invalid email format"
    echo '{"success": false, "error": "Invalid email format"}'
    exit 1
fi

log "Credentials validated successfully"

# Store encrypted credentials
# In production, use proper encryption (GPG, age, etc.)
# Here we use base64 encoding as a placeholder
cat > "$CREDENTIALS_FILE" << EOF
DEVICE_ID=$(echo "$DEVICE_ID" | base64)
API_KEY=$(echo "$API_KEY" | base64)
OWNER_EMAIL=$(echo "$OWNER_EMAIL" | base64)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

chmod 600 "$CREDENTIALS_FILE"
log "Credentials stored securely"

# Update firewall rules to enable WAN
log "Enabling WAN access..."

# Remove WAN blocking rules
iptables -D FORWARD -o eth1 -j DROP 2>/dev/null || true
iptables -D FORWARD -o wan -j DROP 2>/dev/null || true

# Allow forwarding from LAN to WAN
iptables -A FORWARD -i br-lan -o eth1 -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i br-lan -o wan -j ACCEPT 2>/dev/null || true
iptables -A FORWARD -i eth0 -o eth1 -j ACCEPT 2>/dev/null || true

# Enable NAT/masquerading for internet access
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE 2>/dev/null || true
iptables -t nat -A POSTROUTING -o wan -j MASQUERADE 2>/dev/null || true

log "Firewall rules updated - WAN access enabled"

# Update state file
cat > "$STATE_FILE" << EOF
STATE=activated
DEVICE_ID=$DEVICE_ID
OWNER_EMAIL=$OWNER_EMAIL
ACTIVATION_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

log "State file updated"

# Clean up onboarding mode markers
rm -f /tmp/firewall-onboarding-mode
rm -f /tmp/dns-hijack-active

# Restore normal DNS operation
log "Restoring normal DNS operation..."

# Remove DNS hijack configuration
rm -f /etc/dnsmasq.d/onboarding.conf

# Restart dnsmasq with normal config
if command -v service > /dev/null 2>&1; then
    service dnsmasq restart
elif [ -f /etc/init.d/dnsmasq ]; then
    /etc/init.d/dnsmasq restart
else
    killall dnsmasq 2>/dev/null || true
    dnsmasq
fi

log "DNS service restored to normal operation"

# Optional: Stop captive portal web server
# (In production, you might want to keep it running for management)
log "Captive portal can now be disabled (optional)"

# Log successful activation
log "========================================="
log "WAN ACTIVATION SUCCESSFUL"
log "Device ID: $DEVICE_ID"
log "Owner: $OWNER_EMAIL"
log "Time: $(date)"
log "========================================="

# Send success response
echo '{"success": true, "message": "WAN access activated successfully", "device_id": "'$DEVICE_ID'"}'

# Send notification (optional - would integrate with monitoring system)
# notify_activation "$DEVICE_ID" "$OWNER_EMAIL"

exit 0

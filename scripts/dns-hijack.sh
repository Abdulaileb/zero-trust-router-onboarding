#!/bin/sh
#
# DNS Hijack Script for Zero-Trust Router Onboarding
# Purpose: Redirect all DNS queries to captive portal during onboarding
# Uses dnsmasq for DNS hijacking
#

set -e

SCRIPT_NAME="dns-hijack"
LOG_FILE="/var/log/${SCRIPT_NAME}.log"
PORTAL_IP="${PORTAL_IP:-192.168.1.1}"
DNSMASQ_CONF="/etc/dnsmasq.d/onboarding.conf"
DNSMASQ_MAIN="/etc/dnsmasq.conf"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting DNS hijack setup for captive portal..."

# Create dnsmasq config directory if it doesn't exist
mkdir -p /etc/dnsmasq.d

# Configure dnsmasq for DNS hijacking
log "Configuring dnsmasq for DNS hijacking to $PORTAL_IP"

cat > "$DNSMASQ_CONF" << EOF
# Zero-Trust Onboarding DNS Hijack Configuration
# Generated on $(date)

# Disable upstream DNS servers during onboarding
no-resolv

# Don't read /etc/resolv.conf
no-poll

# Address all DNS queries to captive portal
address=/#/$PORTAL_IP

# Log DNS queries for debugging
log-queries

# Increase cache size
cache-size=1000

# Enable DHCP authoritative mode
dhcp-authoritative

# DHCP range for LAN (adjust as needed)
dhcp-range=192.168.1.50,192.168.1.200,12h

# Set captive portal as DNS server
dhcp-option=6,$PORTAL_IP

# Prevent DNS rebinding attacks
stop-dns-rebind
rebind-localhost-ok

# Local domain
local=/onboarding.local/
domain=onboarding.local

# Serve captive portal detection pages
# Apple iOS/macOS
address=/captive.apple.com/$PORTAL_IP
# Android
address=/clients3.google.com/$PORTAL_IP
address=/connectivitycheck.gstatic.com/$PORTAL_IP
# Windows
address=/www.msftconnecttest.com/$PORTAL_IP
# Firefox
address=/detectportal.firefox.com/$PORTAL_IP

EOF

log "DNS hijack configuration created at $DNSMASQ_CONF"

# Ensure dnsmasq includes our config directory
if [ -f "$DNSMASQ_MAIN" ]; then
    if ! grep -q "conf-dir=/etc/dnsmasq.d" "$DNSMASQ_MAIN" 2>/dev/null; then
        echo "conf-dir=/etc/dnsmasq.d" >> "$DNSMASQ_MAIN"
        log "Added conf-dir directive to $DNSMASQ_MAIN"
    fi
fi

# Restart dnsmasq to apply changes
if command -v service > /dev/null 2>&1; then
    service dnsmasq restart
    log "dnsmasq service restarted"
elif [ -f /etc/init.d/dnsmasq ]; then
    /etc/init.d/dnsmasq restart
    log "dnsmasq restarted via init.d"
else
    killall dnsmasq 2>/dev/null || true
    dnsmasq
    log "dnsmasq restarted manually"
fi

# Verify dnsmasq is running
if pgrep dnsmasq > /dev/null; then
    log "DNS hijack setup complete - dnsmasq is running"
else
    log "ERROR: dnsmasq is not running!"
    exit 1
fi

# Create marker file
touch /tmp/dns-hijack-active
log "DNS hijack is now active"

exit 0

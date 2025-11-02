#!/bin/sh
#
# Firewall Setup Script for Zero-Trust Router Onboarding
# Purpose: Block WAN access by default until onboarding is complete
# Compatible with OpenWRT firewall (nftables/iptables)
#

set -e

SCRIPT_NAME="firewall-setup"
LOG_FILE="/var/log/${SCRIPT_NAME}.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting firewall setup for zero-trust onboarding..."

# Check if running on OpenWRT
if [ ! -f /etc/openwrt_release ]; then
    log "WARNING: Not running on OpenWRT, using generic iptables rules"
fi

# Flush existing rules (careful in production!)
log "Configuring firewall rules..."

# Block all WAN traffic by default
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -P INPUT DROP

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established and related connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow LAN to router communication (assuming br-lan is LAN interface)
iptables -A INPUT -i br-lan -j ACCEPT
iptables -A INPUT -i eth0 -j ACCEPT

# Allow DHCP from LAN
iptables -A INPUT -p udp --dport 67:68 -j ACCEPT

# Allow DNS queries from LAN (will be hijacked)
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT

# Allow HTTPS for captive portal
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow HTTP redirect to HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Block all WAN forwarding (key security feature)
# This prevents any LAN to WAN traffic until onboarding complete
iptables -A FORWARD -o eth1 -j DROP
iptables -A FORWARD -o wan -j DROP

# Log dropped packets for debugging
iptables -A INPUT -j LOG --log-prefix "ONBOARD-INPUT-DROP: " --log-level 4
iptables -A FORWARD -j LOG --log-prefix "ONBOARD-FORWARD-DROP: " --log-level 4

log "Firewall rules applied successfully"
log "WAN access is BLOCKED - onboarding required"

# Save firewall rules (OpenWRT specific)
if command -v fw3 > /dev/null 2>&1; then
    fw3 reload
    log "OpenWRT firewall reloaded"
fi

# Create marker file to indicate firewall is in onboarding mode
touch /tmp/firewall-onboarding-mode
log "Firewall setup complete"

exit 0

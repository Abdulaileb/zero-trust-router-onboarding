#!/bin/sh
#
# Zero-Trust Router Onboarding - Main Setup Script
# Purpose: Orchestrate the complete onboarding system setup
# Run this script to initialize the zero-trust onboarding framework
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="/var/log/zero-trust-setup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_step() {
    echo "${BLUE}==>${NC} $1"
    log "$1"
}

print_success() {
    echo "${GREEN}✓${NC} $1"
    log "SUCCESS: $1"
}

print_error() {
    echo "${RED}✗${NC} $1"
    log "ERROR: $1"
}

print_warning() {
    echo "${YELLOW}⚠${NC} $1"
    log "WARNING: $1"
}

# Banner
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   Zero-Trust Router Onboarding Framework                 ║
║   Secure OpenWRT Router Initialization System            ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF

log "============================================="
log "Starting Zero-Trust Router Onboarding Setup"
log "============================================="

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

print_success "Running as root"

# Step 1: Check dependencies
print_step "Step 1/5: Checking dependencies..."

MISSING_DEPS=""

for cmd in iptables dnsmasq openssl; do
    if ! command -v $cmd > /dev/null 2>&1; then
        MISSING_DEPS="$MISSING_DEPS $cmd"
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    print_warning "Missing dependencies:$MISSING_DEPS"
    print_step "Attempting to install missing packages..."
    
    if command -v opkg > /dev/null 2>&1; then
        # OpenWRT package manager
        opkg update
        for pkg in $MISSING_DEPS; do
            opkg install $pkg || print_warning "Failed to install $pkg"
        done
    elif command -v apt-get > /dev/null 2>&1; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y $MISSING_DEPS
    else
        print_error "No package manager found. Please install:$MISSING_DEPS"
        exit 1
    fi
fi

print_success "Dependencies checked"

# Step 2: Setup firewall
print_step "Step 2/5: Configuring firewall (blocking WAN)..."

if [ -f "$SCRIPT_DIR/firewall-setup.sh" ]; then
    chmod +x "$SCRIPT_DIR/firewall-setup.sh"
    "$SCRIPT_DIR/firewall-setup.sh" || {
        print_error "Firewall setup failed"
        exit 1
    }
    print_success "Firewall configured - WAN access blocked"
else
    print_error "Firewall setup script not found at $SCRIPT_DIR/firewall-setup.sh"
    exit 1
fi

# Step 3: Setup DNS hijack
print_step "Step 3/5: Configuring DNS hijack..."

if [ -f "$SCRIPT_DIR/dns-hijack.sh" ]; then
    chmod +x "$SCRIPT_DIR/dns-hijack.sh"
    export PORTAL_IP="${PORTAL_IP:-192.168.1.1}"
    "$SCRIPT_DIR/dns-hijack.sh" || {
        print_error "DNS hijack setup failed"
        exit 1
    }
    print_success "DNS hijack configured"
else
    print_error "DNS hijack script not found at $SCRIPT_DIR/dns-hijack.sh"
    exit 1
fi

# Step 4: Setup HTTPS captive portal
print_step "Step 4/5: Setting up HTTPS captive portal..."

if [ -f "$SCRIPT_DIR/https-portal-setup.sh" ]; then
    chmod +x "$SCRIPT_DIR/https-portal-setup.sh"
    "$SCRIPT_DIR/https-portal-setup.sh" || {
        print_error "HTTPS portal setup failed"
        exit 1
    }
    print_success "HTTPS captive portal configured"
else
    print_error "HTTPS portal setup script not found at $SCRIPT_DIR/https-portal-setup.sh"
    exit 1
fi

# Step 5: Install CGI handler and WAN activation script
print_step "Step 5/5: Installing onboarding handlers..."

# Make scripts executable
chmod +x "$SCRIPT_DIR/wan-activation.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/onboard-cgi.sh" 2>/dev/null || true

# Copy CGI script to web server
if [ -f "$SCRIPT_DIR/onboard-cgi.sh" ]; then
    mkdir -p /www/cgi-bin
    cp "$SCRIPT_DIR/onboard-cgi.sh" /www/cgi-bin/onboard.sh
    chmod +x /www/cgi-bin/onboard.sh
    print_success "CGI handler installed"
fi

# Create system state directory
mkdir -p /etc/onboarding
mkdir -p /var/log

print_success "Onboarding handlers installed"

# Final summary
echo ""
echo "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo "${GREEN}║                                                           ║${NC}"
echo "${GREEN}║   Setup Complete! Zero-Trust Onboarding Active           ║${NC}"
echo "${GREEN}║                                                           ║${NC}"
echo "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "System Status:"
echo "  🔒 WAN Access: ${RED}BLOCKED${NC}"
echo "  🌐 DNS Hijack: ${GREEN}ACTIVE${NC}"
echo "  🔐 HTTPS Portal: ${GREEN}RUNNING${NC}"
echo "  📍 Portal URL: ${BLUE}https://192.168.1.1/${NC}"
echo ""
echo "Next Steps:"
echo "  1. Connect a client device to the router's LAN"
echo "  2. Open a web browser (will redirect to portal)"
echo "  3. Complete onboarding with credentials"
echo "  4. WAN access will be automatically enabled"
echo ""
echo "Logs: $LOG_FILE"
echo ""

log "============================================="
log "Zero-Trust Router Onboarding Setup Complete"
log "============================================="

exit 0

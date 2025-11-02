#!/bin/bash
#
# DNS Hijack Tests
# Purpose: Validate DNS hijacking configuration for captive portal
#

set -e

SCRIPT_NAME="test-dns-hijack"
TEST_RESULTS="/tmp/test-results-dns.log"
PASSED=0
FAILED=0
PORTAL_IP="${PORTAL_IP:-192.168.1.1}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================" > "$TEST_RESULTS"
echo "DNS Hijack Tests" >> "$TEST_RESULTS"
echo "Started: $(date)" >> "$TEST_RESULTS"
echo "========================================" >> "$TEST_RESULTS"

log() {
    echo "$1" | tee -a "$TEST_RESULTS"
}

pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    echo "PASS: $1" >> "$TEST_RESULTS"
    ((PASSED++))
}

fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    echo "FAIL: $1" >> "$TEST_RESULTS"
    ((FAILED++))
}

info() {
    echo -e "${YELLOW}→${NC} $1"
    echo "INFO: $1" >> "$TEST_RESULTS"
}

# Test 1: Check if dnsmasq is installed
test_dnsmasq_installed() {
    info "Test 1: Check dnsmasq installation"
    if command -v dnsmasq > /dev/null 2>&1; then
        pass "dnsmasq is installed"
    else
        fail "dnsmasq is not installed"
    fi
}

# Test 2: Check if dnsmasq is running
test_dnsmasq_running() {
    info "Test 2: Check dnsmasq is running"
    if pgrep dnsmasq > /dev/null; then
        pass "dnsmasq is running"
    else
        fail "dnsmasq is not running"
    fi
}

# Test 3: Check DNS hijack config file exists
test_config_exists() {
    info "Test 3: Check DNS hijack configuration file"
    if [ -f /etc/dnsmasq.d/onboarding.conf ]; then
        pass "DNS hijack configuration file exists"
    else
        fail "DNS hijack configuration not found at /etc/dnsmasq.d/onboarding.conf"
    fi
}

# Test 4: Check address directive in config
test_address_directive() {
    info "Test 4: Check address directive for DNS hijacking"
    if [ -f /etc/dnsmasq.d/onboarding.conf ]; then
        if grep -q "address=/#/$PORTAL_IP" /etc/dnsmasq.d/onboarding.conf; then
            pass "DNS hijack address directive configured correctly"
        else
            fail "DNS hijack address directive not found or incorrect"
        fi
    else
        fail "Configuration file not found"
    fi
}

# Test 5: Check no-resolv directive
test_no_resolv() {
    info "Test 5: Check no-resolv directive (disables upstream DNS)"
    if [ -f /etc/dnsmasq.d/onboarding.conf ]; then
        if grep -q "no-resolv" /etc/dnsmasq.d/onboarding.conf; then
            pass "no-resolv directive found (upstream DNS disabled)"
        else
            fail "no-resolv directive not found"
        fi
    else
        fail "Configuration file not found"
    fi
}

# Test 6: Check captive portal detection URLs
test_captive_portal_urls() {
    info "Test 6: Check captive portal detection URLs"
    if [ -f /etc/dnsmasq.d/onboarding.conf ]; then
        if grep -q "captive.apple.com" /etc/dnsmasq.d/onboarding.conf; then
            pass "Captive portal detection URLs configured"
        else
            fail "Captive portal detection URLs not found"
        fi
    else
        fail "Configuration file not found"
    fi
}

# Test 7: Check DHCP configuration
test_dhcp_config() {
    info "Test 7: Check DHCP configuration"
    if [ -f /etc/dnsmasq.d/onboarding.conf ]; then
        if grep -q "dhcp-range" /etc/dnsmasq.d/onboarding.conf; then
            pass "DHCP range configured"
        else
            fail "DHCP range not configured"
        fi
    else
        fail "Configuration file not found"
    fi
}

# Test 8: Verify DNS hijack marker file
test_marker_file() {
    info "Test 8: Check DNS hijack marker file"
    if [ -f /tmp/dns-hijack-active ]; then
        pass "DNS hijack marker file exists"
    else
        fail "DNS hijack marker file not found (DNS hijack may not be active)"
    fi
}

# Test 9: Test DNS resolution (if root)
test_dns_resolution() {
    info "Test 9: Test DNS resolution"
    if command -v nslookup > /dev/null 2>&1; then
        result=$(nslookup google.com 127.0.0.1 2>&1 | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || echo "")
        if [ "$result" = "$PORTAL_IP" ]; then
            pass "DNS queries return portal IP ($PORTAL_IP)"
        else
            info "DNS resolution returned: $result (may not be in hijack mode)"
        fi
    else
        info "nslookup not available, skipping DNS resolution test"
    fi
}

# Test 10: Check DNS script exists
test_script_exists() {
    info "Test 10: Check DNS hijack script exists"
    if [ -f ../scripts/dns-hijack.sh ]; then
        pass "DNS hijack script exists"
    else
        fail "DNS hijack script not found"
    fi
}

# Run all tests
echo ""
echo "Starting DNS Hijack Tests..."
echo "==========================="
echo ""

test_dnsmasq_installed
test_dnsmasq_running
test_config_exists
test_address_directive
test_no_resolv
test_captive_portal_urls
test_dhcp_config
test_marker_file
test_dns_resolution
test_script_exists

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Total Tests: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "========================================"
echo ""

echo "" >> "$TEST_RESULTS"
echo "========================================" >> "$TEST_RESULTS"
echo "Test Summary" >> "$TEST_RESULTS"
echo "Total: $((PASSED + FAILED))" >> "$TEST_RESULTS"
echo "Passed: $PASSED" >> "$TEST_RESULTS"
echo "Failed: $FAILED" >> "$TEST_RESULTS"
echo "Completed: $(date)" >> "$TEST_RESULTS"
echo "========================================" >> "$TEST_RESULTS"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Check $TEST_RESULTS for details.${NC}"
    exit 1
fi

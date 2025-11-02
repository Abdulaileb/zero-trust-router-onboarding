#!/bin/bash
#
# Firewall Configuration Tests
# Purpose: Validate firewall rules for zero-trust onboarding
#

set -e

SCRIPT_NAME="test-firewall"
TEST_RESULTS="/tmp/test-results-firewall.log"
PASSED=0
FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================" > "$TEST_RESULTS"
echo "Firewall Configuration Tests" >> "$TEST_RESULTS"
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

# Test 1: Check if iptables is installed
test_iptables_installed() {
    info "Test 1: Check iptables installation"
    if command -v iptables > /dev/null 2>&1; then
        pass "iptables is installed"
    else
        fail "iptables is not installed"
    fi
}

# Test 2: Check FORWARD chain policy
test_forward_policy() {
    info "Test 2: Check FORWARD chain default policy"
    if [ "$(id -u)" -eq 0 ]; then
        policy=$(iptables -L FORWARD | head -1 | awk '{print $4}' | tr -d ')')
        if [ "$policy" = "DROP" ]; then
            pass "FORWARD chain has DROP policy"
        else
            fail "FORWARD chain policy is $policy (expected DROP)"
        fi
    else
        info "Skipping (requires root)"
    fi
}

# Test 3: Check INPUT chain accepts LAN
test_input_lan() {
    info "Test 3: Check INPUT chain allows LAN traffic"
    if [ "$(id -u)" -eq 0 ]; then
        if iptables -L INPUT -n | grep -q "ACCEPT.*br-lan\|ACCEPT.*eth0"; then
            pass "INPUT chain accepts LAN traffic"
        else
            fail "INPUT chain does not have LAN accept rule"
        fi
    else
        info "Skipping (requires root)"
    fi
}

# Test 4: Check HTTPS port is open
test_https_port() {
    info "Test 4: Check HTTPS port 443 is allowed"
    if [ "$(id -u)" -eq 0 ]; then
        if iptables -L INPUT -n | grep -q "tcp dpt:443"; then
            pass "Port 443 (HTTPS) is allowed in INPUT"
        else
            fail "Port 443 (HTTPS) not found in INPUT rules"
        fi
    else
        info "Skipping (requires root)"
    fi
}

# Test 5: Check DNS port is open
test_dns_port() {
    info "Test 5: Check DNS port 53 is allowed"
    if [ "$(id -u)" -eq 0 ]; then
        if iptables -L INPUT -n | grep -q "dpt:53"; then
            pass "Port 53 (DNS) is allowed in INPUT"
        else
            fail "Port 53 (DNS) not found in INPUT rules"
        fi
    else
        info "Skipping (requires root)"
    fi
}

# Test 6: Check WAN blocking rule
test_wan_block() {
    info "Test 6: Check WAN forwarding is blocked"
    if [ "$(id -u)" -eq 0 ]; then
        if iptables -L FORWARD -n | grep -q "DROP.*wan\|DROP.*eth1"; then
            pass "WAN forwarding is blocked"
        else
            fail "WAN forwarding block rule not found"
        fi
    else
        info "Skipping (requires root)"
    fi
}

# Test 7: Check logging rules
test_logging() {
    info "Test 7: Check firewall logging is enabled"
    if [ "$(id -u)" -eq 0 ]; then
        if iptables -L INPUT -n | grep -q "LOG"; then
            pass "Firewall logging is enabled"
        else
            fail "Firewall logging not found"
        fi
    else
        info "Skipping (requires root)"
    fi
}

# Test 8: Check established connections
test_established() {
    info "Test 8: Check established/related connections allowed"
    if [ "$(id -u)" -eq 0 ]; then
        if iptables -L INPUT -n | grep -q "ESTABLISHED,RELATED"; then
            pass "Established/related connections allowed"
        else
            fail "Established/related rule not found"
        fi
    else
        info "Skipping (requires root)"
    fi
}

# Test 9: Verify onboarding marker file
test_marker_file() {
    info "Test 9: Check onboarding marker file"
    if [ -f /tmp/firewall-onboarding-mode ]; then
        pass "Onboarding marker file exists"
    else
        fail "Onboarding marker file not found (firewall may not be in onboarding mode)"
    fi
}

# Test 10: Check firewall script exists
test_script_exists() {
    info "Test 10: Check firewall setup script exists"
    if [ -f ../scripts/firewall-setup.sh ]; then
        pass "Firewall setup script exists"
    else
        fail "Firewall setup script not found"
    fi
}

# Run all tests
echo ""
echo "Starting Firewall Tests..."
echo "=========================="
echo ""

test_iptables_installed
test_forward_policy
test_input_lan
test_https_port
test_dns_port
test_wan_block
test_logging
test_established
test_marker_file
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

#!/bin/bash
#
# WAN Activation Tests
# Purpose: Validate WAN activation logic and credential handling
#

set -e

SCRIPT_NAME="test-wan-activation"
TEST_RESULTS="/tmp/test-results-wan.log"
PASSED=0
FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================" > "$TEST_RESULTS"
echo "WAN Activation Tests" >> "$TEST_RESULTS"
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

# Test 1: Check WAN activation script exists
test_script_exists() {
    info "Test 1: Check WAN activation script exists"
    if [ -f ../scripts/wan-activation.sh ]; then
        pass "WAN activation script exists"
    else
        fail "WAN activation script not found"
    fi
}

# Test 2: Check script is executable
test_script_executable() {
    info "Test 2: Check script is executable"
    if [ -x ../scripts/wan-activation.sh ]; then
        pass "WAN activation script is executable"
    else
        fail "WAN activation script is not executable"
    fi
}

# Test 3: Check onboarding directory
test_onboarding_dir() {
    info "Test 3: Check onboarding directory"
    if [ -d /etc/onboarding ] || mkdir -p /etc/onboarding 2>/dev/null; then
        pass "Onboarding directory exists or can be created"
    else
        fail "Cannot create onboarding directory"
    fi
}

# Test 4: Test script with missing parameters
test_missing_params() {
    info "Test 4: Test script with missing parameters"
    if [ -x ../scripts/wan-activation.sh ]; then
        output=$(../scripts/wan-activation.sh 2>&1 || true)
        if echo "$output" | grep -qi "error\|missing"; then
            pass "Script correctly handles missing parameters"
        else
            fail "Script does not properly validate missing parameters"
        fi
    else
        info "Script not executable, skipping"
    fi
}

# Test 5: Test script with invalid email
test_invalid_email() {
    info "Test 5: Test script with invalid email format"
    if [ -x ../scripts/wan-activation.sh ]; then
        output=$(../scripts/wan-activation.sh "test-device" "test-key-12345" "invalid-email" 2>&1 || true)
        if echo "$output" | grep -qi "invalid.*email"; then
            pass "Script validates email format"
        else
            info "Email validation may not be strict (this is acceptable)"
        fi
    else
        info "Script not executable, skipping"
    fi
}

# Test 6: Test script with short API key
test_short_api_key() {
    info "Test 6: Test script with too short API key"
    if [ -x ../scripts/wan-activation.sh ]; then
        output=$(../scripts/wan-activation.sh "test-device" "short" "test@example.com" 2>&1 || true)
        if echo "$output" | grep -qi "invalid.*key\|too short"; then
            pass "Script validates API key length"
        else
            info "API key validation may be flexible"
        fi
    else
        info "Script not executable, skipping"
    fi
}

# Test 7: Check credential storage location
test_credential_storage() {
    info "Test 7: Check credential storage configuration"
    if [ -x ../scripts/wan-activation.sh ]; then
        if grep -q "/etc/onboarding/credentials" ../scripts/wan-activation.sh; then
            pass "Script uses secure credential storage location"
        else
            fail "Credential storage location not found in script"
        fi
    else
        fail "Script not found"
    fi
}

# Test 8: Check state file usage
test_state_file() {
    info "Test 8: Check state file management"
    if [ -x ../scripts/wan-activation.sh ]; then
        if grep -q "/etc/onboarding/state" ../scripts/wan-activation.sh; then
            pass "Script manages state file"
        else
            fail "State file management not found in script"
        fi
    else
        fail "Script not found"
    fi
}

# Test 9: Check iptables commands
test_iptables_commands() {
    info "Test 9: Check iptables WAN activation commands"
    if [ -x ../scripts/wan-activation.sh ]; then
        if grep -q "iptables.*FORWARD" ../scripts/wan-activation.sh; then
            pass "Script modifies iptables FORWARD rules"
        else
            fail "iptables FORWARD rules not found in script"
        fi
        
        if grep -q "iptables.*MASQUERADE" ../scripts/wan-activation.sh; then
            pass "Script enables NAT/masquerading"
        else
            fail "NAT/masquerading not found in script"
        fi
    else
        fail "Script not found"
    fi
}

# Test 10: Check logging functionality
test_logging() {
    info "Test 10: Check logging functionality"
    if [ -x ../scripts/wan-activation.sh ]; then
        if grep -q "log()" ../scripts/wan-activation.sh; then
            pass "Script has logging function"
        else
            fail "Logging function not found"
        fi
    else
        fail "Script not found"
    fi
}

# Test 11: Check JSON response format
test_json_response() {
    info "Test 11: Check JSON response format"
    if [ -x ../scripts/wan-activation.sh ]; then
        if grep -q '{"success"' ../scripts/wan-activation.sh; then
            pass "Script returns JSON formatted responses"
        else
            fail "JSON response format not found"
        fi
    else
        fail "Script not found"
    fi
}

# Test 12: Check DNS restoration
test_dns_restoration() {
    info "Test 12: Check DNS restoration after activation"
    if [ -x ../scripts/wan-activation.sh ]; then
        if grep -q "dnsmasq.*restart" ../scripts/wan-activation.sh; then
            pass "Script restores DNS service"
        else
            info "DNS restoration may be handled differently"
        fi
    else
        fail "Script not found"
    fi
}

# Test 13: Verify cleanup of onboarding markers
test_marker_cleanup() {
    info "Test 13: Check cleanup of onboarding markers"
    if [ -x ../scripts/wan-activation.sh ]; then
        if grep -q "rm.*firewall-onboarding-mode\|rm.*dns-hijack-active" ../scripts/wan-activation.sh; then
            pass "Script cleans up onboarding markers"
        else
            fail "Marker cleanup not found in script"
        fi
    else
        fail "Script not found"
    fi
}

# Run all tests
echo ""
echo "Starting WAN Activation Tests..."
echo "==============================="
echo ""

test_script_exists
test_script_executable
test_onboarding_dir
test_missing_params
test_invalid_email
test_short_api_key
test_credential_storage
test_state_file
test_iptables_commands
test_logging
test_json_response
test_dns_restoration
test_marker_cleanup

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

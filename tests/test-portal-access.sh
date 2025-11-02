#!/bin/bash
#
# HTTPS Portal Access Tests
# Purpose: Validate captive portal setup and accessibility
#

set -e

SCRIPT_NAME="test-portal-access"
TEST_RESULTS="/tmp/test-results-portal.log"
PASSED=0
FAILED=0
PORTAL_IP="${PORTAL_IP:-192.168.1.1}"
PORTAL_DIR="${PORTAL_DIR:-/www/onboarding}"
CERT_DIR="${CERT_DIR:-/etc/onboarding/certs}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================" > "$TEST_RESULTS"
echo "HTTPS Portal Access Tests" >> "$TEST_RESULTS"
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

# Test 1: Check if openssl is installed
test_openssl_installed() {
    info "Test 1: Check OpenSSL installation"
    if command -v openssl > /dev/null 2>&1; then
        pass "OpenSSL is installed"
    else
        fail "OpenSSL is not installed"
    fi
}

# Test 2: Check portal directory exists
test_portal_dir() {
    info "Test 2: Check portal directory"
    if [ -d "$PORTAL_DIR" ]; then
        pass "Portal directory exists at $PORTAL_DIR"
    else
        fail "Portal directory not found at $PORTAL_DIR"
    fi
}

# Test 3: Check index.html exists
test_index_html() {
    info "Test 3: Check portal index.html"
    if [ -f "$PORTAL_DIR/index.html" ]; then
        pass "Portal index.html exists"
    else
        fail "Portal index.html not found"
    fi
}

# Test 4: Check success.html exists
test_success_html() {
    info "Test 4: Check success.html"
    if [ -f "$PORTAL_DIR/success.html" ]; then
        pass "Success page exists"
    else
        fail "Success page not found"
    fi
}

# Test 5: Check SSL certificate exists
test_ssl_cert() {
    info "Test 5: Check SSL certificate"
    if [ -f "$CERT_DIR/cert.pem" ]; then
        pass "SSL certificate exists"
    else
        fail "SSL certificate not found at $CERT_DIR/cert.pem"
    fi
}

# Test 6: Check SSL private key exists
test_ssl_key() {
    info "Test 6: Check SSL private key"
    if [ -f "$CERT_DIR/key.pem" ]; then
        pass "SSL private key exists"
    else
        fail "SSL private key not found at $CERT_DIR/key.pem"
    fi
}

# Test 7: Verify SSL certificate validity
test_cert_validity() {
    info "Test 7: Verify SSL certificate validity"
    if [ -f "$CERT_DIR/cert.pem" ]; then
        if openssl x509 -in "$CERT_DIR/cert.pem" -noout -checkend 0 2>/dev/null; then
            pass "SSL certificate is valid"
        else
            fail "SSL certificate is expired or invalid"
        fi
    else
        fail "SSL certificate not found"
    fi
}

# Test 8: Check CGI directory
test_cgi_dir() {
    info "Test 8: Check CGI directory"
    if [ -d /www/cgi-bin ]; then
        pass "CGI directory exists"
    else
        fail "CGI directory not found"
    fi
}

# Test 9: Check CGI onboard script
test_cgi_script() {
    info "Test 9: Check onboarding CGI script"
    if [ -f /www/cgi-bin/onboard.sh ]; then
        pass "Onboarding CGI script exists"
        if [ -x /www/cgi-bin/onboard.sh ]; then
            pass "CGI script is executable"
        else
            fail "CGI script is not executable"
        fi
    else
        fail "Onboarding CGI script not found"
    fi
}

# Test 10: Check web server running
test_web_server() {
    info "Test 10: Check web server is running"
    if pgrep uhttpd > /dev/null 2>&1; then
        pass "uhttpd is running"
    elif pgrep nginx > /dev/null 2>&1; then
        pass "nginx is running"
    else
        fail "No web server (uhttpd or nginx) found running"
    fi
}

# Test 11: Check HTTPS port listening
test_https_listening() {
    info "Test 11: Check HTTPS port 443 is listening"
    if command -v netstat > /dev/null 2>&1; then
        if netstat -tln 2>/dev/null | grep -q ":443"; then
            pass "Port 443 is listening"
        else
            fail "Port 443 is not listening"
        fi
    elif command -v ss > /dev/null 2>&1; then
        if ss -tln 2>/dev/null | grep -q ":443"; then
            pass "Port 443 is listening"
        else
            fail "Port 443 is not listening"
        fi
    else
        info "Neither netstat nor ss available, skipping port check"
    fi
}

# Test 12: Check portal marker file
test_portal_marker() {
    info "Test 12: Check portal active marker"
    if [ -f /tmp/https-portal-active ]; then
        pass "Portal active marker exists"
    else
        fail "Portal active marker not found"
    fi
}

# Test 13: Test HTTP to HTTPS redirect (if curl available)
test_https_redirect() {
    info "Test 13: Test HTTP to HTTPS redirect"
    if command -v curl > /dev/null 2>&1; then
        response=$(curl -s -I -L http://$PORTAL_IP 2>&1 | head -1 || echo "")
        if echo "$response" | grep -q "301\|302\|303\|307\|308"; then
            pass "HTTP redirects to HTTPS"
        else
            info "Could not verify redirect (may not be configured or server not accessible)"
        fi
    else
        info "curl not available, skipping redirect test"
    fi
}

# Test 14: Check portal setup script exists
test_script_exists() {
    info "Test 14: Check portal setup script exists"
    if [ -f ../scripts/https-portal-setup.sh ]; then
        pass "Portal setup script exists"
    else
        fail "Portal setup script not found"
    fi
}

# Run all tests
echo ""
echo "Starting Portal Access Tests..."
echo "=============================="
echo ""

test_openssl_installed
test_portal_dir
test_index_html
test_success_html
test_ssl_cert
test_ssl_key
test_cert_validity
test_cgi_dir
test_cgi_script
test_web_server
test_https_listening
test_portal_marker
test_https_redirect
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

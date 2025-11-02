# Security Considerations

## Overview

This document outlines the security design, threat model, and best practices for the Zero-Trust Router Onboarding Framework.

## Threat Model

### Assets

1. **Router Configuration:** Device settings and firmware
2. **Network Access:** WAN/Internet connectivity
3. **Credentials:** API keys, device IDs, user emails
4. **Network Traffic:** LAN and WAN data flows

### Adversaries

1. **Unauthorized Users:** Attempting to access internet without onboarding
2. **Network Attackers:** MITM, DNS spoofing, packet injection
3. **Malicious Insiders:** Users with physical LAN access
4. **Remote Attackers:** Attempting to exploit web services

### Attack Vectors

#### 1. Bypassing WAN Block

**Attack:** Directly accessing WAN interface
- **Mitigation:** iptables DROP policy on FORWARD chain
- **Detection:** Firewall logs all blocked packets

**Attack:** MAC spoofing to appear as router
- **Mitigation:** Layer 2 isolation, proper routing tables
- **Detection:** ARP monitoring (future enhancement)

#### 2. Credential Attacks

**Attack:** Brute force API keys
- **Mitigation:** Rate limiting (recommended), account lockout
- **Detection:** Failed attempt logging
- **Status:** ⚠️ Not implemented in prototype

**Attack:** Credential interception (MITM)
- **Mitigation:** HTTPS/TLS encryption
- **Detection:** Certificate validation
- **Status:** ✅ Implemented

**Attack:** XSS/CSRF on portal
- **Mitigation:** Input validation, CSP headers
- **Detection:** WAF logs (future)
- **Status:** ⚠️ Basic validation only

#### 3. DNS Attacks

**Attack:** DNS cache poisoning
- **Mitigation:** No external DNS during onboarding
- **Detection:** All queries logged
- **Status:** ✅ Implemented

**Attack:** DNS tunneling for data exfiltration
- **Mitigation:** DNS hijack blocks external resolution
- **Detection:** Query pattern analysis (future)
- **Status:** ✅ Partially protected

#### 4. Physical Access

**Attack:** Console/serial access to router
- **Mitigation:** Password protection, secure boot
- **Detection:** Physical tamper detection
- **Status:** ⚠️ Out of scope for prototype

**Attack:** Firmware modification
- **Mitigation:** Verified boot, signed updates
- **Detection:** Integrity checking
- **Status:** ⚠️ Out of scope for prototype

## Security Features

### 1. Network Isolation

**Implementation:**
```bash
# Default deny everything
iptables -P FORWARD DROP

# Explicit WAN block
iptables -A FORWARD -o wan -j DROP
```

**Benefits:**
- Zero-trust default stance
- Fail-secure design
- Clear security boundary

**Limitations:**
- No protection against physical bypass
- Relies on correct interface identification

### 2. TLS/HTTPS Encryption

**Implementation:**
```bash
# 4096-bit RSA key
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout key.pem -out cert.pem -days 365
```

**Benefits:**
- Encrypts credential transmission
- Prevents passive eavesdropping
- Industry-standard security

**Limitations:**
- Self-signed cert triggers browser warnings
- No certificate pinning
- No HSTS enforcement

### 3. DNS Security

**Implementation:**
```
# Disable upstream resolvers
no-resolv
no-poll

# Answer all queries locally
address=/#/192.168.1.1
```

**Benefits:**
- Prevents DNS leaks
- Forces portal access
- Blocks DNS tunneling

**Limitations:**
- No DNSSEC validation
- No DoH/DoT support
- Single point of failure

### 4. Credential Storage

**Implementation:**
```bash
# Base64 encoding (placeholder)
echo "$API_KEY" | base64 > /etc/onboarding/credentials.enc
chmod 600 /etc/onboarding/credentials.enc
```

**Benefits:**
- Restricted file permissions
- Not stored in plaintext
- Separated from application code

**Limitations:**
- ⚠️ Base64 is NOT encryption
- No hardware security module (HSM)
- Keys stored on disk

### 5. Logging and Auditing

**Implementation:**
```bash
# Log all firewall drops
iptables -A INPUT -j LOG --log-prefix "ONBOARD-DROP: "

# Application logging
log() {
    echo "[$(date)] $1" | tee -a "$LOG_FILE"
}
```

**Benefits:**
- Complete audit trail
- Forensic analysis capability
- Debugging support

**Limitations:**
- No log rotation
- No centralized logging
- No real-time alerting

## Known Vulnerabilities

### 1. Self-Signed Certificates

**Issue:** Browser security warnings may train users to ignore certificate errors

**Severity:** Medium

**Mitigation:**
- Use Let's Encrypt for production
- Implement certificate pinning
- Add warning in documentation

### 2. Basic Credential Validation

**Issue:** No server-side API verification in prototype

**Severity:** Medium

**Mitigation:**
- Add API integration in production
- Implement proper authentication backend
- Use OAuth/SAML for enterprise

### 3. No Rate Limiting

**Issue:** Brute force attacks not prevented

**Severity:** Medium

**Mitigation:**
```bash
# Add to firewall
iptables -A INPUT -p tcp --dport 443 \
  -m limit --limit 10/min -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j DROP
```

### 4. Base64 Credential Storage

**Issue:** Not actual encryption, easily reversible

**Severity:** High

**Mitigation:**
```bash
# Use GPG encryption
echo "$API_KEY" | gpg --encrypt --recipient router@local \
  > /etc/onboarding/credentials.gpg

# Or use age
echo "$API_KEY" | age -r age1xxx... \
  > /etc/onboarding/credentials.age
```

### 5. No Input Sanitization

**Issue:** Potential XSS/command injection

**Severity:** High

**Mitigation:**
```bash
# Sanitize inputs
DEVICE_ID=$(echo "$DEVICE_ID" | sed 's/[^a-zA-Z0-9._-]//g')
API_KEY=$(echo "$API_KEY" | sed 's/[^a-zA-Z0-9._-]//g')
```

## Production Security Checklist

### Before Deployment

- [ ] Replace self-signed certificates with CA-signed
- [ ] Implement proper credential encryption (GPG/age/HSM)
- [ ] Add input validation and sanitization
- [ ] Enable rate limiting on all endpoints
- [ ] Set up centralized logging
- [ ] Configure log rotation
- [ ] Add intrusion detection (fail2ban)
- [ ] Enable security headers (CSP, HSTS, X-Frame-Options)
- [ ] Implement session management
- [ ] Add CSRF protection
- [ ] Configure automated backups
- [ ] Set up monitoring and alerting
- [ ] Perform security audit
- [ ] Conduct penetration testing
- [ ] Review and update dependencies

### Network Security

- [ ] Configure VLANs for isolation
- [ ] Enable MAC address filtering (optional)
- [ ] Set up 802.1X authentication (enterprise)
- [ ] Configure IPv6 security
- [ ] Enable WPA3 for WiFi
- [ ] Disable WPS and UPnP
- [ ] Set up IDS/IPS
- [ ] Configure DDoS protection

### Access Control

- [ ] Change default passwords
- [ ] Disable root SSH login
- [ ] Use key-based SSH authentication
- [ ] Implement role-based access control
- [ ] Set up multi-factor authentication
- [ ] Configure session timeouts
- [ ] Enable account lockout policies
- [ ] Audit user permissions

### Compliance

- [ ] GDPR compliance (if applicable)
- [ ] Data retention policies
- [ ] Privacy policy implementation
- [ ] Security incident response plan
- [ ] Regular security updates
- [ ] Vulnerability disclosure program

## Security Best Practices

### 1. Defense in Depth

Implement multiple security layers:
```
Layer 1: Physical Security (tamper detection)
Layer 2: Network Security (firewall, isolation)
Layer 3: Application Security (input validation)
Layer 4: Data Security (encryption at rest/transit)
Layer 5: Monitoring (logging, alerting)
```

### 2. Principle of Least Privilege

- Run services with minimal permissions
- Use dedicated users for services
- Restrict file system access
- Limit network capabilities

### 3. Fail Secure

- Default deny firewall rules
- Explicit allow rules only
- Automatic rollback on errors
- Safe failure modes

### 4. Security Updates

```bash
# Regular update schedule
opkg update && opkg upgrade

# Automated security patches
echo "0 3 * * * /usr/bin/security-update.sh" >> /etc/crontabs/root
```

### 5. Monitoring

```bash
# Real-time monitoring
tail -f /var/log/wan-activation.log | \
  grep -i "error\|fail\|invalid"

# Alerting
if grep -q "FAIL" /var/log/wan-activation.log; then
    send_alert "Onboarding failure detected"
fi
```

## Secure Development

### Code Review Checklist

- [ ] No hardcoded credentials
- [ ] Input validation on all user inputs
- [ ] Output encoding to prevent XSS
- [ ] SQL parameterization (if using database)
- [ ] Secure random number generation
- [ ] Proper error handling (no info leaks)
- [ ] Security headers implemented
- [ ] Dependencies up to date
- [ ] No sensitive data in logs
- [ ] Proper session management

### Testing

```bash
# Security testing
./tests/test-firewall.sh        # Firewall rules
./tests/test-xss.sh             # XSS vulnerabilities
./tests/test-injection.sh       # Injection attacks
./tests/test-authentication.sh  # Auth bypass

# Fuzzing
./tests/fuzz-inputs.sh          # Input fuzzing
```

## Incident Response

### Detection

Monitor for:
- Failed onboarding attempts
- Unusual network patterns
- Firewall rule changes
- Certificate errors
- Service crashes

### Response Plan

1. **Identify:** Confirm security incident
2. **Contain:** Isolate affected systems
3. **Eradicate:** Remove threat
4. **Recover:** Restore normal operation
5. **Learn:** Update security measures

### Emergency Procedures

```bash
# Emergency WAN block
iptables -I FORWARD 1 -j DROP

# Emergency shutdown
/etc/init.d/uhttpd stop
/etc/init.d/dnsmasq stop

# Factory reset
firstboot -y && reboot
```

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [OpenWRT Security](https://openwrt.org/docs/guide-user/security/start)
- [Zero Trust Architecture](https://www.nist.gov/publications/zero-trust-architecture)

## Contact

For security issues, please contact:
- Security Team: security@example.com
- PGP Key: [Key ID]
- Bug Bounty: [Program Link]

**Do not** disclose security vulnerabilities publicly before coordinated disclosure.

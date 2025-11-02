# System Architecture

## Overview

The Zero-Trust Router Onboarding Framework uses a layered security architecture to ensure that consumer routers cannot access the internet until they have been properly onboarded with valid credentials.

## Component Architecture

### 1. Network Layer

```
┌─────────────────────────────────────────────────┐
│              Internet (WAN)                     │
│                    ↑                            │
│                    │ BLOCKED                    │
│                    │ (until activated)          │
└────────────────────┼─────────────────────────────┘
                     │
                ┌────┴────┐
                │   WAN   │
                │Interface│
                └────┬────┘
                     │
         ┌───────────┴───────────┐
         │      Router/VM        │
         │   ┌─────────────┐     │
         │   │  Firewall   │     │
         │   │  (iptables) │     │
         │   └─────────────┘     │
         │   ┌─────────────┐     │
         │   │   dnsmasq   │     │
         │   │ (DNS/DHCP)  │     │
         │   └─────────────┘     │
         │   ┌─────────────┐     │
         │   │ Web Server  │     │
         │   │(uhttpd/nginx)│    │
         │   └─────────────┘     │
         └───────────┬───────────┘
                     │
                ┌────┴────┐
                │   LAN   │
                │Interface│
                └────┬────┘
                     │
         ┌───────────┴───────────┐
         │    Client Devices     │
         │  (Laptop, Phone, etc) │
         └───────────────────────┘
```

### 2. Security Flow

```
┌──────────────┐
│ Router Boots │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ Firewall Setup       │
│ - Block WAN Forward  │
│ - Allow LAN Access   │
│ - Log All Traffic    │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ DNS Hijack Active    │
│ - All DNS → Portal   │
│ - Captive Detection  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ HTTPS Portal Running │
│ - Self-Signed Cert   │
│ - Credential Form    │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ User Connects LAN    │
│ - Gets DHCP Lease    │
│ - DNS Points to      │
│   Portal             │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Browser Opens        │
│ - Redirected to      │
│   Portal             │
│ - Shows Form         │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Credentials Submitted│
│ - Device ID          │
│ - API Key            │
│ - Owner Email        │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Validation           │
│ - Format Check       │
│ - Length Validation  │
│ - Optional API Call  │
└──────┬───────────────┘
       │
       ├─── Invalid ───┐
       │               ▼
       │         ┌─────────────┐
       │         │ Show Error  │
       │         └─────────────┘
       │
       └─── Valid ────▼
┌──────────────────────┐
│ WAN Activation       │
│ - Remove WAN Block   │
│ - Enable NAT         │
│ - Restore DNS        │
│ - Save State         │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Internet Enabled     │
│ - Full WAN Access    │
│ - Normal Routing     │
└──────────────────────┘
```

### 3. Data Flow

#### DNS Query Flow (During Onboarding)

```
Client Device          dnsmasq              Portal
     │                    │                    │
     │─── DNS Query ─────>│                    │
     │   (google.com)     │                    │
     │                    │                    │
     │<── DNS Response ───│                    │
     │   (192.168.1.1)    │                    │
     │                    │                    │
     │──── HTTP Request ──┼───────────────────>│
     │   (http://google)  │                    │
     │                    │                    │
     │<─── 301 Redirect ──┼────────────────────│
     │   (https://...)    │                    │
     │                    │                    │
     │──── HTTPS Request ─┼───────────────────>│
     │   (portal page)    │                    │
     │                    │                    │
     │<─── Portal HTML ───┼────────────────────│
     │                    │                    │
```

#### Credential Submission Flow

```
Browser              Web Server        CGI Script      Activation Script
   │                     │                 │                  │
   │─── POST /cgi-bin/onboard.sh ────────>│                  │
   │   (credentials)     │                 │                  │
   │                     │                 │                  │
   │                     │<── Parse POST ──│                  │
   │                     │                 │                  │
   │                     │                 │─── Validate ────>│
   │                     │                 │   credentials    │
   │                     │                 │                  │
   │                     │                 │<── Update FW ────│
   │                     │                 │   (iptables)     │
   │                     │                 │                  │
   │                     │                 │<── Save State ───│
   │                     │                 │                  │
   │                     │<── JSON Response│                  │
   │                     │   {"success"}   │                  │
   │                     │                 │                  │
   │<─── JSON ───────────│                 │                  │
   │   {"success":true}  │                 │                  │
   │                     │                 │                  │
```

## Component Details

### Firewall (iptables)

**Purpose:** Enforce network isolation

**Configuration:**
- Default DROP policy on FORWARD chain
- Allow LAN to Router communication
- Block all WAN forwarding
- Allow established/related connections

**Critical Rules:**
```bash
iptables -A FORWARD -o wan -j DROP        # Block WAN
iptables -A INPUT -i br-lan -j ACCEPT    # Allow LAN
iptables -A INPUT -p tcp --dport 443 -j ACCEPT  # HTTPS
```

### DNS Hijacking (dnsmasq)

**Purpose:** Redirect all DNS queries to captive portal

**Configuration:**
- Disable upstream DNS resolvers
- Return portal IP for all queries
- Support captive portal detection URLs
- Provide DHCP services

**Key Settings:**
```
address=/#/192.168.1.1
no-resolv
dhcp-range=192.168.1.50,192.168.1.200,12h
```

### HTTPS Portal (uhttpd/nginx)

**Purpose:** Serve credential collection interface

**Features:**
- Self-signed SSL certificate
- Responsive web interface
- CGI script execution
- HTTP to HTTPS redirect

**Endpoints:**
- `/` - Main portal page
- `/cgi-bin/onboard.sh` - Form handler
- `/success.html` - Post-activation page

### WAN Activation Script

**Purpose:** Enable internet access after validation

**Actions:**
1. Validate credentials
2. Remove WAN blocking rules
3. Enable NAT/masquerading
4. Restore normal DNS
5. Save activation state
6. Log the event

## Security Features

### Defense in Depth

1. **Network Layer:** Firewall blocks WAN by default
2. **Application Layer:** Portal requires valid credentials
3. **Transport Layer:** TLS encrypts credential transmission
4. **Data Layer:** Credentials stored encrypted

### Logging and Auditing

All components log to `/var/log/`:
- `firewall-setup.log` - Firewall changes
- `dns-hijack.log` - DNS operations
- `https-portal-setup.log` - Portal events
- `wan-activation.log` - Activation attempts

### State Management

System state tracked in:
- `/tmp/firewall-onboarding-mode` - Marker for onboarding mode
- `/tmp/dns-hijack-active` - DNS hijack status
- `/etc/onboarding/state` - Activation state
- `/etc/onboarding/credentials.enc` - Encrypted credentials

## Extension Points

### Custom Credential Validation

Modify `wan-activation.sh` to add:
```bash
# API verification
response=$(curl -X POST "$API_ENDPOINT/verify" \
  -d "device_id=$DEVICE_ID" \
  -d "api_key=$API_KEY")
```

### Additional Security Checks

Add to firewall setup:
```bash
# Rate limiting
iptables -A INPUT -p tcp --dport 443 \
  -m limit --limit 10/min -j ACCEPT
```

### Monitoring Integration

Add to activation script:
```bash
# Send metrics
echo "onboarding.activated device_id=$DEVICE_ID" | \
  nc metrics-server 8125
```

## Performance Considerations

### Resource Usage

- **CPU:** Minimal (< 5% on typical router)
- **Memory:** ~10MB for web server + scripts
- **Storage:** ~5MB for scripts and certificates
- **Network:** No overhead after activation

### Scalability

- Single router: Handles ~50 concurrent clients
- Multiple simultaneous onboardings: Not recommended
- Portal timeout: 1 hour default

## Testing Architecture

### Test Environments

1. **QEMU VM:** Full OpenWRT environment
2. **Docker Container:** Isolated testing
3. **Physical Router:** Production validation

### Test Coverage

- Unit tests: Individual script validation
- Integration tests: End-to-end flow
- Security tests: Penetration testing
- Performance tests: Load testing

## Future Enhancements

1. **OAuth/SAML Integration:** Enterprise SSO
2. **Certificate Pinning:** Enhanced HTTPS security
3. **Rate Limiting:** DDoS protection
4. **Automated Rollback:** Recovery from errors
5. **Cloud Management:** Centralized monitoring
6. **IPv6 Support:** Dual-stack networking

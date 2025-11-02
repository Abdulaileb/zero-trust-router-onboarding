# Zero-Trust Router Onboarding Framework

A secure, research-driven prototype for zero-trust onboarding of consumer routers using OpenWRT, QEMU, and Linux networking technologies.

## Overview

This framework implements a security-first approach to router initialization that:
- **Blocks WAN access by default** until onboarding is complete
- **Redirects all LAN clients** to a TLS-enabled captive portal
- **Requires credential injection** before activating internet access
- **Uses HTTPS/TLS** for all sensitive communications
- **Follows zero-trust principles** throughout the onboarding process

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Zero-Trust Router                       │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │   Firewall   │  │  DNS Hijack  │  │  HTTPS Portal   │  │
│  │              │  │              │  │                 │  │
│  │ WAN: BLOCKED │→→│ → Portal IP  │→→│  Credential     │  │
│  │ LAN: ALLOW   │  │   (dnsmasq)  │  │  Injection      │  │
│  └──────────────┘  └──────────────┘  └─────────────────┘  │
│                                              ↓              │
│                                    ┌─────────────────┐     │
│                                    │ WAN Activation  │     │
│                                    │   (iptables)    │     │
│                                    └─────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## Features

### 🔒 Security First
- Default-deny firewall rules
- WAN interface blocked until onboarding
- TLS/HTTPS for credential submission
- Self-signed certificates with 4096-bit RSA keys
- Encrypted credential storage
- Logging of all onboarding attempts

### 🌐 Network Isolation
- Complete WAN isolation during onboarding
- LAN-only access to captive portal
- DNS hijacking to force portal access
- Support for captive portal detection (iOS, Android, Windows, Firefox)

### 🎯 User Experience
- Modern, responsive web interface
- Mobile-friendly design
- Clear status indicators
- Automatic redirect to internet after activation
- Support for major platforms' captive portal detection

### ⚙️ Flexibility
- Compatible with OpenWRT
- Works with QEMU for testing
- Configurable network interfaces
- Support for uhttpd and nginx web servers
- Extensible credential verification

## Installation

### Prerequisites

**Required:**
- OpenWRT router or QEMU VM
- Linux kernel with iptables/nftables
- dnsmasq (DNS/DHCP server)
- openssl
- Web server (uhttpd or nginx)

**Optional:**
- opkg (OpenWRT package manager)
- fcgiwrap (for nginx CGI support)

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Abdulaileb/zero-trust-router-onboarding.git
   cd zero-trust-router-onboarding
   ```

2. **Run the setup script:**
   ```bash
   cd scripts
   sudo ./setup.sh
   ```

3. **Connect to the router and complete onboarding:**
   - Connect a device to the router's LAN
   - Open any website in a browser
   - You'll be redirected to `https://192.168.1.1/`
   - Enter credentials to activate WAN access

### Manual Installation

If you prefer to set up components individually:

```bash
# 1. Configure firewall
sudo ./scripts/firewall-setup.sh

# 2. Setup DNS hijacking
sudo ./scripts/dns-hijack.sh

# 3. Configure HTTPS portal
sudo ./scripts/https-portal-setup.sh

# 4. Install CGI handler
sudo cp scripts/onboard-cgi.sh /www/cgi-bin/onboard.sh
sudo chmod +x /www/cgi-bin/onboard.sh
```

## Configuration

Edit `/etc/onboarding/config` or `configs/onboarding.conf`:

```bash
# Portal IP address
PORTAL_IP=192.168.1.1

# Network interfaces
LAN_INTERFACE=br-lan
WAN_INTERFACE=wan

# Security settings
CERT_VALIDITY_DAYS=365
REQUIRE_MIN_KEY_LENGTH=8

# Feature flags
ENABLE_EMAIL_VALIDATION=true
```

## Usage

### For End Users

1. Connect your device to the router's WiFi or LAN port
2. Open a web browser and navigate to any website
3. You'll be automatically redirected to the onboarding portal
4. Fill in the required credentials:
   - Device ID
   - API Key
   - Owner Email
5. Click "Activate Router"
6. Wait for confirmation
7. Internet access is now enabled!

### For Administrators

**Check onboarding status:**
```bash
cat /etc/onboarding/state
```

**View logs:**
```bash
tail -f /var/log/zero-trust-setup.log
tail -f /var/log/firewall-setup.log
tail -f /var/log/dns-hijack.log
```

**Manually activate WAN:**
```bash
./scripts/wan-activation.sh "device-123" "api-key-xyz" "user@example.com"
```

**Reset to onboarding mode:**
```bash
./scripts/firewall-setup.sh
./scripts/dns-hijack.sh
```

## Testing with QEMU

### Setup QEMU OpenWRT VM

1. **Download OpenWRT image:**
   ```bash
   wget https://downloads.openwrt.org/releases/21.02.0/targets/x86/64/openwrt-21.02.0-x86-64-generic-ext4-combined.img.gz
   gunzip openwrt-21.02.0-x86-64-generic-ext4-combined.img.gz
   ```

2. **Start QEMU VM:**
   ```bash
   qemu-system-x86_64 \
     -enable-kvm \
     -M q35 \
     -m 256 \
     -nographic \
     -drive file=openwrt.img,format=raw \
     -netdev user,id=wan,hostfwd=tcp::8080-:80,hostfwd=tcp::8443-:443 \
     -device e1000,netdev=wan \
     -netdev tap,id=lan,ifname=tap0,script=no,downscript=no \
     -device e1000,netdev=lan
   ```

3. **Access the VM:**
   - Console: Direct QEMU output
   - SSH: `ssh root@localhost -p 22`
   - Portal: `https://localhost:8443/`

### Run Tests

```bash
cd tests
sudo ./test-firewall.sh
sudo ./test-dns-hijack.sh
sudo ./test-portal-access.sh
sudo ./test-wan-activation.sh
```

## Project Structure

```
zero-trust-router-onboarding/
├── README.md                      # This file
├── LICENSE                        # Project license
├── scripts/                       # Implementation scripts
│   ├── setup.sh                  # Main orchestration script
│   ├── firewall-setup.sh         # Firewall configuration
│   ├── dns-hijack.sh             # DNS hijacking setup
│   ├── https-portal-setup.sh     # HTTPS captive portal
│   ├── wan-activation.sh         # WAN activation logic
│   └── onboard-cgi.sh           # CGI handler for form
├── configs/                       # Configuration files
│   ├── network.conf              # Network interface config
│   └── onboarding.conf           # Onboarding settings
├── docs/                          # Documentation
│   ├── ARCHITECTURE.md           # System architecture
│   ├── SECURITY.md               # Security considerations
│   └── API.md                    # API documentation
└── tests/                         # Test scripts
    ├── test-firewall.sh          # Firewall tests
    ├── test-dns-hijack.sh        # DNS tests
    ├── test-portal-access.sh     # Portal tests
    └── test-wan-activation.sh    # Activation tests
```

## Security Considerations

### Threat Model

This framework addresses:
- Unauthorized WAN access before device provisioning
- Unencrypted credential transmission
- DNS-based attacks during onboarding
- Man-in-the-middle attacks on credential submission

### Known Limitations

- Self-signed certificates will trigger browser warnings
- Basic credential validation (extend for production)
- No built-in rate limiting on onboarding attempts
- Credentials stored with basic encoding (use proper encryption in production)

### Production Recommendations

1. **Use proper CA-signed certificates** instead of self-signed
2. **Implement rate limiting** on login attempts
3. **Add multi-factor authentication** support
4. **Encrypt credentials** using GPG/age or HSM
5. **Integrate with enterprise identity provider** (LDAP, OAuth, SAML)
6. **Add intrusion detection** and monitoring
7. **Implement automated backup** of onboarding state
8. **Use secure boot** and verified firmware

## Troubleshooting

### Portal Not Accessible

```bash
# Check web server status
ps aux | grep uhttpd
ps aux | grep nginx

# Check firewall rules
iptables -L -n -v

# Check DNS
nslookup google.com 192.168.1.1
```

### DNS Hijack Not Working

```bash
# Verify dnsmasq is running
ps aux | grep dnsmasq

# Check dnsmasq config
cat /etc/dnsmasq.d/onboarding.conf

# Test DNS resolution
dig @192.168.1.1 example.com
```

### WAN Still Blocked After Onboarding

```bash
# Check state file
cat /etc/onboarding/state

# Verify iptables rules
iptables -L FORWARD -n -v
iptables -t nat -L POSTROUTING -n -v

# Manually remove blocking rules
iptables -D FORWARD -o wan -j DROP
iptables -t nat -A POSTROUTING -o wan -j MASQUERADE
```

### SSL Certificate Errors

```bash
# Regenerate certificates
cd /etc/onboarding/certs
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout key.pem -out cert.pem -days 365 \
  -subj "/CN=onboarding.local"
```

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

See [LICENSE](LICENSE) file for details.

## Acknowledgments

- OpenWRT project for the router operating system
- QEMU project for virtualization support
- Security research community for zero-trust principles

## References

- [OpenWRT Documentation](https://openwrt.org/docs/start)
- [Zero Trust Security Model](https://www.nist.gov/publications/zero-trust-architecture)
- [Captive Portal Detection](https://en.wikipedia.org/wiki/Captive_portal)
- [iptables Tutorial](https://www.netfilter.org/documentation/)

## Support

For issues, questions, or contributions:
- GitHub Issues: https://github.com/Abdulaileb/zero-trust-router-onboarding/issues
- Documentation: See `docs/` directory

## Changelog

### Version 1.0.0 (Initial Release)
- ✅ Firewall configuration with WAN blocking
- ✅ DNS hijacking for captive portal redirect
- ✅ HTTPS/TLS captive portal with modern UI
- ✅ Credential injection and validation
- ✅ WAN activation after successful onboarding
- ✅ QEMU testing support
- ✅ Comprehensive documentation

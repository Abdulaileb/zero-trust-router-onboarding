# QEMU Testing Guide

## Overview

This guide explains how to test the Zero-Trust Router Onboarding Framework using QEMU virtualization.

## Prerequisites

- QEMU installed (`qemu-system-x86_64`)
- At least 2GB free disk space
- 512MB RAM available
- Linux host system
- Root/sudo access for network setup

## Quick Start

### 1. Install QEMU

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install qemu-system-x86 qemu-utils
```

**Fedora/RHEL:**
```bash
sudo dnf install qemu-system-x86
```

**macOS:**
```bash
brew install qemu
```

### 2. Download OpenWRT Image

```bash
# Download x86_64 image
wget https://downloads.openwrt.org/releases/23.05.0/targets/x86/64/openwrt-23.05.0-x86-64-generic-ext4-combined.img.gz

# Extract
gunzip openwrt-23.05.0-x86-64-generic-ext4-combined.img.gz

# Resize for more space (optional)
qemu-img resize openwrt-23.05.0-x86-64-generic-ext4-combined.img 1G
```

### 3. Setup Network (Linux Host)

```bash
# Create TAP interface for LAN
sudo ip tuntap add mode tap tap0
sudo ip link set tap0 up
sudo ip addr add 192.168.1.100/24 dev tap0

# Enable IP forwarding (for testing)
sudo sysctl -w net.ipv4.ip_forward=1
```

### 4. Start QEMU VM

**Basic (No network):**
```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 256 \
  -nographic \
  -drive file=openwrt-23.05.0-x86-64-generic-ext4-combined.img,format=raw
```

**With Networking:**
```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 256 \
  -nographic \
  -drive file=openwrt-23.05.0-x86-64-generic-ext4-combined.img,format=raw \
  -netdev user,id=wan,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80,hostfwd=tcp::8443-:443 \
  -device e1000,netdev=wan \
  -netdev tap,id=lan,ifname=tap0,script=no,downscript=no \
  -device e1000,netdev=lan
```

**Parameters Explained:**
- `-enable-kvm`: Use KVM acceleration (Linux only)
- `-m 256`: Allocate 256MB RAM
- `-nographic`: Console mode (no GUI)
- `-netdev user,id=wan`: WAN interface with port forwarding
- `-netdev tap,id=lan,ifname=tap0`: LAN interface using tap0
- `hostfwd=tcp::2222-:22`: Forward host port 2222 to VM SSH (22)
- `hostfwd=tcp::8443-:443`: Forward host port 8443 to VM HTTPS (443)

### 5. Initial OpenWRT Configuration

Once the VM boots, you'll see the OpenWRT console. Log in as `root` (no password initially).

```bash
# Set root password
passwd

# Configure network interfaces
vi /etc/config/network
```

**Network configuration:**
```
config interface 'lan'
    option device 'br-lan'
    option proto 'static'
    option ipaddr '192.168.1.1'
    option netmask '255.255.255.0'

config interface 'wan'
    option device 'eth0'
    option proto 'dhcp'

config device
    option name 'br-lan'
    option type 'bridge'
    list ports 'eth1'
```

**Restart network:**
```bash
/etc/init.d/network restart
```

### 6. Install Dependencies

```bash
# Update package list
opkg update

# Install required packages
opkg install iptables-nft dnsmasq openssl-util uhttpd curl
```

### 7. Copy Framework to VM

From your host machine:

```bash
# Create archive
cd /path/to/zero-trust-router-onboarding
tar czf zero-trust.tar.gz scripts/ configs/ docs/ tests/

# Copy to VM via SCP
scp -P 2222 zero-trust.tar.gz root@localhost:/tmp/
```

On the VM:

```bash
# Extract
cd /tmp
tar xzf zero-trust.tar.gz

# Create installation directory
mkdir -p /opt/zero-trust
cp -r scripts configs docs tests /opt/zero-trust/
cd /opt/zero-trust
```

### 8. Run Setup

```bash
cd /opt/zero-trust/scripts
./setup.sh
```

Expected output:
```
╔═══════════════════════════════════════════════════════════╗
║   Zero-Trust Router Onboarding Framework                 ║
╚═══════════════════════════════════════════════════════════╝

✓ Running as root
→ Step 1/5: Checking dependencies...
✓ Dependencies checked
→ Step 2/5: Configuring firewall (blocking WAN)...
✓ Firewall configured - WAN access blocked
→ Step 3/5: Configuring DNS hijack...
✓ DNS hijack configured
→ Step 4/5: Setting up HTTPS captive portal...
✓ HTTPS captive portal configured
→ Step 5/5: Installing onboarding handlers...
✓ Onboarding handlers installed

Setup Complete! Zero-Trust Onboarding Active
```

### 9. Test from Host Machine

**Test DNS hijacking:**
```bash
# Should return 192.168.1.1 for any domain
dig @192.168.1.1 google.com
```

**Test HTTPS portal:**
```bash
# Access via forwarded port
curl -k https://localhost:8443/

# Or access directly if using tap interface
curl -k https://192.168.1.1/
```

**Test onboarding:**
```bash
curl -k -X POST https://localhost:8443/cgi-bin/onboard.sh \
  -d "device_id=qemu-test-01" \
  -d "api_key=test-key-12345678" \
  -d "owner_email=test@example.com"
```

Expected response:
```json
{
  "success": true,
  "message": "WAN access activated successfully",
  "device_id": "qemu-test-01"
}
```

### 10. Verify WAN Activation

After successful onboarding:

```bash
# On VM, check state
cat /etc/onboarding/state

# Test internet connectivity
ping -c 3 8.8.8.8
```

## Testing Scenarios

### Scenario 1: Full Onboarding Flow

1. Start VM with blocked WAN
2. Connect from host browser to `https://192.168.1.1/`
3. Fill in credentials
4. Verify WAN activation
5. Test internet access

### Scenario 2: Security Testing

```bash
# Try to bypass firewall
iptables -L -n -v

# Try to access WAN before onboarding
ping 8.8.8.8  # Should fail

# Check DNS hijacking
nslookup google.com

# After onboarding
ping 8.8.8.8  # Should succeed
```

### Scenario 3: Test Suite

```bash
# Run all tests
cd /opt/zero-trust/tests
./test-firewall.sh
./test-dns-hijack.sh
./test-portal-access.sh
./test-wan-activation.sh
```

## Troubleshooting

### VM Won't Boot

```bash
# Check QEMU version
qemu-system-x86_64 --version

# Try without KVM
qemu-system-x86_64 -m 256 -nographic -drive file=openwrt.img,format=raw
```

### Network Not Working

```bash
# On VM, check interfaces
ip addr show

# Restart network
/etc/init.d/network restart

# Check routing
ip route show
```

### Can't Access Portal

```bash
# Check uhttpd status
ps | grep uhttpd
/etc/init.d/uhttpd restart

# Check firewall
iptables -L INPUT -n -v | grep 443

# Check logs
logread | grep uhttpd
```

### DNS Not Hijacking

```bash
# Verify dnsmasq config
cat /etc/dnsmasq.d/onboarding.conf

# Restart dnsmasq
/etc/init.d/dnsmasq restart

# Test manually
nslookup google.com 127.0.0.1
```

## Advanced Configuration

### Enable Serial Console

```bash
qemu-system-x86_64 \
  ... \
  -serial mon:stdio \
  -nographic
```

### Multiple VMs

```bash
# Create multiple disk images
cp openwrt.img openwrt-vm1.img
cp openwrt.img openwrt-vm2.img

# Start with different ports
qemu-system-x86_64 ... -netdev user,hostfwd=tcp::2222-:22 ...
qemu-system-x86_64 ... -netdev user,hostfwd=tcp::2223-:22 ...
```

### Snapshot Testing

```bash
# Create snapshot before testing
qemu-img snapshot -c clean-install openwrt.img

# Restore snapshot
qemu-img snapshot -a clean-install openwrt.img

# List snapshots
qemu-img snapshot -l openwrt.img
```

## Performance Testing

### Memory Usage

```bash
# On VM
free -m
cat /proc/meminfo

# Monitor during onboarding
watch -n 1 free -m
```

### CPU Usage

```bash
# On VM
top

# Host monitoring
top -p $(pgrep qemu)
```

### Network Throughput

```bash
# Install iperf
opkg install iperf3

# Run server on VM
iperf3 -s

# Run client from host
iperf3 -c 192.168.1.1
```

## Automated Testing

### Test Script

```bash
#!/bin/bash
# automated-test.sh

# Start VM in background
qemu-system-x86_64 ... &
QEMU_PID=$!

# Wait for boot
sleep 30

# Run tests
ssh -p 2222 root@localhost "cd /opt/zero-trust/tests && ./test-firewall.sh"
ssh -p 2222 root@localhost "cd /opt/zero-trust/tests && ./test-dns-hijack.sh"

# Test onboarding
curl -k -X POST https://localhost:8443/cgi-bin/onboard.sh \
  -d "device_id=auto-test" \
  -d "api_key=automated-key-123" \
  -d "owner_email=auto@test.com"

# Verify activation
ssh -p 2222 root@localhost "ping -c 3 8.8.8.8"

# Cleanup
kill $QEMU_PID
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: QEMU Tests

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install QEMU
        run: sudo apt-get install qemu-system-x86
      - name: Download OpenWRT
        run: |
          wget https://downloads.openwrt.org/.../openwrt.img.gz
          gunzip openwrt.img.gz
      - name: Run Tests
        run: ./automated-test.sh
```

## Cleanup

```bash
# Stop VM (from QEMU console)
poweroff

# Or kill from host
killall qemu-system-x86_64

# Remove TAP interface
sudo ip link delete tap0

# Disable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=0
```

## Resources

- [QEMU Documentation](https://www.qemu.org/docs/master/)
- [OpenWRT QEMU Guide](https://openwrt.org/docs/guide-user/virtualization/qemu)
- [TAP Networking](https://www.kernel.org/doc/Documentation/networking/tuntap.txt)

## Next Steps

1. Test with physical hardware
2. Customize portal design
3. Integrate with production API
4. Add monitoring
5. Deploy to production routers

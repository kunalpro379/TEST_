#!/bin/bash

# TUN device diagnostic script

echo "=== TUN Device Diagnostic Tool ==="
echo "This script will check the status of your TUN device and report any issues."
echo ""

# Check if TUN module is loaded
echo "1. Checking if TUN module is loaded:"
if lsmod | grep -q "^tun"; then
  echo "   ✅ TUN module is loaded"
else
  echo "   ❌ TUN module is NOT loaded"
  echo "      Run 'sudo modprobe tun' to load it"
fi

# Check if /dev/net/tun exists
echo ""
echo "2. Checking if TUN device node exists:"
if [ -c /dev/net/tun ]; then
  echo "   ✅ /dev/net/tun exists"
  
  # Check permissions
  PERMS=$(stat -c "%a" /dev/net/tun)
  OWNER=$(stat -c "%U:%G" /dev/net/tun)
  echo "   - Permissions: $PERMS"
  echo "   - Owner: $OWNER"
  
  if [[ "$PERMS" == "666" || "$PERMS" == "600" || "$PERMS" == "644" ]]; then
    echo "   ✅ Permissions look good"
  else
    echo "   ⚠️ Permissions may be restrictive"
  fi
else
  echo "   ❌ /dev/net/tun does NOT exist"
  echo "      Run 'sudo mkdir -p /dev/net && sudo mknod /dev/net/tun c 10 200 && sudo chmod 666 /dev/net/tun'"
fi

# Check for tun0 interface
echo ""
echo "3. Checking for tun0 interface:"
if ip link show tun0 &>/dev/null; then
  echo "   ✅ tun0 interface exists"
  echo "   - Interface details:"
  ip addr show tun0 | sed 's/^/     /'
  
  # Check if it's UP
  if ip link show tun0 | grep -q "UP"; then
    echo "   ✅ tun0 is UP"
  else
    echo "   ❌ tun0 is DOWN"
    echo "      Run 'sudo ip link set tun0 up' to bring it up"
  fi
else
  echo "   ❌ tun0 interface does NOT exist"
  echo "      Run 'sudo ip tuntap add dev tun0 mode tun' to create it"
fi

# Check for processes using the TUN device
echo ""
echo "4. Checking for processes using the TUN device:"
PROCS=$(lsof /dev/net/tun 2>/dev/null)
if [ -n "$PROCS" ]; then
  echo "   ⚠️ Found processes using the TUN device:"
  echo "$PROCS" | sed 's/^/     /'
  echo "   These processes might interfere with your VPN server"
else
  echo "   ✅ No processes are currently using the TUN device"
fi

# Check IP forwarding
echo ""
echo "5. Checking IP forwarding status:"
IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$IP_FORWARD" -eq 1 ]; then
  echo "   ✅ IP forwarding is enabled"
else
  echo "   ❌ IP forwarding is disabled"
  echo "      Run 'sudo echo 1 > /proc/sys/net/ipv4/ip_forward' to enable it"
fi

echo ""
echo "=== Diagnostic Complete ===" 
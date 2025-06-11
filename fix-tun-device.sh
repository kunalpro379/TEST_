#!/bin/bash

# This script helps diagnose and fix TUN device issues for the VPN server

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (with sudo)"
  exit 1
fi

echo "=== TUN Device Diagnostic and Fix Tool ==="

# Step 1: Check if TUN module is loaded
echo "Checking if TUN module is loaded..."
if lsmod | grep -q "^tun"; then
  echo "✅ TUN module is loaded"
else
  echo "❌ TUN module is not loaded. Loading it now..."
  modprobe tun
  if [ $? -eq 0 ]; then
    echo "✅ Successfully loaded TUN module"
  else
    echo "❌ Failed to load TUN module. This is a critical error."
    exit 1
  fi
fi

# Step 2: Check if /dev/net/tun exists and has correct permissions
echo "Checking TUN device node..."
if [ -c /dev/net/tun ]; then
  echo "✅ /dev/net/tun exists"
  
  # Check permissions
  PERMS=$(stat -c "%a" /dev/net/tun)
  if [[ "$PERMS" == "666" || "$PERMS" == "600" || "$PERMS" == "644" ]]; then
    echo "✅ /dev/net/tun has appropriate permissions: $PERMS"
  else
    echo "⚠️ /dev/net/tun has unusual permissions: $PERMS"
    echo "Setting permissions to 666 (read/write for all users)..."
    chmod 666 /dev/net/tun
  fi
else
  echo "❌ /dev/net/tun does not exist. Creating it now..."
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200
  chmod 666 /dev/net/tun
  echo "✅ Created /dev/net/tun device node"
fi

# Step 3: Check for existing tun0 interface and remove it if found
echo "Checking for existing tun0 interface..."
if ip link show tun0 &>/dev/null; then
  echo "⚠️ tun0 interface already exists. Removing it..."
  ip link set tun0 down
  ip tuntap del dev tun0 mode tun
  echo "✅ Removed existing tun0 interface"
fi

# Step 4: Check for processes using the TUN device
echo "Checking for processes using the TUN device..."
PROCS=$(lsof /dev/net/tun 2>/dev/null)
if [ -n "$PROCS" ]; then
  echo "⚠️ Found processes using the TUN device:"
  echo "$PROCS"
  echo "Would you like to kill these processes? (y/n)"
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    lsof /dev/net/tun | awk 'NR>1 {print $2}' | xargs kill -9 2>/dev/null
    echo "✅ Killed processes using the TUN device"
  fi
else
  echo "✅ No processes are currently using the TUN device"
fi

# Step 5: Create a fresh tun0 interface
echo "Creating a fresh tun0 interface..."
ip tuntap add dev tun0 mode tun
ip addr add 10.0.0.1/24 dev tun0
ip link set tun0 up

if ip link show tun0 &>/dev/null; then
  echo "✅ Successfully created and configured tun0 interface"
  echo "Interface details:"
  ip addr show tun0
else
  echo "❌ Failed to create tun0 interface"
  exit 1
fi

# Step 6: Enable IP forwarding
echo "Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward
if [ $? -eq 0 ]; then
  echo "✅ IP forwarding enabled"
else
  echo "❌ Failed to enable IP forwarding"
fi

echo ""
echo "=== TUN device setup complete ==="
echo "You can now run your VPN server with:"
echo "sudo java -jar target/vpn-server-1.0-SNAPSHOT-jar-with-dependencies.jar"
echo "" 
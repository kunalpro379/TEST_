#!/bin/bash

# Improved VPN Server startup script with better error handling

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (with sudo)"
  exit 1
fi

# Cleanup function to ensure everything is cleaned up on exit
cleanup() {
  echo "Cleaning up..."
  # Close any existing Java processes using the TUN device
  pkill -f "vpn-server-1.0-SNAPSHOT-jar-with-dependencies.jar" 2>/dev/null
  
  # Remove the TUN interface if it exists
  ip link show tun0 >/dev/null 2>&1 && {
    ip link set tun0 down 2>/dev/null
    ip tuntap del dev tun0 mode tun 2>/dev/null
    echo "TUN interface removed."
  }
  
  exit
}

# Register the cleanup function to run on script exit
trap cleanup EXIT INT TERM

echo "=== VPN Server Startup ==="

# Step 1: Check if TUN module is loaded
echo "Checking if TUN module is loaded..."
if ! lsmod | grep -q "^tun"; then
  echo "TUN module not loaded. Loading it now..."
  modprobe tun
  if [ $? -ne 0 ]; then
    echo "Failed to load TUN module. This is required for the VPN to work."
    exit 1
  fi
fi

# Step 2: Check if /dev/net/tun exists with correct permissions
echo "Checking TUN device node..."
if [ ! -c /dev/net/tun ]; then
  echo "TUN device not found. Creating it..."
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200
  chmod 666 /dev/net/tun
else
  # Ensure permissions are correct
  chmod 666 /dev/net/tun
fi

# Step 3: Check for existing tun0 interface
echo "Checking for existing tun0 interface..."
if ip link show tun0 &>/dev/null; then
  echo "tun0 interface already exists. Removing it..."
  ip link set tun0 down
  ip tuntap del dev tun0 mode tun
fi

# Step 4: Check for processes using the TUN device
echo "Checking for processes using the TUN device..."
PROCS=$(lsof /dev/net/tun 2>/dev/null)
if [ -n "$PROCS" ]; then
  echo "Warning: Found processes using the TUN device:"
  echo "$PROCS"
  echo "These processes might interfere with the VPN server."
  echo "Would you like to kill these processes? (y/n)"
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    lsof /dev/net/tun | awk 'NR>1 {print $2}' | xargs kill -9 2>/dev/null
    echo "Killed processes using the TUN device."
  fi
fi

# Step 5: Create and configure TUN interface
echo "Creating TUN interface..."
ip tuntap add dev tun0 mode tun
if [ $? -ne 0 ]; then
  echo "Failed to create TUN interface. This may be a system limitation."
  exit 1
fi

echo "Configuring TUN interface..."
ip addr add 10.0.0.1/24 dev tun0
ip link set tun0 up

# Verify the interface was created successfully
if ! ip link show tun0 &>/dev/null; then
  echo "Failed to create and configure tun0 interface."
  exit 1
fi

# Step 6: Enable IP forwarding
echo "Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward

# Step 7: Set up NAT (uncomment if you want to enable internet access through the VPN)
# echo "Setting up NAT..."
# iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE

# Step 8: Run the VPN server
echo "Starting VPN server..."
java -jar target/vpn-server-1.0-SNAPSHOT-jar-with-dependencies.jar

# The cleanup will be handled by the trap 
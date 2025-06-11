#!/bin/bash

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

# Make sure TUN module is loaded
if ! lsmod | grep -q "^tun"; then
  echo "Loading TUN module..."
  modprobe tun || {
    echo "Failed to load TUN module. This might be a kernel issue."
    exit 1
  }
fi

# Check if /dev/net/tun exists
if [ ! -c /dev/net/tun ]; then
  echo "TUN device not found. Attempting to create it..."
  
  # Try to create /dev/net directory if it doesn't exist
  if [ ! -d /dev/net ]; then
    mkdir -p /dev/net
  fi
  
  # Try to create the TUN device node if it doesn't exist
  if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
    chmod 600 /dev/net/tun
  fi
fi

# Check again if the device exists
if [ ! -c /dev/net/tun ]; then
  echo "Failed to create TUN device. This might be a limitation of your environment."
  exit 1
fi

# Check for existing TUN interfaces and remove them
echo "Checking for existing TUN interfaces..."
if ip link show tun0 >/dev/null 2>&1; then
  echo "Found existing tun0 interface. Removing it first..."
  ip link set tun0 down
  ip tuntap del dev tun0 mode tun
fi

# Check for processes using the TUN device
echo "Checking for processes using TUN device..."
if lsof | grep -q "/dev/net/tun"; then
  echo "WARNING: Some processes are already using the TUN device:"
  lsof | grep "/dev/net/tun"
  echo "Attempting to continue anyway..."
fi

# Create and configure TUN interface
echo "Creating TUN interface..."
ip tuntap add dev tun0 mode tun || {
  echo "Failed to create TUN interface. This may be a permissions issue."
  exit 1
}

# Configure TUN interface
echo "Configuring TUN interface..."
ip addr add 10.0.0.1/24 dev tun0 || {
  echo "Failed to assign IP address."
  exit 1
}

ip link set tun0 up || {
  echo "Failed to bring up TUN interface."
  exit 1
}

# Set proper permissions for the TUN device
echo "Setting TUN device permissions..."
chmod 666 /dev/net/tun || {
  echo "Warning: Failed to set permissions on /dev/net/tun"
}

# Enable IP forwarding
echo "Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward || {
  echo "Failed to enable IP forwarding. This may impact VPN functionality."
}

# Run the VPN server
echo "Starting VPN server..."
java -jar target/vpn-server-1.0-SNAPSHOT-jar-with-dependencies.jar

# The cleanup will be handled by the trap 
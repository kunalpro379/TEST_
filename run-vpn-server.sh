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
  
  # Remove the symbolic link if we created one
  [ -L /dev/net/tun ] && {
    rm -f /dev/net/tun
    echo "Removed /dev/net/tun symbolic link."
  }
  
  exit
}

# Register the cleanup function to run on script exit
trap cleanup EXIT INT TERM

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
  echo "Failed to create TUN device. This might be a limitation of your WSL environment."
  echo "For WSL2, you may need to enable TUN/TAP support. See: https://github.com/microsoft/WSL/issues/4150"
  exit 1
fi

# Create and configure TUN interface
echo "Creating TUN interface..."
ip tuntap add dev tun0 mode tun || {
  echo "Failed to create TUN interface. Checking if it already exists..."
  ip link show tun0 > /dev/null 2>&1 || {
    echo "Cannot create or find tun0 interface. This may be a WSL limitation."
    echo "You might need to use a different approach for WSL or use a native Linux system."
    exit 1
  }
  echo "TUN interface already exists, continuing..."
}

# Configure TUN interface
echo "Configuring TUN interface..."
ip addr add 10.0.0.1/24 dev tun0 || {
  echo "Failed to assign IP address. Checking if already assigned..."
  ip addr show dev tun0 | grep -q "10.0.0.1/24" || {
    echo "Cannot configure TUN interface. Please check your network setup."
    exit 1
  }
  echo "IP already assigned, continuing..."
}

ip link set tun0 up || {
  echo "Failed to bring up TUN interface."
  exit 1
}

# Special step for WSL: create a symbolic link from /dev/net/tun to /dev/net/tun
# This gives Java a direct path to access the device
echo "Creating symbolic link for Java to access the TUN device..."
ln -sf /dev/net/tun /dev/net/tun || {
  echo "Warning: Failed to create symbolic link. This may not be a problem if the device works correctly."
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
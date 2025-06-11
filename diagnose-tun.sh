#!/bin/bash

echo "===== TUN Device Diagnostic Script ====="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (with sudo)"
  exit 1
fi

# Check kernel modules
echo -e "\n=== Checking if TUN module is loaded ==="
lsmod | grep tun
if [ $? -ne 0 ]; then
  echo "TUN module is not loaded. Attempting to load it..."
  modprobe tun
  if [ $? -ne 0 ]; then
    echo "Failed to load TUN module. This might be a kernel issue."
  else
    echo "Successfully loaded TUN module."
  fi
else
  echo "TUN module is loaded."
fi

# Check TUN device
echo -e "\n=== Checking TUN device node ==="
if [ -c /dev/net/tun ]; then
  echo "/dev/net/tun device exists"
  ls -la /dev/net/tun
else
  echo "/dev/net/tun does not exist!"
fi

# Check existing TUN interfaces
echo -e "\n=== Checking existing TUN interfaces ==="
ip tuntap show
echo ""
ip link show | grep tun
echo ""
ip addr show | grep tun

# Check processes using TUN
echo -e "\n=== Checking processes using TUN device ==="
lsof | grep tun

# Check permissions
echo -e "\n=== Checking permissions ==="
ls -la /dev/net/
id

echo -e "\n=== End of Diagnostic Report ===" 
# How to Test Your VPN Server

This guide explains how to test your Linux VPN server using Docker on Windows.

## Prerequisites

1. Install Docker Desktop for Windows:
   - Download from [Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - Install and make sure it's running (check the Docker icon in system tray)

2. Make sure Docker is using Linux containers (not Windows containers)

## Running the VPN Server

1. **Start Docker Desktop**
   - Look for the Docker whale icon in the taskbar
   - Make sure it says "Docker Desktop is running"

2. **Build the Docker image**
   - Open Command Prompt or PowerShell
   - Navigate to your project directory
   - Run the build command:
   ```
   docker build -t vpn-server-test .
   ```

3. **Run the container**
   - Use this command to run with the necessary privileges:
   ```
   docker run -it --rm --name vpn-test --cap-add=NET_ADMIN --device /dev/net/tun --sysctl net.ipv4.ip_forward=1 vpn-server-test
   ```

4. **What's happening inside the container**
   - TUN interface (tun0) is created
   - IP forwarding is enabled
   - NAT is configured
   - Java VPN server starts and listens for packets on tun0

## Testing the VPN Server

To test your VPN server properly, you need to create two containers:

### Setting up a client container

1. Open a new terminal window (keep the server running)

2. Run a client container:
   ```
   docker run -it --rm --name vpn-client --cap-add=NET_ADMIN --device /dev/net/tun alpine sh
   ```

3. Inside the client container, set up the TUN interface:
   ```
   apk add iproute2 iputils
   ip tuntap add dev tun0 mode tun
   ip addr add 10.0.0.2/24 dev tun0
   ip link set tun0 up
   ```

4. Test connectivity:
   ```
   ping -I tun0 10.0.0.1
   ```

## Troubleshooting Docker Issues

If Docker doesn't start or gives errors:

1. **Check Docker service**
   - Open Services (services.msc)
   - Look for "Docker Desktop Service"
   - Make sure it's running

2. **Restart Docker Desktop**
   - Right-click the Docker icon in taskbar
   - Select "Restart"

3. **WSL Issues**
   - Docker Desktop needs WSL 2 on Windows
   - Run PowerShell as administrator:
   ```
   wsl --update
   ```

4. **Network Issues**
   - If containers can't access internet:
   ```
   docker network prune
   ```
   - Then restart Docker Desktop

## Testing Without Docker

If Docker isn't working, you can test on a Linux machine or VM:

1. SSH into your Linux machine/VM

2. Install required packages:
   ```
   sudo apt update
   sudo apt install openjdk-17-jdk maven
   ```

3. Copy your project files

4. Build:
   ```
   mvn package
   ```

5. Run (as root):
   ```
   sudo bash -c 'ip tuntap add dev tun0 mode tun && \
   ip addr add 10.0.0.1/24 dev tun0 && \
   ip link set tun0 up && \
   echo 1 > /proc/sys/net/ipv4/ip_forward && \
   iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE && \
   java -jar target/vpn-server-1.0-SNAPSHOT-jar-with-dependencies.jar'
   ``` 
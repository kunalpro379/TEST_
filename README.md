# VPN Server Test in Docker

This is a simple VPN server implementation that uses TUN interfaces for capturing and forwarding IP packets. It's containerized using Docker to simplify testing.

## Prerequisites

- Docker installed on your system
- Basic understanding of networking and VPN concepts

## Quick Start

1. Build the Docker image:
   ```bash
   docker build -t vpn-server-test .
   ```

2. Run the container with required privileges:
   ```bash
   docker run -it --rm --name vpn-test \
     --cap-add=NET_ADMIN \
     --device /dev/net/tun \
     vpn-server-test
   ```

## How It Works

1. The Docker container is configured with:
   - The TUN kernel module support
   - NET_ADMIN capabilities to create/configure network interfaces
   - Tools for network testing and debugging

2. Inside the container:
   - A TUN interface (`tun0`) is created
   - IP forwarding is enabled
   - NAT is configured for outgoing connections
   - The Java VPN server reads packets from the TUN interface and processes them

3. The packet flow:
   - Client sends packet → TUN interface
   - Java server reads from TUN
   - Server processes and forwards to destination
   - Server receives response
   - Server writes response back to TUN
   - Client receives the response

## Testing Your VPN Server

### Inside the Container

The container will already have the TUN interface set up. You can verify with:
```bash
ip addr show tun0
```

You can test sending packets through the TUN interface:
```bash
ping -I tun0 8.8.8.8
```

### Manual Testing

For detailed testing, you can:

1. Examine packet flow with tcpdump:
   ```bash
   tcpdump -i tun0 -n
   ```

2. Test routing:
   ```bash
   ip route add 192.168.1.0/24 dev tun0
   ```

3. Test forwarding:
   ```bash
   echo 1 > /proc/sys/net/ipv4/ip_forward
   iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
   ```

## Development

The project is a Maven-based Java application with the following components:

- `TunDevice.java`: JNA wrapper for Linux TUN interface
- `VPNServer.java`: Main server that processes packets

To compile (inside the container):
```bash
mvn clean package
```

To run the server manually:
```bash
java -jar target/vpn-server-1.0-SNAPSHOT-jar-with-dependencies.jar
```

## Advanced Usage

For a more realistic test:

1. Create two Docker containers (server and client)
2. Set up TUN interfaces in both
3. Configure routing between them
4. Send traffic from client through the server

## Troubleshooting

- If you see "Cannot open TUN/TAP dev" errors, verify that:
  - The container has `--device /dev/net/tun`
  - The container has `--cap-add=NET_ADMIN`
  
- If packets are not being forwarded:
  - Check IP forwarding: `cat /proc/sys/net/ipv4/ip_forward`
  - Verify NAT rules: `iptables -t nat -L -v`
  - Check routing tables: `ip route` 
FROM eclipse-temurin:17-jdk-focal

# Install necessary tools for networking and debugging
RUN apt-get update && \
    apt-get install -y iproute2 iputils-ping net-tools tcpdump curl maven

# Create working directory
WORKDIR /app

# Copy project files
COPY pom.xml /app/
COPY src /app/src/

# Compile the project
RUN mvn package

# Setup entrypoint script
RUN echo '#!/bin/bash\n\
# Create TUN interface\n\
ip tuntap add dev tun0 mode tun\n\
ip addr add 10.0.0.1/24 dev tun0\n\
ip link set tun0 up\n\
# Enable IP forwarding\n\
echo 1 > /proc/sys/net/ipv4/ip_forward\n\
# Setup NAT\n\
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE\n\
# Start VPN server\n\
java -jar target/vpn-server-1.0-SNAPSHOT-jar-with-dependencies.jar\n' > /app/entrypoint.sh && \
chmod +x /app/entrypoint.sh

# Run the server
ENTRYPOINT ["/app/entrypoint.sh"]

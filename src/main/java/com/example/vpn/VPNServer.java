package com.example.vpn;

import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.nio.channels.DatagramChannel;
import java.nio.channels.SelectionKey;
import java.nio.channels.Selector;
import java.util.HashMap;
import java.util.Map;

/**
 * A simple VPN server that uses TUN interface to capture packets
 * and forward them to their destinations.
 */
public class VPNServer {
    // TUN device name
    private static final String TUN_NAME = "tun0";

    // Buffer size for packet reading
    private static final int BUFFER_SIZE = 4096;

    // Map to track active connections
    private Map<Integer, DatagramChannel> activeConnections = new HashMap<>();

    private TunDevice tunDevice;
    private Selector selector;
    private ByteBuffer buffer = ByteBuffer.allocate(BUFFER_SIZE);

    /**
     * Initialize the VPN server
     */
    public void init() throws IOException {
        try {
            // Open TUN device
            tunDevice = new TunDevice();
            tunDevice.open(TUN_NAME);
        } catch (IOException e) {
            System.err.println("Error opening TUN device: " + e.getMessage());

            // Attempt to use existing TUN device as a fallback
            if (e.getMessage().contains("Device or resource busy") ||
                    e.getMessage().contains("ioctl TUNSETIFF failed")) {
                System.out.println("Attempting to use existing TUN device...");

                // Check if tun0 device exists already
                try {
                    Process p = Runtime.getRuntime().exec("ip link show " + TUN_NAME);
                    int exitCode = p.waitFor();

                    if (exitCode == 0) {
                        System.out.println("Found existing TUN device: " + TUN_NAME);
                        tunDevice = new TunDevice();
                        tunDevice.openExisting(TUN_NAME);
                    } else {
                        throw new IOException("TUN device " + TUN_NAME + " not found");
                    }
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw new IOException("Interrupted while checking TUN device");
                }
            } else {
                throw e;
            }
        }

        // Create selector for multiplexing
        selector = Selector.open();

        System.out.println("VPN Server initialized with TUN device: " + TUN_NAME);
    }

    /**
     * Run the VPN server main loop
     */
    public void run() throws IOException {
        System.out.println("VPN Server running. Press Ctrl+C to stop.");

        // The server loop
        while (true) {
            // Read packet from TUN device
            int bytesRead = tunDevice.read(buffer.array());
            if (bytesRead <= 0) {
                continue;
            }

            buffer.position(0);
            buffer.limit(bytesRead);

            // Parse IP packet headers
            byte version = (byte) ((buffer.get(0) >> 4) & 0xF);

            if (version == 4) { // IPv4
                handleIPv4Packet(buffer, bytesRead);
            } else {
                System.out.println("Unsupported IP version: " + version);
            }

            // Reset buffer for next read
            buffer.clear();
        }
    }

    /**
     * Handle an IPv4 packet
     */
    private void handleIPv4Packet(ByteBuffer packet, int length) throws IOException {
        // Extract source and destination IP
        byte[] sourceIP = new byte[4];
        byte[] destIP = new byte[4];

        // Source IP starts at offset 12
        packet.position(12);
        packet.get(sourceIP);

        // Destination IP starts at offset 16
        packet.get(destIP);

        // Protocol is at offset 9
        byte protocol = packet.get(9);

        try {
            InetAddress srcAddr = InetAddress.getByAddress(sourceIP);
            InetAddress dstAddr = InetAddress.getByAddress(destIP);

            System.out.printf("Packet: %s -> %s, Protocol: %d, Length: %d bytes%n",
                    srcAddr.getHostAddress(), dstAddr.getHostAddress(), protocol, length);

            // Here, for a real VPN, you would:
            // 1. Create a socket to the destination
            // 2. Forward the packet
            // 3. Receive responses
            // 4. Write responses back to TUN

            // For demo purposes, we'll just log the packet details
            dumpPacketInfo(packet, length);

            // Echo the packet back to TUN for testing
            // In a real VPN, you'd receive response from destination
            packet.position(0);
            tunDevice.write(packet.array(), 0, length);

        } catch (Exception e) {
            System.err.println("Error handling packet: " + e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * Print packet details for debugging
     */
    private void dumpPacketInfo(ByteBuffer packet, int length) {
        packet.position(0);
        StringBuilder sb = new StringBuilder();
        sb.append("Packet Hex Dump: ");

        for (int i = 0; i < Math.min(length, 64); i++) {
            if (i % 16 == 0)
                sb.append("\n");
            sb.append(String.format("%02X ", packet.get(i) & 0xFF));
        }

        if (length > 64) {
            sb.append("\n... ").append(length - 64).append(" more bytes");
        }

        System.out.println(sb.toString());
    }

    /**
     * Close the VPN server and release resources
     */
    public void close() {
        try {
            if (tunDevice != null) {
                tunDevice.close();
            }

            if (selector != null) {
                selector.close();
            }

            // Close all active connections
            for (DatagramChannel channel : activeConnections.values()) {
                if (channel != null && channel.isOpen()) {
                    channel.close();
                }
            }

            System.out.println("VPN Server stopped.");
        } catch (IOException e) {
            System.err.println("Error closing VPN server: " + e.getMessage());
        }
    }

    /**
     * Main method to start the VPN server
     */
    public static void main(String[] args) {
        VPNServer server = new VPNServer();

        try {
            server.init();

            // Add shutdown hook to clean up resources
            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                System.out.println("Shutting down VPN server...");
                server.close();
            }));

            server.run();
        } catch (IOException e) {
            System.err.println("Error starting VPN server: " + e.getMessage());
            e.printStackTrace();
            server.close();
        }
    }
}
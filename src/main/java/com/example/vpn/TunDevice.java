package com.example.vpn;

import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Structure;
import com.sun.jna.ptr.IntByReference;

import java.io.Closeable;
import java.io.FileDescriptor;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.lang.reflect.Field;
import java.util.Arrays;
import java.util.List;

/**
 * JNA wrapper for Linux TUN/TAP device
 */
public class TunDevice implements Closeable {

     private static final String CLONE_DEV = "/dev/net/tun";
     private int fd = -1;
     private FileInputStream inputStream;
     private FileOutputStream outputStream;

     public interface CLibrary extends Library {
          CLibrary INSTANCE = Native.load("c", CLibrary.class);

          int open(String path, int flags);

          int close(int fd);

          int ioctl(int fd, long request, Pointer arg);

          int getuid();

          String strerror(int errno);

          int errno();
     }

     @Structure.FieldOrder({ "ifr_name", "ifr_flags" })
     public static class IfreqFlags extends Structure {
          public byte[] ifr_name = new byte[16];
          public short ifr_flags;

          public IfreqFlags(String ifName) {
               byte[] bytes = ifName.getBytes();
               System.arraycopy(bytes, 0, ifr_name, 0, Math.min(bytes.length, ifr_name.length - 1));
          }
     }

     // TUNSETIFF ioctl request
     private static final long TUNSETIFF = 0x400454ca;

     // Flags for TUNSETIFF
     private static final short IFF_TUN = 0x0001;
     private static final short IFF_NO_PI = 0x1000;

     /**
      * Open a TUN device
      * 
      * @param devName TUN interface name (e.g. "tun0")
      * @throws IOException if TUN device cannot be opened
      */
     public void open(String devName) throws IOException {
          // Check if we're running as root
          if (CLibrary.INSTANCE.getuid() != 0) {
               throw new IOException(
                         "This application requires root privileges to access TUN device. Please run with sudo.");
          }

          // Check if /dev/net/tun exists
          java.io.File tunFile = new java.io.File(CLONE_DEV);
          if (!tunFile.exists()) {
               throw new IOException("TUN device " + CLONE_DEV + " does not exist. " +
                         "Make sure the TUN module is loaded (modprobe tun)");
          }

          // Open the TUN device
          fd = CLibrary.INSTANCE.open(CLONE_DEV, 2); // O_RDWR = 2
          if (fd < 0) {
               int errno = CLibrary.INSTANCE.errno();
               String errMsg = CLibrary.INSTANCE.strerror(errno);
               throw new IOException(
                         "Failed to open " + CLONE_DEV + ": " + errMsg
                                   + ". Ensure the TUN module is loaded (modprobe tun)");
          }

          // Configure the TUN device
          IfreqFlags ifr = new IfreqFlags(devName);
          ifr.ifr_flags = (short) (IFF_TUN | IFF_NO_PI);

          int result = CLibrary.INSTANCE.ioctl(fd, TUNSETIFF, ifr.getPointer());
          if (result < 0) {
               int errno = CLibrary.INSTANCE.errno();
               String errMsg = CLibrary.INSTANCE.strerror(errno);
               CLibrary.INSTANCE.close(fd);

               if (errno == 16) { // EBUSY
                    throw new IOException(
                              "TUN device is busy (already in use). Try removing the existing tun0 interface first with: ip tuntap del dev tun0 mode tun");
               } else {
                    throw new IOException("Failed to configure TUN device: ioctl TUNSETIFF failed (" + errMsg + "). " +
                              "Make sure you have appropriate permissions and that the TUN module is loaded.");
               }
          }

          // Create Java file streams for the file descriptor
          try {
               // Use legacy approach for FileDescriptor that works on most Linux JVMs
               FileDescriptor fileDescriptor = new FileDescriptor();
               Field fdField = FileDescriptor.class.getDeclaredField("fd");
               fdField.setAccessible(true);
               fdField.setInt(fileDescriptor, fd);

               inputStream = new FileInputStream(fileDescriptor);
               outputStream = new FileOutputStream(fileDescriptor);
          } catch (Exception e) {
               CLibrary.INSTANCE.close(fd);
               throw new IOException("Failed to create streams for TUN device: " + e.getMessage(), e);
          }

          System.out.println("TUN device opened: " + devName);
     }

     /**
      * Open a TUN device that has already been created by external means
      * (like via ip tuntap command)
      * 
      * @param devName TUN interface name (e.g. "tun0")
      * @throws IOException if TUN device cannot be opened
      */
     public void openExisting(String devName) throws IOException {
          // Check if we're running as root
          if (CLibrary.INSTANCE.getuid() != 0) {
               throw new IOException(
                         "This application requires root privileges to access TUN device. Please run with sudo.");
          }

          // First check if the device actually exists
          try {
               Process p = Runtime.getRuntime().exec("ip link show " + devName);
               int exitCode = p.waitFor();
               if (exitCode != 0) {
                    throw new IOException("TUN device " + devName
                              + " does not exist. Create it first with: ip tuntap add dev " + devName + " mode tun");
               }
          } catch (InterruptedException e) {
               Thread.currentThread().interrupt();
               throw new IOException("Interrupted while checking TUN device");
          }

          // Open the TUN device
          fd = CLibrary.INSTANCE.open(CLONE_DEV, 2); // O_RDWR = 2
          if (fd < 0) {
               int errno = CLibrary.INSTANCE.errno();
               String errMsg = CLibrary.INSTANCE.strerror(errno);
               throw new IOException("Failed to open " + CLONE_DEV + ": " + errMsg + ". Ensure the TUN device exists.");
          }

          // Configure the TUN device
          IfreqFlags ifr = new IfreqFlags(devName);
          ifr.ifr_flags = (short) (IFF_TUN | IFF_NO_PI);

          int result = CLibrary.INSTANCE.ioctl(fd, TUNSETIFF, ifr.getPointer());
          if (result < 0) {
               int errno = CLibrary.INSTANCE.errno();
               String errMsg = CLibrary.INSTANCE.strerror(errno);
               CLibrary.INSTANCE.close(fd);

               if (errno == 16) { // EBUSY
                    throw new IOException("TUN device " + devName
                              + " is busy (already in use by another process). Check running processes with: lsof | grep "
                              + devName);
               } else {
                    throw new IOException("Failed to configure existing TUN device: " + errMsg
                              + ". The device may be in use by another process.");
               }
          }

          // Create Java file streams for the file descriptor
          try {
               // Use legacy approach for FileDescriptor that works on most Linux JVMs
               FileDescriptor fileDescriptor = new FileDescriptor();
               Field fdField = FileDescriptor.class.getDeclaredField("fd");
               fdField.setAccessible(true);
               fdField.setInt(fileDescriptor, fd);

               inputStream = new FileInputStream(fileDescriptor);
               outputStream = new FileOutputStream(fileDescriptor);
               System.out.println("Successfully connected to existing TUN device: " + devName);
          } catch (Exception e) {
               CLibrary.INSTANCE.close(fd);
               throw new IOException("Failed to create streams for TUN device: " + e.getMessage(), e);
          }
     }

     /**
      * Read data from TUN device
      * 
      * @param buffer Buffer to read into
      * @return Number of bytes read
      * @throws IOException if read fails
      */
     public int read(byte[] buffer) throws IOException {
          return inputStream.read(buffer);
     }

     /**
      * Write data to TUN device
      * 
      * @param buffer Buffer to write
      * @param offset Offset in buffer
      * @param length Number of bytes to write
      * @throws IOException if write fails
      */
     public void write(byte[] buffer, int offset, int length) throws IOException {
          outputStream.write(buffer, offset, length);
     }

     /**
      * Close the TUN device
      */
     @Override
     public void close() throws IOException {
          if (inputStream != null) {
               inputStream.close();
          }

          if (outputStream != null) {
               outputStream.close();
          }

          if (fd >= 0) {
               CLibrary.INSTANCE.close(fd);
               fd = -1;
          }
     }
}
# Windows Gaming VM Setup

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers Windows gaming VM setup with GPU passthrough:

- **Windows VM Configuration**: Optimizing Windows for gaming performance
- **VirtIO Driver Installation**: Paravirtualized drivers for better performance
- **GPU Passthrough Tuning**: Maximizing gaming performance
- **Input Device Passthrough**: USB controllers, keyboards, mice
- **Performance Optimization**: Latency reduction, frame rate improvement

## When You Need This

- Gaming servers for streaming
- Windows-only game development
- Multi-user gaming environments
- Game server hosting with GPU requirements

## Simpler Alternative

For most homelab users:
- Use native Windows installation for gaming
- Use cloud gaming services (GeForce Now, Xbox Cloud)
- Run games on Linux with Proton/Steam Play
- Use remote desktop for occasional Windows access

---

## Prerequisites

### Host Requirements

```bash
# Verify GPU supports passthrough
lspci -v | grep -i vga

# Check IOMMU group isolation
for i in /sys/kernel/iommu_groups/*; do 
    echo "IOMMU Group $(basename $i):"; 
    lspci -nnv -D -s $(ls $i/* | sed 's|.*/||' | head -1); 
done

# Ensure GPU is not used by host
# Consider using integrated GPU for host display
```

### VM Requirements

- GPU passthrough configured (see [GPU_PASSTHROUGH/README.md](GPU_PASSTHROUGH/README.md))
- At least 8GB RAM recommended (16GB+ for modern games)
- 100GB+ storage for Windows and games
- USB passthrough for controllers

---

## VM Creation

Create a Windows gaming VM with optimized settings.

```bash
# Create VM with gaming-optimized settings
qm create 100 --name windows-gaming --memory 16384 --cores 8 --sockets 1 --cpu host \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-100-disk-0,size=200G \
  --net0 virtio,bridge=vmbr0,firewall=1 \
  --usb0 host=XX:XX,usb3=1 \
  --vga qxl --qxlvgamemeg 256

# Add GPU passthrough
qm set 100 --args '-device vfio-pci,host=01:00.0,x-vga=on'

# Enable KVM acceleration
qm set 100 --kvm 1

# Set boot order
qm set 100 --boot order='cdn'

# Enable USB tablet for mouse integration
qm set 100 --usb0 host=XX:XX,usb3=1

# Start VM
qm start 100

# Open console
qm terminal 100
```

> **⚠️ PITFALL**: High resource allocation affects other VMs.

---

## VirtIO Driver Installation

Install VirtIO drivers for better VM performance.

```bash
# Download VirtIO ISO
# From Proxmox repo: https://fedorapeople.org/groups/virt-io/virtio-win/direct-downloads/stable-virtio/

# Attach VirtIO ISO to VM
qm set 100 --ide2 local-lvm:virtio.iso,media=cdrom

# Inside Windows VM:
# 1. Open Device Manager
# 2. Find unknown devices
# 3. Update driver -> Browse my computer
# 4. Point to VirtIO ISO -> win10/amd64 (or win11)
# 5. Install all VirtIO drivers:
#    - VirtIO GPU (for display)
#    - VirtIO SCSI (for storage)
#    - NetKVM (for network)
#    - Balloon (for memory management)

# Verify drivers installed
# Device Manager should show no yellow exclamation marks
```

> **⚠️ PITFALL**: Wrong VirtIO version can cause issues.

---

## GPU Driver Installation

Install GPU drivers in the Windows VM.

```bash
# Inside Windows VM after GPU passthrough:

# For NVIDIA GPU:
# 1. Download latest driver from NVIDIA website
# 2. Run installer
# 3. Select "Custom Installation"
# 4. Check "Perform clean installation"
# 5. Install GeForce Experience (optional)

# For AMD GPU:
# 1. Download AMD Adrenalin driver
# 2. Run installer
# 3. Select "Full Installation"
# 4. Install additional software (optional)

# Verify driver installation
# Device Manager -> Display adapters
# Should show your GPU without errors

# Check GPU in Task Manager
# Performance tab -> GPU
```

> **⚠️ PITFALL**: Windows updates can break passthrough.

---

## Performance Optimization

Optimize the VM for gaming performance.

```bash
# Disable ballooning for consistent memory
qm set 100 --balloon 0

# Enable CPU passthrough
qm set 100 --cpu host

# Set NUMA topology for multi-socket CPUs
qm set 100 --numa 1

# Increase I/O queue depth
qm set 100 --scsi0 local-lvm:vm-100-disk-0,size=200G,iothread=1

# Enable hugepages for better performance
qm set 100 --memory 16384 --balloon 0

# Optimize network settings
qm set 100 --net0 virtio,bridge=vmbr0,firewall=1,rate=1000

# Inside Windows - Power Settings:
# 1. Control Panel -> Power Options
# 2. Select "High Performance"
# 3. Advanced settings -> PCI Express -> Link State Power Management
# 4. Set to "Off"

# Inside Windows - GPU Settings:
# 1. NVIDIA Control Panel / AMD Software
# 2. Power Management -> Prefer Maximum Performance
# 3. Texture Filtering -> Performance
```

> **⚠️ PITFALL**: Over-optimization can cause instability.

---

## Input Device Passthrough

Pass through USB controllers and devices.

```bash
# List USB devices
lsusb

# Pass through USB controller
qm set 100 --usb0 host=XX:XX,usb3=1

# Pass through specific USB device (keyboard/mouse)
qm set 100 --usb1 host=YY:YY

# Inside Windows - Game Controller Settings:
# 1. Control Panel -> Devices and Printers
# 2. Right-click controller -> Game controller settings
# 3. Calibrate if needed

# Test with game
# Launch game and verify controller input
```

> **⚠️ PITFALL**: USB device can only be used by one VM at a time.

---

## Network Optimization

Optimize network for low-latency gaming.

```bash
# Configure bridge for low latency
cat > /etc/network/interfaces.d/vmbr0 << 'EOF'
auto vmbr0
iface vmbr0 inet manual
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    bridge-maxwait 0
EOF

# Restart networking
systemctl restart networking

# Inside Windows - Network Settings:
# 1. Control Panel -> Network and Sharing Center
# 2. Change adapter settings
# 3. Right-click Ethernet -> Properties
# 4. Configure -> Advanced
# 5. Set:
#    - Interrupt Moderation: Off
#    - Flow Control: Off
#    - Large Send Offload: Disabled

# Test network latency
# ping -t 192.168.1.1  # From Windows VM
```

> **⚠️ PITFALL**: Disabling features can reduce stability.

---

## Game Installation

Install games in the VM.

```bash
# Mount game ISO
qm set 100 --ide3 local-lvm:game.iso,media=cdrom

# Inside Windows:
# 1. Open File Explorer
# 2. Navigate to DVD drive
# 3. Run installer
# 4. Install to fast storage (NVMe preferred)

# For Steam:
# 1. Download Steam installer
# 2. Install Steam
# 3. Configure library folders
# 4. Install games

# Optimize Steam settings:
# 1. Steam -> Settings -> Downloads
# 2. Download region: Closest server
# 3. Limit download bandwidth: Unchecked
# 4. In-game FPS limit: Unchecked
```

---

## Troubleshooting

Common gaming VM issues and solutions.

```bash
# Issue 1: Low FPS
# Solution: Check GPU passthrough
qm set 100 | grep args
# Should show: -device vfio-pci,host=XX:XX.0,x-vga=on

# Issue 2: Input lag
# Solution: Enable USB tablet
qm set 100 --usb0 host=XX:XX,usb3=1

# Issue 3: Black screen on boot
# Solution: Add x-vga=on
qm set 100 --args '-device vfio-pci,host=01:00.0,x-vga=on'

# Issue 4: GPU not detected
# Solution: Check IOMMU group
for i in /sys/kernel/iommu_groups/*; do 
    echo "IOMMU Group $(basename $i):"; 
    lspci -nnv -D -s $(ls $i/* | sed 's|.*/||' | head -1); 
done

# Issue 5: Audio not working
# Solution: Pass through audio device
qm set 100 --args '-device vfio-pci,host=01:00.1'

# Debug logs
dmesg | grep -i vfio
dmesg | grep -i iommu
journalctl -u pvedaemon | grep -i vfio
```

---

## Summary

### Gaming Performance Comparison

| Configuration | FPS | Latency | Quality |
|-----|-----|---------|-|
| Native Windows | 100% | Lowest | Best |
| GPU Passthrough | 85-95% | Low | Excellent |
| Remote Desktop | 30-50% | High | Good |
| Cloud Gaming | 60-80% | Variable | Good |

### Learning Path Progression

1. **Beginner**: Basic VM creation, GPU passthrough
2. **Intermediate**: VirtIO drivers, performance tuning
3. **Advanced**: USB passthrough, network optimization
4. **Enterprise**: Multi-VM gaming, streaming setup

### Real-World Job Skill Mapping

- **DevOps Engineer**: VM configuration, automation
- **Cloud Engineer**: Hardware virtualization, resource management
- **SRE**: Troubleshooting, performance optimization
- **Gaming Industry**: Game server setup, optimization

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.

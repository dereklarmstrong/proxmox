# GPU Passthrough Troubleshooting Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers systematic troubleshooting for GPU passthrough issues:

- **Systematic Debugging**: Methodical approach to hardware virtualization issues
- **Log Analysis**: Interpreting kernel and system logs
- **Hardware Compatibility Testing**: Verifying device support
- **Driver Management**: Host and guest driver conflicts
- **Performance Profiling**: Identifying bottlenecks

## When You Need This

- GPU passthrough not working
- Performance issues in VM
- Driver conflicts
- Hardware compatibility problems
- Intermittent failures

## Simpler Alternative

For most homelab users:
- Use cloud GPU services for development
- Run GPU workloads on separate physical hardware
- Use virtual GPU (virtio-gpu) for display
- Test passthrough in non-production first

---

## Common Issues and Solutions

### Issue 1: IOMMU Not Enabled

**Symptoms**:
- VFIO modules fail to load
- Error: "IOMMU group not found"
- GPU passthrough fails silently

**Diagnosis**:
```bash
# Check IOMMU status
dmesg | grep -i iommu
dmesg | grep -i DMAR

# Check kernel parameters
cat /proc/cmdline | grep iommu

# Verify GRUB configuration
cat /etc/default/grub | grep CMDLINE
```

**Solution**:
```bash
# Enable IOMMU in GRUB
cat > /etc/default/grub.d/iommu.cfg << 'EOF'
GRUB_CMDLINE_LINUX="amd_iommu=on intel_iommu=on iommu=pt"
EOF

# Update GRUB
update-grub

# Reboot
reboot

# Verify after reboot
dmesg | grep -i iommu
```

> **⚠️ PITFALL**: Wrong IOMMU settings can cause boot issues.

---

### Issue 2: VFIO Module Not Loading

**Symptoms**:
- `modprobe vfio_pci` fails
- Error: "Module vfio_pci not found"
- GPU not available for passthrough

**Diagnosis**:
```bash
# Check if VFIO modules are loaded
lsmod | grep vfio

# Check for module errors
dmesg | grep -i vfio

# Check module availability
modprobe -l | grep vfio
```

**Solution**:
```bash
# Create VFIO configuration
cat > /etc/modprobe.d/vfio.conf << 'EOF'
# Load VFIO modules
options vfio-pci ids=10de:1d80,10de:10f0
EOF

# Add modules to load on boot
cat > /etc/modules-load.d/vfio.conf << 'EOF'
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF

# Load modules
modprobe vfio
modprobe vfio_iommu_type1
modprobe vfio_pci
modprobe vfio_virqfd

# Verify
lsmod | grep vfio
```

> **⚠️ PITFALL**: Module conflicts with host drivers.

---

### Issue 3: GPU Driver Conflict

**Symptoms**:
- Host display broken after passthrough
- GPU still bound to host driver
- Error: "Device or resource busy"

**Diagnosis**:
```bash
# Check which driver is using GPU
lspci -k -s 01:00.0
# Look for "Kernel driver in use"

# Check loaded modules
lsmod | grep -E 'nvidia|nouveau|amdgpu|radeon'
```

**Solution**:
```bash
# Blacklist host GPU drivers
cat > /etc/modprobe.d/blacklist-gpu.conf << 'EOF'
blacklist nvidia
blacklist nvidia_modeset
blacklist nvidia_uvm
blacklist nvidia_drm
blacklist nouveau
blacklist radeon
blacklist amdgpu
EOF

# Update initramfs
update-initramfs -u

# Reboot
reboot

# Verify GPU is free
lspci -k -s 01:00.0
# Should show "Kernel driver in use: vfio-pci"
```

> **⚠️ PITFALL**: Can break host display if wrong GPU blacklisted.

---

### Issue 4: Shared IOMMU Groups

**Symptoms**:
- Cannot passthrough GPU alone
- Error: "Failed to assign device to domain"
- Audio device in same group as GPU

**Diagnosis**:
```bash
# List IOMMU groups
for i in /sys/kernel/iommu_groups/*; do 
    echo "IOMMU Group $(basename $i):"; 
    lspci -nnv -D -s $(ls $i/* | sed 's|.*/||' | head -1); 
done

# Find your GPU's group
grep -r "01:00.0" /sys/kernel/iommu_groups/*/devices/
```

**Solution**:
```bash
# Option 1: Pass through entire group
qm set 100 --args '-device vfio-pci,host=01:00.0,x-vga=on'
qm set 100 --args '-device vfio-pci,host=01:00.1'  # Audio device

# Option 2: Use ACS override (advanced, not recommended)
# Add to GRUB: pcie_acs_override=downstream,multifunction

# Option 3: Use different GPU with isolated IOMMU group
```

> **⚠️ PITFALL**: ACS override can be insecure.

---

### Issue 5: Black Screen in VM

**Symptoms**:
- VM boots but no display
- Console shows nothing
- GPU passthrough appears successful

**Diagnosis**:
```bash
# Check VM configuration
qm config 100 | grep -E 'args|vga'

# Check VM logs
qm log 100

# Check if GPU is detected in VM
# (If you can access console via VNC)
```

**Solution**:
```bash
# Add x-vga=on for primary display
qm set 100 --args '-device vfio-pci,host=01:00.0,x-vga=on'

# Disable virtual VGA
qm set 100 --vga none

# Or use QXL for fallback
qm set 100 --vga qxl --qxlvgamemeg 256

# Restart VM
qm stop 100
qm start 100
```

> **⚠️ PITFALL**: x-vga=on can cause host display issues.

---

### Issue 6: Low Performance

**Symptoms**:
- FPS significantly lower than native
- High latency
- Stuttering

**Diagnosis**:
```bash
# Check VM configuration
qm config 100 | grep -E 'cpu|memory|cores'

# Check host resource usage
top
htop

# Check GPU utilization in VM
# (Use nvidia-smi or rocm-smi inside VM)
```

**Solution**:
```bash
# Enable CPU passthrough
qm set 100 --cpu host

# Disable memory ballooning
qm set 100 --balloon 0

# Increase memory allocation
qm set 100 --memory 16384

# Enable NUMA
qm set 100 --numa 1

# Use virtio SCSI
qm set 100 --scsihw virtio-scsi-pci

# Inside VM - Power Settings:
# Set to High Performance
```

> **⚠️ PITFALL**: High resource usage affects other VMs.

---

### Issue 7: Audio Not Working

**Symptoms**:
- No sound in VM
- Audio device not detected
- Error in device manager

**Diagnosis**:
```bash
# Check if audio device is in same IOMMU group as GPU
for i in /sys/kernel/iommu_groups/*; do 
    echo "IOMMU Group $(basename $i):"; 
    lspci -nnv -D -s $(ls $i/* | sed 's|.*/||' | head -1); 
done

# Check VM configuration
qm config 100 | grep args
```

**Solution**:
```bash
# Pass through audio device (usually in same group as GPU)
qm set 100 --args '-device vfio-pci,host=01:00.1'

# Or pass through entire USB audio controller
qm set 100 --usb0 host=XX:XX

# Inside Windows - Sound Settings:
# Set default playback device to passed-through audio
```

---

### Issue 8: Windows Update Breaks Passthrough

**Symptoms**:
- Passthrough worked before
- Windows update caused issues
- GPU not detected after update

**Diagnosis**:
```bash
# Check Device Manager in VM
# Look for yellow exclamation marks

# Check Windows Event Viewer
# Look for GPU-related errors
```

**Solution**:
```bash
# Inside Windows VM:
# 1. Device Manager -> Display adapters
# 2. Right-click GPU -> Update driver
# 3. Browse my computer -> Let me pick
# 4. Select GPU from list

# Or reinstall drivers:
# 1. Download latest driver
# 2. Use DDU (Display Driver Uninstaller)
# 3. Clean install driver

# Prevent automatic updates:
# Group Policy -> Computer Configuration
# Administrative Templates -> Windows Components
# Windows Update -> Don't include drivers
```

> **⚠️ PITFALL**: Security updates may be delayed.

---

### Issue 9: VM Won't Start After Passthrough Config

**Symptoms**:
- VM fails to start
- Error in Proxmox web UI
- Console shows error

**Diagnosis**:
```bash
# Check Proxmox logs
journalctl -u pvedaemon | tail -50

# Check VM log
qm log 100

# Check for VFIO errors
dmesg | grep -i vfio
```

**Solution**:
```bash
# Remove GPU passthrough temporarily
qm set 100 --args ''

# Start VM without GPU
qm start 100

# Debug step by step:
# 1. Start VM without args
# 2. Add args incrementally
# 3. Test each addition

# Check for conflicting devices
qm config 100 | grep -E 'hostpci|args'
```

---

### Issue 10: GPU Reset Failures

**Symptoms**:
- GPU works initially
- Stops working after suspend/resume
- Intermittent failures

**Diagnosis**:
```bash
# Check GPU reset capability
cat /sys/bus/pci/devices/0000:01:00.0/reset

# Check kernel messages
dmesg | grep -i reset
```

**Solution**:
```bash
# Enable GPU reset in kernel
cat > /etc/modprobe.d/vfio.conf << 'EOF'
options vfio-pci enable_reset=1
EOF

# Update initramfs
update-initramfs -u

# Reboot
reboot

# For NVIDIA GPUs - disable runtime PM
cat > /etc/modprobe.d/nvidia-pm.conf << 'EOF'
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia-drm modeset=1
EOF
```

> **⚠️ PITFALL**: Reset may not work on all hardware.

---

## Debugging Checklist

```bash
# Complete debugging checklist
echo "=== GPU Passthrough Debugging ==="

# 1. Check IOMMU
echo "IOMMU Status:"
dmesg | grep -i iommu | head -5

# 2. Check VFIO modules
echo "VFIO Modules:"
lsmod | grep vfio

# 3. Check GPU IOMMU group
echo "GPU IOMMU Group:"
for i in /sys/kernel/iommu_groups/*; do 
    if grep -q "01:00.0" $i/devices/* 2>/dev/null; then
        echo "Found in: $(basename $i)"
        lspci -nnv -D -s 01:00.0
    fi
done

# 4. Check driver binding
echo "GPU Driver:"
lspci -k -s 01:00.0

# 5. Check VM configuration
echo "VM Passthrough Config:"
qm config 100 | grep -E 'args|hostpci'

# 6. Check recent errors
echo "Recent Errors:"
dmesg | grep -i error | tail -10

echo "=== Debugging Complete ==="
```

---

## Summary

### Learning Path Progression

1. **Beginner**: Basic troubleshooting, log checking
2. **Intermediate**: Driver conflicts, IOMMU groups
3. **Advanced**: Performance optimization, complex setups
4. **Enterprise**: Multi-GPU, automated recovery

### Real-World Job Skill Mapping

- **SRE**: Troubleshooting, incident response
- **DevOps Engineer**: Debugging, automation
- **Cloud Engineer**: Hardware virtualization
- **AI/ML Engineer**: GPU troubleshooting

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.

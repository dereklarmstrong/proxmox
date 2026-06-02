# GPU Passthrough on Proxmox VE 8.x

## Overview

Guide for passing through NVIDIA and AMD GPUs to VMs on Proxmox VE 8.x.
Covers IOMMU setup, VFIO driver binding, and guest configuration.

## Prerequisites

- CPU with IOMMU support (Intel VT-d or AMD-Vi)
- IOMMU enabled in BIOS/UEFI
- Proxmox VE 8.x on Debian 12
- Dedicated GPU for passthrough (not the one Proxmox host is using)

## Step 1: Enable IOMMU

### Intel CPUs

Edit `/etc/default/grub`:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```

### AMD CPUs

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"
```

Apply:

```bash
update-grub
reboot
```

Verify:

```bash
dmesg | grep -e DMAR -e IOMMU
```

## Step 2: Load VFIO Modules

Add to `/etc/modules`:

```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

Update initramfs:

```bash
update-initramfs -u -k all
reboot
```

## Step 3: Identify GPU PCI IDs

```bash
lspci -nn | grep -i nvidia   # or grep -i amd
```

Note the PCI IDs (e.g., `10de:2204,10de:1aef` for NVIDIA GPU + audio).

## Step 4: Bind GPU to VFIO

Create `/etc/modprobe.d/vfio.conf`:

```bash
options vfio-pci ids=10de:2204,10de:1aef disable_vga=1
```

Blacklist the host driver:

```bash
# /etc/modprobe.d/blacklist.conf
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
# For AMD:
# blacklist amdgpu
# blacklist radeon
```

Update initramfs and reboot:

```bash
update-initramfs -u -k all
reboot
```

Verify VFIO binding:

```bash
lspci -nnk -s <PCI_ADDRESS>
# Should show: Kernel driver in use: vfio-pci
```

## Step 5: VM Configuration

Add PCI device to VM config (`/etc/pve/qemu-server/<vmid>.conf`):

```
hostpci0: <PCI_ADDRESS>,pcie=1
cpu: host
machine: q35
```

Or via CLI:

```bash
qm set <vmid> -hostpci0 <PCI_ADDRESS>,pcie=1
qm set <vmid> -cpu host
qm set <vmid> -machine q35
```

## NVIDIA-Specific Notes

* Install NVIDIA drivers inside the guest VM, not on the host
* CUDA compatibility depends on driver version — match driver to your CUDA toolkit
* For vGPU (if supported by your GPU): requires NVIDIA vGPU license and supported GPU
* Consumer GPUs (RTX 3090, 4090, etc.) support full passthrough but NOT vGPU

### Verify inside guest:

```bash
nvidia-smi
```

## AMD ROCm-Specific Notes

* Install `amdgpu` driver inside guest
* ROCm requires specific kernel versions — check ROCm compatibility matrix
* For ROCm container runtime, install `rocm-docker` package inside guest

### Verify inside guest:

```bash
rocm-smi
```

## IOMMU Groups

If your GPU shares an IOMMU group with other devices, you must pass through
ALL devices in that group. Check groups:

```bash
#!/bin/bash
for d in /sys/kernel/iommu_groups/*/devices/*; do
  n=$(basename $(dirname $(dirname "$d")))
  echo "IOMMU Group $n: $(lspci -nns ${d##*/})"
done | sort -V
```

If grouping is too broad, consider the ACS override patch (use with caution —
security implications).

## Common Issues

| Problem                            | Cause                      | Fix                                                  |
| ---------------------------------- | -------------------------- | ---------------------------------------------------- |
| VM won't start after adding GPU    | IOMMU not enabled          | Verify `dmesg \| grep IOMMU` shows enabled           |
| GPU not visible in guest           | VFIO not binding           | Check `lspci -nnk` shows vfio-pci driver             |
| Black screen on GPU output         | Missing ROM file           | Add `romfile=<path>` to hostpci config               |
| Reset bug (GPU won't reinitialize) | Known issue with some GPUs | Requires host reboot or vendor-specific reset script |
| Poor performance                   | Missing `cpu: host`        | Set CPU type to `host`, not `kvm64`                  |

# GPU Passthrough Documentation

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## Overview

This section covers GPU passthrough configuration for Proxmox, enabling near-native GPU performance in VMs for gaming, AI/ML workloads, and other GPU-accelerated applications.

## Documentation Index

| Document | Description | Difficulty |
|----------|-------------|------------|
| [`readme.md`](readme.md) | GPU passthrough fundamentals and IOMMU configuration | Intermediate |
| [`nvidia-cuda.md`](nvidia-cuda.md) | CUDA setup for AI/ML workloads | Advanced |
| [`amd-rocm.md`](amd-rocm.md) | ROCm setup for AMD GPU computing | Advanced |
| [`gaming.md`](gaming.md) | Windows gaming VM configuration | Intermediate |
| [`troubleshooting.md`](troubleshooting.md) | Common issues and debugging | All levels |

### Quick Reference

- **Getting Started**: Start with the main [`readme.md`](readme.md)
- **AI/ML Workloads**: Follow [`nvidia-cuda.md`](nvidia-cuda.md) or [`amd-rocm.md`](amd-rocm.md)
- **Gaming Setup**: See [`gaming.md`](gaming.md)
- **Issues**: Check [`troubleshooting.md`](troubleshooting.md)

## Use Cases

### Gaming VMs
- Near-native performance for Windows gaming
- DirectX and Vulkan support
- Low latency for competitive gaming
- See: [`gaming.md`](gaming.md)

### AI/ML Workloads
- CUDA for NVIDIA GPUs (machine learning)
- ROCm for AMD GPUs (open source ML)
- Local LLM inference and training
- GPU-accelerated computing
- See: [`nvidia-cuda.md`](nvidia-cuda.md), [`amd-rocm.md`](amd-rocm.md)

## Learning Path

### Beginner
1. Understand IOMMU groups in [`README.md`](README.md)
2. Configure basic GPU passthrough
3. Test with simple workloads

### Intermediate
1. Set up gaming VM in [`gaming.md`](gaming.md)
2. Configure CUDA/ROCm for AI workloads
3. Optimize performance settings

### Advanced
1. Multi-GPU passthrough configurations
2. Performance tuning and profiling
3. Troubleshoot complex issues in [`troubleshooting.md`](troubleshooting.md)

## GPU Comparison

| GPU Type | Gaming | AI/ML | Ease of Setup | Performance |
|------|---|-----|------|------|
| NVIDIA CUDA | Excellent | Excellent | Medium | Excellent |
| AMD ROCm | Good | Good | Medium | Very Good |
| Intel Arc | Good | Limited | Easy | Good |

## Related Documentation

- **Networking**: See [`networking/`](../networking/) for network configuration
- **Storage**: See [`gpu-passthrough/storage-strategy.md`](../gpu-passthrough/storage-strategy.md) for storage optimization
- **Automation**: See [`automation/`](../automation/) for VM automation

## Common Issues

| Issue | Solution |
|------|------|
| IOMMU not enabled | See [`troubleshooting.md`](troubleshooting.md) - Issue 1 |
| VFIO module not loading | See [`troubleshooting.md`](troubleshooting.md) - Issue 2 |
| Driver conflicts | See [`troubleshooting.md`](troubleshooting.md) - Issue 3 |
| Black screen in VM | See [`troubleshooting.md`](troubleshooting.md) - Issue 5 |
| Low performance | See [`troubleshooting.md`](troubleshooting.md) - Issue 6 |

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.

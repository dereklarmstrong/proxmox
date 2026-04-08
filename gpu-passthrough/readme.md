# GPU Passthrough Documentation

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## Overview

This section covers GPU passthrough configuration for Proxmox, enabling near-native GPU performance in VMs for gaming, AI/ML workloads, and other GPU-accelerated applications.

## Documentation Index

| Document | Description | Difficulty |
|----------|-------------|------------|
| [`README.md`](README.md) | GPU passthrough fundamentals and IOMMU configuration | Intermediate |
| [`NVIDIA_CUDA.md`](NVIDIA_CUDA.md) | CUDA setup for AI/ML workloads | Advanced |
| [`AMD_ROCM.md`](AMD_ROCM.md) | ROCm setup for AMD GPU computing | Advanced |
| [`GAMING.md`](GAMING.md) | Windows gaming VM configuration | Intermediate |
| [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Common issues and debugging | All levels |

### Quick Reference

- **Getting Started**: Start with the main [`README.md`](README.md)
- **AI/ML Workloads**: Follow [`NVIDIA_CUDA.md`](NVIDIA_CUDA.md) or [`AMD_ROCM.md`](AMD_ROCM.md)
- **Gaming Setup**: See [`GAMING.md`](GAMING.md)
- **Issues**: Check [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)

## Use Cases

### Gaming VMs
- Near-native performance for Windows gaming
- DirectX and Vulkan support
- Low latency for competitive gaming
- See: [`GAMING.md`](GAMING.md)

### AI/ML Workloads
- CUDA for NVIDIA GPUs (machine learning)
- ROCm for AMD GPUs (open source ML)
- Local LLM inference and training
- GPU-accelerated computing
- See: [`NVIDIA_CUDA.md`](NVIDIA_CUDA.md), [`AMD_ROCM.md`](AMD_ROCM.md)

## Learning Path

### Beginner
1. Understand IOMMU groups in [`README.md`](README.md)
2. Configure basic GPU passthrough
3. Test with simple workloads

### Intermediate
1. Set up gaming VM in [`GAMING.md`](GAMING.md)
2. Configure CUDA/ROCm for AI workloads
3. Optimize performance settings

### Advanced
1. Multi-GPU passthrough configurations
2. Performance tuning and profiling
3. Troubleshoot complex issues in [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)

## GPU Comparison

| GPU Type | Gaming | AI/ML | Ease of Setup | Performance |
|------|---|-----|------|------|
| NVIDIA CUDA | Excellent | Excellent | Medium | Excellent |
| AMD ROCm | Good | Good | Medium | Very Good |
| Intel Arc | Good | Limited | Easy | Good |

## Related Documentation

- **Networking**: See [`NETWORKING/`](../NETWORKING/) for network configuration
- **Storage**: See [`docs/storage_strategy.md`](../docs/storage_strategy.md) for storage optimization
- **Automation**: See [`AUTOMATION/`](../AUTOMATION/) for VM automation

## Common Issues

| Issue | Solution |
|------|------|
| IOMMU not enabled | See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - Issue 1 |
| VFIO module not loading | See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - Issue 2 |
| Driver conflicts | See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - Issue 3 |
| Black screen in VM | See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - Issue 5 |
| Low performance | See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - Issue 6 |

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.

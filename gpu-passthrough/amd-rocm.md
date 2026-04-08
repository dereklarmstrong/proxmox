# AMD ROCm Setup for AI Workloads

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers AMD ROCm setup for AI and machine learning workloads:

- **ROCm Stack Installation**: AMD's open-source compute platform
- **GPU-Accelerated Computing**: Leveraging AMD GPUs for ML workloads
- **HIP Programming**: AMD's CUDA-like programming model
- **Open-Source ML Tooling**: ROCm-based deep learning frameworks
- **Performance Optimization**: Maximizing AMD GPU utilization

## When You Need This

- Open-source ML stack preference
- AMD GPU hardware ownership
- Cost-sensitive deployments
- Avoiding vendor lock-in
- Custom GPU computing workloads

## Simpler Alternative

For most homelab users:
- Use NVIDIA CUDA (better tooling support)
- Use cloud GPU services
- Run smaller models on CPU
- Use pre-trained models without fine-tuning

---

## Prerequisites

### Supported AMD GPUs

ROCm supports the following GPU families:

| Series | Models | ROCm Support |
|-----|-----|-----|
| Radeon RX 7000 | RX 7900 XTX, RX 7900 XT | ROCm 5.6+ |
| Radeon RX 6000 | RX 6900 XT, RX 6800 XT | ROCm 5.4+ |
| Radeon RX 5000 | RX 5700 XT | ROCm 5.0+ |
| Radeon Instinct | MI250X, MI250, MI100 | ROCm 5.6+ |
| Radeon Pro | W7900, W6800 | ROCm 5.6+ |

### Host Requirements

```bash
# Verify AMD GPU
lspci | grep -i vga
# Output: AMD/ATI device

# Check ROCm support
cat /sys/class/drm/card0/device/uevent | grep DRM_DRIVER

# Ensure GPU is not used by host for display
# Consider using integrated GPU for host display
```

### VM Requirements

- GPU passthrough configured (see [GPU_PASSTHROUGH/README.md](GPU_PASSTHROUGH/README.md))
- At least 8GB RAM recommended
- 50GB+ storage for ROCm toolkit and libraries

---

## ROCm Installation

Install the AMD ROCm toolkit in your VM.

```bash
# For Ubuntu 22.04 VM
# Add ROCm repository
curl -fsSL https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor -o /usr/share/keyrings/rocm.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/5.6.1 jammy main" > /etc/apt/sources.list.d/rocm.list

# Update package list
apt update

# Install ROCm toolkit
apt install -y rocm-dev rocm-hip-sdk rocminfo

# Install additional components
apt install -y rocblas rocfft hipblas hipfft

# Verify installation
rocminfo

# Check ROCm version
rocminfo | grep "ROCm Version"

# Set environment variables
echo 'export PATH=/opt/rocm/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

> **⚠️ PITFALL**: ROCm has fewer supported GPUs than CUDA.

---

## PyTorch with ROCm

Install PyTorch with ROCm support.

```bash
# Install PyTorch with ROCm 5.6
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.6

# Verify ROCm support
python -c "import torch; print(f'ROCm available: {torch.version.hip}'); print(f'Device count: {torch.cuda.device_count()}')"

# Test GPU utilization
python << 'EOF'
import torch
import time

if torch.cuda.is_available():
    print(f"Using device: {torch.cuda.get_device_name(0)}")
    print(f"ROCm version: {torch.version.hip}")
    
    # Simple matrix multiplication test
    a = torch.rand(1000, 1000).cuda()
    b = torch.rand(1000, 1000).cuda()
    
    start = time.time()
    c = torch.matmul(a, b)
    end = time.time()
    
    print(f"Matrix multiplication time: {end - start:.4f} seconds")
else:
    print("ROCm not available!")
EOF
```

> **⚠️ PITFALL**: ROCm version must match PyTorch build.

---

## TensorFlow with ROCm

Install TensorFlow with ROCm support.

```bash
# Install TensorFlow with ROCm support
pip install tensorflow-rocm

# Verify installation
python -c "import tensorflow as tf; print(f'TensorFlow version: {tf.__version__}'); print(f'ROCm available: {tf.config.list_physical_devices(\"GPU\")}')"

# Test GPU utilization
python << 'EOF'
import tensorflow as tf
import time

gpus = tf.config.list_physical_devices('GPU')
if gpus:
    print(f"GPU found: {gpus[0].name}")
    
    # Simple matrix operation
    with tf.device('/GPU:0'):
        a = tf.random.uniform([1000, 1000])
        b = tf.random.uniform([1000, 1000])
        start = time.time()
        c = tf.matmul(a, b)
        end = time.time()
    
    print(f"Matrix multiplication time: {end - start:.4f} seconds")
else:
    print("No GPU found!")
EOF
```

> **⚠️ PITFALL**: ROCm version compatibility is critical.

---

## Docker with ROCm Support

Run GPU-accelerated containers with ROCm.

```bash
# Install Docker in VM
apt update
apt install -y docker.io docker-compose

# Install ROCm Docker support
apt install -y rocm-smi

# Test ROCm container
docker run --device /dev/kfd --device /dev/dri --group-add $(getent group render | cut -d: -f3) \
  rocm/rocm_pytorch:5.6.1-py3.10.11-ubuntu22.04 python -c "import torch; print(f'ROCm: {torch.version.hip}')"

# Run PyTorch container
docker run --device /dev/kfd --device /dev/dri --group-add $(getent group render | cut -d: -f3) \
  rocm/pytorch:rocm5.6_ubuntu22.04_py3.10 python -c "import torch; print(f'ROCm available: {torch.cuda.is_available()}')"

# Run TensorFlow container
docker run --device /dev/kfd --device /dev/dri --group-add $(getent group render | cut -d: -f3) \
  rocm/tensorflow:rocm5.6_ubuntu22.04 python -c "import tensorflow as tf; print(f'GPU: {tf.config.list_physical_devices(\"GPU\")}')"
```

> **⚠️ PITFALL**: Device permissions in containers need proper configuration.

---

## HIP Programming

HIP (Heterogeneous-Compute Interface for Portability) allows writing portable GPU code.

```bash
# Install HIP development tools
apt install -y hip-sdk hipblas rocblas

# Example HIP kernel
cat > /root/hello_hip.cpp << 'EOF'
#include <hip/hip_runtime.h>
#include <stdio.h>

#define N 1000000
#define THREADS_PER_BLOCK 256

__global__ void vectorAdd(float *a, float *b, float *c) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < N) {
        c[i] = a[i] + b[i];
    }
}

int main() {
    float *a, *b, *c;
    float *d_a, *d_b, *d_c;
    size_t size = N * sizeof(float);

    // Allocate host memory
    a = (float*)malloc(size);
    b = (float*)malloc(size);
    c = (float*)malloc(size);

    // Initialize vectors
    for (int i = 0; i < N; i++) {
        a[i] = i * 1.0f;
        b[i] = i * 2.0f;
    }

    // Allocate device memory
    hipMalloc((void**)&d_a, size);
    hipMalloc((void**)&d_b, size);
    hipMalloc((void**)&d_c, size);

    // Copy data to device
    hipMemcpy(d_a, a, size, hipMemcpyHostToDevice);
    hipMemcpy(d_b, b, size, hipMemcpyHostToDevice);

    // Launch kernel
    int threads = THREADS_PER_BLOCK;
    int blocks = (N + threads - 1) / threads;
    vectorAdd<<<blocks, threads>>>(d_a, d_b, d_c);

    // Copy result back
    hipMemcpy(c, d_c, size, hipMemcpyDeviceToHost);

    // Free device memory
    hipFree(d_a);
    hipFree(d_b);
    hipFree(d_c);

    // Verify result
    printf("First 5 results: ");
    for (int i = 0; i < 5; i++) {
        printf("%.1f ", c[i]);
    }
    printf("\n");

    free(a);
    free(b);
    free(c);

    return 0;
}
EOF

# Compile HIP code
hipcc hello_hip.cpp -o hello_hip

# Run
./hello_hip
```

> **⚠️ PITFALL**: HIP has a smaller community than CUDA.

---

## Model Fine-tuning with ROCm

Fine-tune models on AMD GPUs.

```bash
# Install fine-tuning dependencies
pip install transformers datasets accelerate peft

python << 'EOF'
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments, Trainer
from datasets import load_dataset
import torch

# Load model and tokenizer
model_name = "mistralai/Mistral-7B-v0.1"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    device_map="auto",  # Auto GPU placement
    torch_dtype=torch.float16
)

# Load dataset
dataset = load_dataset("json", data_files={"train": "data.json"}, split="train")

# Training arguments
training_args = TrainingArguments(
    output_dir="./fine-tuned-model",
    per_device_train_batch_size=1,
    gradient_accumulation_steps=4,
    learning_rate=2e-5,
    num_train_epochs=3,
    fp16=True,
    save_strategy="epoch"
)

# Train
trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=dataset,
    tokenizer=tokenizer
)

trainer.train()
trainer.save_model("./fine-tuned-model")
EOF
```

> **⚠️ PITFALL**: Requires significant GPU memory and time.

---

## Performance Monitoring

Monitor GPU utilization during workloads.

```bash
# Install ROCm monitoring tools
apt install -y rocm-smi

# Monitor GPU in real-time
rocm-smi

# Script for logging GPU stats
cat > /root/gpu_monitor.sh << 'EOF'
#!/bin/bash
# Log GPU utilization every 5 seconds
while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    rocm-smi --showtemp --showvddc --showmclk --showpwr --csv >> /var/log/gpu_usage.log
    sleep 5
done
EOF

# Run as service
cat > /etc/systemd/system/gpu-monitor.service << 'EOF'
[Unit]
Description=GPU Utilization Monitor
After=network.target

[Service]
ExecStart=/root/gpu_monitor.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl enable gpu-monitor
systemctl start gpu-monitor
```

> **⚠️ PITFALL**: Log files can grow large - set up log rotation.

---

## Summary

### ROCm vs CUDA Comparison

| Feature | ROCm | CUDA |
|-----|------|-----|
| Open Source | Yes | No |
| GPU Support | Limited | Extensive |
| Tooling | Good | Excellent |
| Community | Growing | Large |
| Documentation | Good | Excellent |
| Framework Support | Good | Excellent |
| Performance | Comparable | Comparable |

### ROCm Version Compatibility

| ROCm Version | PyTorch | TensorFlow | GPU Support |
|-----|-----|-----|---|
| 5.6 | 2.1+ | 2.13+ | RX 7000, RX 6000, MI250 |
| 5.4 | 2.0-2.1 | 2.10-2.13 | RX 6000, MI100 |
| 5.0 | 1.12-1.13 | 2.7-2.9 | RX 5000, Vega |

### Learning Path Progression

1. **Beginner**: Install ROCm, run basic GPU tests
2. **Intermediate**: PyTorch/TensorFlow with ROCm, Docker containers
3. **Advanced**: HIP programming, custom kernels
4. **Enterprise**: Multi-GPU training, distributed computing

### Real-World Job Skill Mapping

- **AI/ML Engineer**: ROCm, HIP, GPU-accelerated computing
- **Data Scientist**: ROCm, PyTorch, TensorFlow
- **DevOps Engineer**: Docker ROCm support, monitoring
- **Research Engineer**: Model fine-tuning, optimization

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.

# NVIDIA CUDA Setup for AI Workloads

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers NVIDIA CUDA setup for AI and machine learning workloads:

- **CUDA Toolkit Installation**: NVIDIA's parallel computing platform
- **GPU-Accelerated Computing**: Leveraging GPU for ML workloads
- **Docker with GPU Support**: Containerized GPU workloads
- **PyTorch/TensorFlow with CUDA**: Deep learning frameworks
- **Performance Optimization**: Maximizing GPU utilization

## When You Need This

- Local LLM inference and fine-tuning
- Machine learning model training
- GPU-accelerated data processing
- Computer vision applications
- Scientific computing workloads

## Simpler Alternative

For most homelab users:
- Use cloud GPU services (AWS, GCP, Lambda Labs)
- Run smaller models on CPU
- Use pre-trained models without fine-tuning
- Share GPU across multiple users

---

## Prerequisites

### Host Requirements

```bash
# Verify NVIDIA GPU support
nvidia-smi

# Check CUDA capability
cat /proc/driver/nvidia/version

# Ensure GPU is not used by host
lsmod | grep nvidia
# If loaded, blacklist in /etc/modprobe.d/blacklist-nvidia.conf
```

### VM Requirements

- GPU passthrough configured (see [GPU_PASSTHROUGH/README.md](GPU_PASSTHROUGH/README.md))
- At least 8GB RAM recommended
- 50GB+ storage for CUDA toolkit and models

---

## CUDA Toolkit Installation

Install the NVIDIA CUDA toolkit in your VM.

```bash
# For Ubuntu 22.04 VM
# Add NVIDIA repository
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb
sudo dpkg -i cuda-keyring_1.0-1_all.deb
sudo apt update

# Install CUDA toolkit (choose version based on your GPU)
# CUDA 12.x for newer GPUs
sudo apt install -y cuda-12-2

# CUDA 11.8 for older GPUs
# sudo apt install -y cuda-11-8

# Verify installation
nvcc --version
nvidia-smi

# Set environment variables
echo 'export PATH=/usr/local/cuda-12.2/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.2/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

> **⚠️ PITFALL**: Driver version mismatches between host and VM can cause issues.

---

## PyTorch with CUDA

Install PyTorch with CUDA support for deep learning.

```bash
# Install PyTorch with CUDA 12.1
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Verify CUDA support
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA version: {torch.version.cuda}'); print(f'Device count: {torch.cuda.device_count()}')"

# Test GPU utilization
python << 'EOF'
import torch
import time

if torch.cuda.is_available():
    print(f"Using device: {torch.cuda.get_device_name(0)}")
    
    # Simple matrix multiplication test
    a = torch.rand(1000, 1000).cuda()
    b = torch.rand(1000, 1000).cuda()
    
    start = time.time()
    c = torch.matmul(a, b)
    end = time.time()
    
    print(f"Matrix multiplication time: {end - start:.4f} seconds")
else:
    print("CUDA not available!")
EOF
```

> **⚠️ PITFALL**: CUDA version must match PyTorch build.

---

## TensorFlow with CUDA

Install TensorFlow with CUDA support.

```bash
# Install TensorFlow with CUDA support
pip install tensorflow-cpu  # CPU version
pip install nvidia-cudnn-cu12  # CUDA libraries

# Or install full CUDA version
pip install "tensorflow[and-cuda]"

# Verify installation
python -c "import tensorflow as tf; print(f'TensorFlow version: {tf.__version__}'); print(f'CUDA available: {tf.config.list_physical_devices(\"GPU\")}')"

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

> **⚠️ PITFALL**: CUDA/cuDNN version compatibility is critical.

---

## Docker with GPU Support

Run GPU-accelerated containers.

```bash
# Install Docker in VM
apt update
apt install -y docker.io docker-compose

# Install NVIDIA Container Toolkit
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | apt-key add -
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt update
apt install -y nvidia-container-toolkit

# Configure Docker for GPU support
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

# Test GPU container
docker run --rm --gpus all nvidia/cuda:12.2-base-ubuntu22.04 nvidia-smi

# Run PyTorch container
docker run --rm --gpus all pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"

# Run TensorFlow container
docker run --rm --gpus all tensorflow/tensorflow:2.13.0-gpu python -c "import tensorflow as tf; print(f'GPU: {tf.config.list_physical_devices(\"GPU\")}')"
```

> **⚠️ PITFALL**: NVIDIA Container Toolkit configuration can be tricky.

---

## Local LLM Inference

Run large language models locally.

```bash
# Install llama.cpp for CPU/GPU inference
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make -j$(nproc)

# Download a model (example: Llama 2 7B)
# wget https://huggingface.co/TheBloke/Llama-2-7B-GGUF/resolve/main/llama-2-7b.Q4_K_M.gguf

# Run inference with GPU
./llama-cli -m model.gguf -p "Hello, how are you?" -n 128 -t $(nproc)

# For Python-based inference
pip install llama-cpp-python
pip install transformers accelerate

python << 'EOF'
from transformers import AutoModelForCausalLM, AutoTokenizer

model_name = "TheBloke/Llama-2-7B-GGUF"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    device_map="auto",  # Auto GPU placement
    torch_dtype="auto"
)

response = model.generate(
    tokenizer("Hello, how are you?", return_tensors="pt").to(model.device),
    max_new_tokens=128
)
print(tokenizer.decode(response[0], skip_special_tokens=True))
EOF
```

> **⚠️ PITFALL**: Large models require significant VRAM.

---

## Model Fine-tuning

Fine-tune models on your data.

```bash
# Install fine-tuning dependencies
pip install transformers datasets accelerate peft bitsandbytes

python << 'EOF'
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments, Trainer
from datasets import load_dataset
import torch

# Load model and tokenizer
model_name = "mistralai/Mistral-7B-v0.1"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    device_map="auto",
    load_in_8bit=True,  # Quantization for memory efficiency
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
# Install monitoring tools
apt install -y nvtop  # NVIDIA system monitoring

# Monitor GPU in real-time
nvtop

# Script for logging GPU stats
cat > /root/gpu_monitor.sh << 'EOF'
#!/bin/bash
# Log GPU utilization every 5 seconds
while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    nvidia-smi --query-gpu=timestamp,name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits >> /var/log/gpu_usage.log
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

### CUDA Version Compatibility

| CUDA Version | PyTorch | TensorFlow | GPU Support |
|-----|-----|-----|-----|
| 12.1 | 2.1+ | 2.13+ | RTX 30/40, A100, H100 |
| 11.8 | 2.0-2.1 | 2.10-2.13 | RTX 20, T4, V100 |
| 11.1 | 1.12-1.13 | 2.7-2.9 | GTX 10, P100 |

### Learning Path Progression

1. **Beginner**: Install CUDA, run basic GPU tests
2. **Intermediate**: PyTorch/TensorFlow with GPU, Docker containers
3. **Advanced**: LLM inference, model fine-tuning
4. **Enterprise**: Multi-GPU training, distributed computing

### Real-World Job Skill Mapping

- **AI/ML Engineer**: All sections apply directly
- **Data Scientist**: CUDA, PyTorch, TensorFlow
- **DevOps Engineer**: Docker GPU support, monitoring
- **Research Engineer**: Model fine-tuning, optimization

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.

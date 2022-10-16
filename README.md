# Proxmox - Community Version Setup

[Proxmox](https://www.proxmox.com/en/) is a Open Source Alternative to popular hypervisors such as VMWare and Hyper-V.
 
 This will help setup the open source community version and install a dark theme as well.
 
# Installation
Follow the offical Proxmox bare metal installation guide below
https://www.proxmox.com/en/proxmox-ve/get-started

# Community Version Setup
Run the following command turn off the license warning message and install `dark mode`

> Download and Run community_setup.sh
```bash
wget https://raw.githubusercontent.com/dereklarmstrong/proxmox/main/community_setup.sh
bash community_setup.sh
```

# Setting up your first cloud init image
You can use the following command to help setup a cloud init deployment image

> Download and run setup help for the first cloud init image

```bash
wget https://raw.githubusercontent.com/dereklarmstrong/proxmox/main/setup_cloud_init_image.sh
bash setup_cloud_init_image.sh -h
```

# Personal Default Setup

This sets up the basic configs from a base proxmox install
This is a work in progress and is not complete

> use at your own risk

```bash
wget https://raw.githubusercontent.com/dereklarmstrong/proxmox/main/default_setup.sh
bash default_setup.sh
```
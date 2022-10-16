#!/usr/bin/env bash
# Author: Derek Armstrong
# Date: 2022-10-15
# Version: 0.1
# Description: This script will setup a new cloud-init image for Proxmox VE server
# GitHub: https://github.com/dereklarmstrong/proxmox
# Exit Codes:
#   0 - Success
#   1 - Error
#   10 - Parameter error: image id in use

# This script is used to setup a cloud init image for proxmox

# This script is based on the following:
# https://pve.proxmox.com/wiki/Cloud-Init_Support
# https://pve.proxmox.com/wiki/Cloud-Init_Support#Create_a_cloud-init_image

# This script is based on the following:
usage="-------------------------------
usage: setup_cloud_init_image.sh -i <image_id> -n <image_name> -s <size> -d <download url> -m <int: memory in MB> -c <int: cpu count> -u <user> -p <password> -k <ssh key> -h <help>
example: setup_cloud_init_image.sh -n cloud-init -s 10G -d https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img -m 2048 -c 2 -u root -p password -k ~/.ssh/id_rsa.pub

Ubuntu Downloads: http://cloud-images.ubuntu.com/
Debian Downloads: https://cdimage.debian.org/cdimage/openstack/
CentOS Downloads: https://cloud.centos.org/centos/8/x86_64/images/
Fedora Downloads: https://download.fedoraproject.org/pub/fedora/linux/releases/34/Cloud/x86_64/images/
openSUSE Downloads: https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.2/images/
Alpine Downloads: https://alpinelinux.org/downloads/
Arch Downloads: https://www.archlinux.org/download/
Gentoo Downloads: https://wiki.gentoo.org/wiki/Project:Cloud/Amazon_EC2_Images
FreeBSD Downloads: https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/
CoreOS Downloads: https://stable.release.core-os.net/amd64-usr/current/
Clear Linux Downloads: https://download.clearlinux.org/releases/current/clear/
SUSE Downloads: https://download.opensuse.org/repositories/Cloud:/Images:/SLE_15_SP2/images/
-------------------------------
"

# Set Script Start Time
start_time=$(date +%s)

# Set Script Name variable
script_name=$(basename "$0")

# Set Default Variables
image_id=9000
image_name="cloud-init-ubuntu-20-04-lts"
image_size="10G"
image_url="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
image_memory=2048
image_cpu=2
image_user="root"
image_password="change_me"

# Parse arguments
while getopts "n:s:d:u:p:k:h" opt; do
  case $opt in
    i) image_id=$OPTARG
    if ! [[ "$image_id" =~ ^[0-9]+$ ]]; then
      echo "Error: image id must be an integer"
      exit 1
    fi
    ;;
    n) image_name="$OPTARG"
    if [[ -z "$image_name" ]]; then
      echo "Error: image name cannot be empty"
      exit 1
    fi
    ;;
    s) size="$OPTARG"
    if ! [[ "$size" =~ ^[0-9]+[G|M]$ ]]; then
      echo "Error: size must be an integer followed by G or M"
      exit 1
    fi
    ;;
    d) download_url="$OPTARG"
    if ! [[ "$download_url" =~ ^https?://.* ]]; then
      echo "Error: download url must start with http or https"
      exit 1
    fi
    ;;
    m) memory_mb="$OPTARG"
    if ! [[ "$memory_mb" =~ ^[0-9]$ ]]; then
      echo "Error: memory must be an integer and is in MB"
      exit 1
    fi
    ;;
    c) cpu_count="$OPTARG"
    if [[ $cpu_count =~ ^[0-9]+$ ]]; then
      image_cpu="$cpu_count"
    else
      echo "CPU count must be an integer"
      exit 1
    fi
    ;;
    u) user="$OPTARG"
    if [[ -z "$user" ]]; then
      echo "Error: user cannot be empty"
      exit 1
    fi
    ;;
    p) password="$OPTARG"
    if [[ -z "$password" ]]; then
      echo "Error: password cannot be empty"
      exit 1
    fi
    ;;
    k) ssh_key="$OPTARG"
    if [[ -z "$ssh_key" ]]; then
      echo "Error: ssh key cannot be empty"
      exit 1
    fi
    ;;
    h) echo "$usage"
       exit 0
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done


# Check if required arguments are set
# If user passes any parameters print execution arguments else print default arguments
if [[ $# -gt 0 ]]; then
  echo "Execution Arguments:"
  echo "  image_id: $image_id"
  echo "  image_name: $image_name"
  echo "  image_size: $image_size"
  echo "  image_url: $image_url"
  echo "  image_memory: $image_memory"
  echo "  image_cpu: $image_cpu"
  echo "  image_user: $image_user"
  echo "  image_password: $image_password"
  echo "  ssh_key: $ssh_key"
else
  echo "Using Default Argument Values:"
  echo "  image_id: $image_id"
  echo "  image_name: $image_name"
  echo "  image_size: $image_size"
  echo "  image_url: $image_url"
  echo "  image_memory: $image_memory"
  echo "  image_cpu: $image_cpu"
  echo "  image_user: $image_user"
  echo "  image_password: $image_password"
  echo "  ssh_key: $ssh_key"
fi

# check if VM Image exists already
# if $image_id exist in /etc/pve/.vmlist
if grep -q "$image_id" /etc/pve/.vmlist; then
  echo "Error: VM Image with ID $image_id already exists"
  exit 1
fi

# Get the cloud init image name from download URL
cloudinit_image_file_name=$(echo $image_url | awk -F "/" '{print $NF}')

# Check to see if the cloud init image already exists
if [ ! -f $cloudinit_image_file_name ]; then
    # Download the cloud init image
    echo "Downloading $cloudinit_image_file_name"
    wget -O $cloudinit_image_file_name $image_url
    # Check if the image was downloaded successfully
    if [ ! -f $cloudinit_image_file_name ]; then
        echo "Failed to download $cloudinit_image_file_name"
        exit 1
    fi
else
    echo "$cloudinit_image_file_name already exists skipping download"
fi

# Create the cloud init image
echo "Creating cloud init image"
qm create $image_id --memory $image_memory --cores $image_cpu --name $image_name --net0 virtio,bridge=vmbr0
if [ $? -ne 0 ]; then
    echo "Failed to create cloud init image"
    exit 1
fi

# Import the downloaded Ubuntu disk to local-lvm storage
echo "Importing $cloudinit_image_file_name to local-lvm storage"
qm importdisk $image_id $cloudinit_image_file_name local-lvm
if [ $? -ne 0 ]; then
    echo "Failed to import $cloudinit_image_file_name to local-lvm storage"
    exit 1
fi

# Attach the new disk to the vm as a scsi drive on the scsi controller
echo "Attaching $cloudinit_image_file_name to vm as scsi drive"
qm set $image_id --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$image_id-disk-0
if [ $? -ne 0 ]; then
    echo "Failed to attach $cloudinit_image_file_name to vm as scsi drive"
    exit 1
fi

# Add cloud init drive
echo "Adding cloud init drive"
qm set $image_id --ide2 local-lvm:cloudinit
if [ $? -ne 0 ]; then
    echo "Failed to add cloud init drive"
    exit 1
fi

# Make the cloud init drive bootable and restrict BIOS to boot from disk only
echo "Making cloud init drive bootable"
qm set $image_id --boot c --bootdisk scsi0
if [ $? -ne 0 ]; then
    echo "Failed to make cloud init drive bootable"
    exit 1
fi

# Resize the cloud init drive if specified
echo "Resizing cloud init drive to $image_size"
if [ ! -z "$size" ]; then
    qm resize $image_id scsi0 $size
    if [ $? -ne 0 ]; then
        echo "Failed to resize cloud init drive to $image_size"
        exit 1
    fi
fi

# If a user was specified, set the user
echo "Setting user to $image_user"
if [ ! -z "$user" ]; then
    qm set $image_id --ciuser $user
    if [ $? -ne 0 ]; then
        echo "Failed to set user to $image_user"
        exit 1
    fi
fi

# If a password was specified, set the password
echo "Setting password to default password"
if [ ! -z "$password" ]; then
    echo "Setting password to provided password"
    qm set $image_id --cipassword $password
    if [ $? -ne 0 ]; then
        echo "Failed to set password to $image_password"
        exit 1
    fi
fi

# If a ssh key was specified, set the ssh key
if [ ! -z "$ssh_key" ]; then
    echo "Setting ssh key to provided ssh key"
    qm set $image_id --sshkey $ssh_key
    if [ $? -ne 0 ]; then
        echo "Failed to set ssh key to $ssh_key"
        exit 1
    fi
fi

# Add serial console
echo "Adding serial console"
qm set $image_id --serial0 socket --vga serial0
if [ $? -ne 0 ]; then
    echo "Failed to add serial console"
    exit 1
fi

#######################
# DO NOT START THE VM #
#######################

# Create template
echo "Creating template"
qm template $image_id
if [ $? -ne 0 ]; then
    echo "Failed to create template"
    exit 1
fi

# Setup Complete
echo "################################"
echo "# DO NOT START THE TEMPLATE VM #"
echo "################################"
echo "$image_name is ready use"
echo "=============================================="
echo "To clone the template from CLI, run the following command:"
echo "qm clone $image_id <new_vm_id> --name <new_vm_name> --full"
echo "=================== OR ======================="
echo "To clone the template from the web interface, click on the template and click clone"
echo "Check the full clone checkbox and click clone"
echo "=============================================="


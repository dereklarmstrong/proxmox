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
#   11 - Parameter error: image name in use

# This script is used to setup a cloud init image for proxmox

# This script is based on the following:
# https://pve.proxmox.com/wiki/Cloud-Init_Support
# https://pve.proxmox.com/wiki/Cloud-Init_Support#Create_a_cloud-init_image

# This script is based on the following:
usage = "-------------------------------
usage: setup_cloud_init_image.sh -i <image_id> -n <image_name> -s <size> -d <download url> -m <memory mb> -c <cpu count> -u <user> -p <password> -k <ssh key>
example: setup_cloud_init_image.sh -n cloud-init -s 10G -d https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img -u root -p password -k ~/.ssh/id_rsa.pub

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


# Set default values
image_id = "9000"
image_size = "10G"
image_url = "https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
image_memory = "2048"
image_cpu = "2"
image_user = "root"
image_password = "change_me"


# Parse arguments
while getopts "n:s:d:u:p:k:" opt; do
  case $opt in
    i) image_id="$OPTARG"
    ;;
    n) image_name="$OPTARG"
    ;;
    s) size="$OPTARG"
    ;;
    d) download_url="$OPTARG"
    ;;
    m) memory_mb="$OPTARG"
    ;;
    c) cpu_count="$OPTARG"
    ;;
    u) user="$OPTARG"
    ;;
    p) password="$OPTARG"
    ;;
    k) ssh_key="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done


# Check if required arguments are set
# If user did not pass any parameters send message that all defaults are being used
if [ $# -eq 0 ]; then
    echo "No arguments supplied, using defaults"
    echo "Image Password: $image_password"
fi
# print image info
echo "Image ID: $image_id"
echo "Image Name: $image_name"
echo "Image Size: $image_size"
echo "Image URL: $image_url"
echo "Image Memory: $image_memory"
echo "Image CPU: $image_cpu"
echo "Image User: $image_user"


# get the image name from the image_url and remove the extension
image_name = $( basename $image_url | cut -d. -f1 )

# check if image_id is in use
image_id_in_use = $( pvesh get /nodes/localhost/storage/local/content | grep -oP "(?<=vmid\":\s\")[0-9]+" | grep -w $image_id )
# Exit if image_id is in use
if [ ! -z $image_id_in_use ]; then
    echo "Image ID $image_id is already in use"
    exit 10
fi

# check if image_name is in use
image_name_in_use = $( pvesh get /nodes/localhost/storage/local/content | grep -oP "(?<=vmid\":\s\")[0-9]+" | grep -w $image_name )
# Exit if image_name is in use
if [ ! -z $image_name_in_use ]; then
    echo "Image name $image_name is already in use"
    exit 11
fi

# Get the cloud init image name from download URL
cloudinit_image_name=$(echo $image_url | awk -F "/" '{print $NF}')

# Download the cloud init image
echo "Downloading $cloudinit_image_name"
wget -O $cloudinit_image_name $cloudinit_image_download

# Create the cloud init image
echo "Creating cloud init image"
qm create $image_id --memory $memory_mb --core $cpu_count --name $image_name --net0 virtio,bridge=vmbr0

# Import the downloaded Ubuntu disk to local-lvm storage
echo "Importing $cloudinit_image_name to local-lvm storage"
qm importdisk $image_id $cloudinit_image_name local-lvm

# Attach the new disk to the vm as a scsi drive on the scsi controller
echo "Attaching $cloudinit_image_name to vm as scsi drive"
qm set $image_id --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$image_id-disk-0

# Add cloud init drive
echo "Adding cloud init drive"
qm set $image_id --ide2 local-lvm:cloudinit

# Make the cloud init drive bootable and restrict BIOS to boot from disk only
echo "Making cloud init drive bootable"
qm set $image_id --boot c --bootdisk scsi0

# Resize the cloud init drive if specified
echo "Resizing cloud init drive to $image_size"
if [ ! -z "$size" ]; then
    qm resize $image_id scsi0 $size
fi

# If a user was specified, set the user
echo "Setting user to $image_user"
if [ ! -z "$user" ]; then
    qm set $image_id --user $user
fi

# If a password was specified, set the password
echo "Setting password to default password"
if [ ! -z "$password" ]; then
    echo "Setting password to provided password"
    qm set $image_id --password $password
fi

# If a ssh key was specified, set the ssh key
if [ ! -z "$ssh_key" ]; then
    echo "Setting ssh key to provided ssh key"
    qm set $image_id --sshkey $ssh_key
fi

# Add serial console
echo "Adding serial console"
qm set $image_id --serial0 socket --vga serial0

#######################
# DO NOT START THE VM #
#######################

# Create template
echo "Creating template"
qm template $image_id

# Setup Complete
echo "$image_name is ready use in the web interface"
echo "To clone the template from CLI, run the following command:"
echo "qm clone $image_id <new_vm_id> --name <new_vm_name> --full"



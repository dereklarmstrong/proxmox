#!/usr/bin/env bash
# Author: Derek Armstrong
# Date: 2022-10-15
# Version: 1.0
# Description: This script will create a full clone of a VM
# GitHub: https://github.com/dereklarmstrong/proxmox
#

# This script will create a full clone of a VM
# this is a work in progress and is not complete
# use at your own risk

# setup help argument
usage="-------------------------------
usage: create_vm_full_clone.sh -s <source_vm_id> -d <destination_vm_id> -n <destination_vm_name> -i <destination_vm_ip_address> -g <destination_vm_gateway> -m <destination_vm_netmask> -h <help>
-------------------------------
-s <source_vm_id> - The ID of the source VM
-d <destination_vm_id> - The ID of the destination VM
-n <destination_vm_name> - The name of the destination VM
-i <destination_vm_ip> - The IP address of the destination VM
-g <destination_vm_gateway> - The gateway of the destination VM
-------------------------------
"


# Parse arguments
while getopts "s:d:n:i:g:h" opt; do
  case $opt in
    s) source_vm_id=$OPTARG
        # if source_vn_id is not integer
        if ! [[ "$source_vm_id" =~ ^[0-9]+$ ]]; then
          echo "Error: source_vm_id must be an integer"
          exit 1
        fi
        ;;
    d) destination_vm_id=$OPTARG
        # if destination_vm_id is not integer
        if ! [[ "$destination_vm_id" =~ ^[0-9]+$ ]]; then
          echo "Error: destination_vm_id must be an integer"
          exit 1
        fi
        ;;
    n) destination_vm_name=$OPTARG
    # if destination_vm_name is not string, contains letters, numbers, and hyphens
    if ! [[ "$destination_vm_name" =~ ^[a-zA-Z0-9-]+$ ]]; then
      echo "Error: destination_vm_name must be a string, contain letters, numbers, and hyphens"
      exit 1
    fi
    ;;
    i) destination_vm_ip=$OPTARG
    # if destination_vm_ip is not string
    if ! [[ "$destination_vm_ip" =~ ^[0-9.]+$ ]]; then
      echo "Error: destination_vm_ip must be a string"
      exit 1
    fi
    ;;
    g) destination_vm_gateway=$OPTARG
    # if destination_vm_gateway is not string
    if ! [[ "$destination_vm_gateway" =~ ^[0-9.]+$ ]]; then
      echo "Error: destination_vm_gateway must be a string"
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

# check if source VM Image exists proxmox
# if $source_vm_id exist in /etc/pve/.vmlist
if grep -q "$source_vm_id" /etc/pve/.vmlist; then
  echo "Source VM Image exists"
else
  echo "Error: Source VM Image does not exist"
  exit 1
fi


# check if Destination VM Image exists proxmox
# if $destination_vm_id exist in /etc/pve/.vmlist
if grep -q "$destination_vm_id" /etc/pve/.vmlist; then
    echo "Error: Destination VM Image already exists"
    exit 1
fi

# Clone the VM with Full Clone
echo "Cloning the VM with Full Clone"
pvesh create /nodes/pve/qemu/$source_vm_id/clone -newid $destination_vm_id -name $destination_vm_name -full 1

# Setup the VM
echo "Setting up the VM"

# Setup the SSH Keys
qm set $destination_vm_id --sshkey ~/.ssh/id_rsa.pub

# Setup the IP Address if provided
if [ -z "$destination_vm_ip" ]; then
  echo "Using DHCP network configuration"
else
  # If Gateway is not set calculate the gateway from the IP Address
  if [ -z "$destination_vm_gateway" ]; then
    destination_vm_gateway=$(echo $destination_vm_ip | cut -d'.' -f1-3).1
    echo "Gateway not provided, Using calculated gateway: $destination_vm_gateway"
  fi
  echo "Using Static IP Address: $destination_vm_ip/24, gateway: $destination_vm_gateway"
  qm set $destination_vm_id --ipconfig0 ip=$destination_vm_ip/24,gw=$destination_vm_gateway
  # Check if IP was set successfully
  if [ $? -eq 0 ]; then
      echo "Successfully set IP Address"
  else
      echo "Error: Failed to set IP Address"
      exit 1
  fi
fi

# Start the VM
echo "Starting the VM"
qm start $destination_vm_id
if [ $? -eq 0 ]; then
  echo "VM Started"
else
  echo "Error: VM failed to start"
  exit 1
fi

# Wait for the VM to start
echo "Waiting for the VM to start"
# print a dot every 5 seconds until the VM is running or 60 seconds has passed
for i in {1..12}; do
  sleep 5
  echo -n "."
  # if the VM is running
  if [ "$(qm status $destination_vm_id | grep status | cut -d':' -f2 | tr -d ' ')" = "running" ]; then
    echo "== VM is running =="
    break
  fi
done

# if the VM is not running
if [ "$(qm status $destination_vm_id | grep status | cut -d':' -f2 | tr -d ' ')" != "running" ]; then
  echo "Error: VM did not start"
  exit 1
fi

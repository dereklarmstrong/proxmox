#!/usr/bin/env bash
# Author: Derek Armstrong
# Date: 2022-10-15
# Version: 1.0
# Description: This script will create my base set of VMs
# GitHub: https://github.com/dereklarmstrong/proxmox
#

# This script will create my base set of VMs

# setup help argument
usage="-------------------------------
usage: deploy_base_vm_set.sh -h <help>
-------------------------------
"

# Parse arguments
while getopts "h" opt; do
  case $opt in
    h) echo "$usage"
       exit 0
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

# Download the create_vm_full_clone.sh script if it does not exist
if [ ! -f create_vm_full_clone.sh ]; then
  wget https://raw.githubusercontent.com/dereklarmstrong/proxmox/main/scripts/create_vm_full_clone.sh
fi

# Download ssh keys from github
if [ ! -f ~/.ssh/github_rsa.pub ]; then
  wget https://raw.githubusercontent.com/dereklarmstrong/proxmox/main/scripts/download_github_keys.sh
  bash download_github_keys.sh
fi


# Setup VM Deployments
# usage: create_vm_full_clone.sh -s <source_vm_id> -d <destination_vm_id> -n <destination_vm_name> -i <destination_vm_ip_address> -g <destination_vm_gateway> -m <destination_vm_netmask> -h <help>

# dev box setup
bash create_vm_full_clone.sh -s 9000 -d 201 -n dev1 -i 192.168.1.21
bash create_vm_full_clone.sh -s 9000 -d 202 -n dev2 -i 192.168.1.22

# load balancer setup
bash create_vm_full_clone.sh -s 9000 -d 301 -n lb1 -i 192.168.1.8
bash create_vm_full_clone.sh -s 9000 -d 302 -n lb2 -i 192.168.1.9

# rancher nodes
bash create_vm_full_clone.sh -s 9000 -d 501 -n rancher-node1 -i 192.168.1.41
bash create_vm_full_clone.sh -s 9000 -d 502 -n rancher-node2 -i 192.168.1.42
bash create_vm_full_clone.sh -s 9000 -d 503 -n rancher-node3 -i 192.168.1.43
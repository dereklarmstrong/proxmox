#!/usr/bin/env bash

# Author: Derek Armstrong
# Date: 2022-10-15
# Version: 0.1
# Description: This script is my personal setup script for a new Proxmox VE server
# GitHub: https://github.com/dereklarmstrong/proxmox

# This sets up the basic configs from a base proxmox install
# this is a work in progress and is not complete
# use at your own risk

# Example usage:
# bash default_setup.sh

# setup help argument
usage="-------------------------------
usage: default_setup.sh
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

# remove the license warning from the web interface
echo "Removing license warning from web interface"
# download file if it doesn't exist
if [ ! -f community_setup.sh ]; then
  wget https://raw.githubusercontent.com/dereklarmstrong/proxmox/main/scripts/community_setup.sh
fi
bash community_setup.sh

# Ask if we should deploy the base VM set
read -p "Do you want to deploy the default ubuntu cloud init image? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "Deploying default ubuntu cloud init image"
  echo ""
  read -p "Enter Default Password for Cloud Init Image: " -s default_password
  # Download Scripts
  # check if file exists and if not download it
  if [ ! -f download_github_keys.sh ]; then
    wget https://raw.githubusercontent.com/dereklarmstrong/proxmox/main/scripts/download_github_keys.sh
  fi
  if [ ! -f setup_cloud_init_image.sh ]; then
    wget https://raw.githubusercontent.com/dereklarmstrong/proxmox/main/scripts/setup_cloud_init_image.sh
  fi
  if [ ! -f deploy_base_vm_set.sh ]; then
    wget https://raw.githubusercontent.com/dereklarmstrong/proxmox/main/scripts/deploy_base_vm_set.sh
  fi

  # Confirm downloads
  if [ -f download_github_keys.sh ] && [ -f setup_cloud_init_image.sh ] && [ -f deploy_base_vm_set.sh ]; then
    echo "All scripts downloaded successfully"
  else
    echo "Error downloading scripts"
    exit 1
  fi
  
  # Download Github SSH Keys
  bash download_github_keys.sh

  # setup cloud init images
  # Example usage:
  # setup_cloud_init_image.sh -i <image_id> \
  #                           -n <image_name> \
  #                           -s <size> \
  #                           -d <download url> \
  #                           -m <int: memory in MB> \
  #                           -c <int: cpu count> \
  #                           -u <user> \
  #                           -p <password> \
  #                           -k <ssh key>
  # Example:
  # Deploy Cloud Init Image
  echo "Deploy Cloud Init Image"
  bash setup_cloud_init_image.sh -i 9000 -n ubuntu-20.04-cloud-init -s 20G -d https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img -m 2048 -c 2 -u derek -p $default_password -k ~/.ssh/github_rsa.pub
  
  # Ask if we should deploy the base VM set
  read -p "Do you want to deploy the base VM set? (y/n) " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    echo "Deploying base VM set"
    bash deploy_base_vm_set.sh
  else
    echo "Skipping base VM set"
  fi
fi

# Setup Complete
echo "== Setup Complete =="

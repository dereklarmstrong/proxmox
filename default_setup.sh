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

wget https://raw.githubusercontent.com/dereklarmstrong/proxmox/main/community_setup.sh
bash community_setup.sh
wget https://raw.githubusercontent.com/dereklarmstrong/proxmox/main/setup_cloud_init_image.sh
bash setup_cloud_init_image.sh

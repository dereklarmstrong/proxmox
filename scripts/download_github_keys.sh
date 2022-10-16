#!/usr/bin/env bash
# Author: Derek Armstrong
# Date: 2022-10-15
# Version: 1.0
# Description: This script will download my public keys from GitHub
# GitHub: https://github.com/dereklarmstrong/proxmox
#

# This script will download my public keys from GitHub

# Download SSH Public Keys from GitHub
curl https://github.com/dereklarmstrong.keys > ~/.ssh/github_rsa.pub

# Add SSH Public Keys to authorized_keys file
cat ~/.ssh/github_rsa.pub >> ~/.ssh/authorized_keys


#!/usr/bin/env bash
# Author: Derek Armstrong
# Date: 2022-10-15
# Version: 1.0
# Description: This script will destroy a VM
# GitHub: 

# This script will destroy a VM


# setup help argument
usage="-------------------------------
usage: destroy_vm.sh -i <vm_id> -h <help>
-------------------------------
-i <vm_id> - The ID of the VM to destroy (required) - Example: 100,101,102
-------------------------------
"

# Parse arguments
while getopts "i:h" opt; do
  case $opt in
    i) vm_id=$OPTARG
        # if vm_id is a comma separated list
        if [[ "$vm_id" =~ "," ]]; then
          # split vm_id into array
          IFS=',' read -r -a vm_id_array <<< "$vm_id"
          # loop through vm_id_array
          for vm_id in "${vm_id_array[@]}"; do
            # if vm_id is not integer
            if ! [[ "$vm_id" =~ ^[0-9]+$ ]]; then
              echo "Error: vm_id must be an integer"
              exit 1
            fi
          done
        fi
        # if vm_id is a space separated list
        if [[ "$vm_id" =~ " " ]]; then
          # split vm_id into array
          IFS=' ' read -r -a vm_id_array <<< "$vm_id"
          # loop through vm_id_array
          for vm_id in "${vm_id_array[@]}"; do
            # if vm_id is not integer
            if ! [[ "$vm_id" =~ ^[0-9]+$ ]]; then
              echo "Error: vm_id must be an integer"
              exit 1
            fi
          done
        fi
        ;;
    h) echo "$usage"
        exit 0
        ;;
    \?) echo "Invalid option -$OPTARG" >&2
        exit 1
        ;;
  esac
done

# if vm_id is not set
if [ -z "$vm_id" ]; then
  echo "Error: vm_id is not set"
  exit 1
fi

# loop through vm_id_array and destroy VMs
for vm_id in "${vm_id_array[@]}"; do
  # destroy VM
  echo "Destroying VM $vm_id"
  # if VM is running stop it
  if [ "$(qm status $vm_id | grep running)" ]; then
      echo "Stopping VM $vm_id"
      qm stop $vm_id
  fi
  qm destroy $vm_id
  if [ $? -eq 0 ]; then
    echo "VM $vm_id destroyed"
  else
    echo "Error: VM $vm_id not destroyed"
    exit 1
  fi
done

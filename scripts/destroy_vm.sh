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
        # if vm_id is not integer
        if ! [[ "$vm_id" =~ ^[0-9]+$ ]]; then
          echo "Error: vm_id must be an integer"
          exit 1
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

# if vm_id contains "," then split into array and loop through array
if [[ "$vm_id" == *","* ]]; then
  IFS=',' read -ra vm_id_array <<< "$vm_id"
  for vm_id in "${vm_id_array[@]}"; do
    # destroy vm
    echo "Destroying VM $vm_id"
    qm stop $vm_id
    qm destroy $vm_id
  done
else
  # destroy vm
  echo "Destroying VM $vm_id"
  qm stop $vm_id
  qm destroy $vm_id
fi
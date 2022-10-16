# Author: Derek Armstrong
# Date: 2022-10-15
# Version: 1.0
# Description: This script will setup a new Proxmox VE server
# GitHub: https://github.com/dereklarmstrong/proxmox

# This sets up the basic configs from a base proxmox install
# this is a work in progress and is not complete
# use at your own risk

# Example usage:
# bash community_setup.sh

# setup help argument
usage="-------------------------------
usage: community_setup.sh
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


echo "Removing license warning from web interface"
# create a dated backup of the original file
cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak.$(date +%Y-%m-%d-%H-%M-%S)
# remove the license warning from the web interface
sed -i.backup -z "s/res === null || res === undefined || \!res || res\n\t\t\t.data.status.toLowerCase() \!== 'active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && systemctl restart pveproxy.service


echo "Setting up community repo"
# create a dated backup of the original file
cp /etc/apt/sources.list.d/pve-no-subscription.list /etc/apt/sources.list.d/pve-no-subscription.list.bak.$(date +%Y-%m-%d-%H-%M-%S)
# setup community repo
echo "deb http://download.proxmox.com/debian/pve buster pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list


echo "Removing pve-enterprise repo"
# create a dated backup of the original file
cp /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.bak.$(date +%Y-%m-%d-%H-%M-%S)
# remove the pve-enterprise repo by commenting it out
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list

# update the system
echo "Updating system"
apt update && apt upgrade -y

# Setup dark theme
bash <(curl -s https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/master/PVEDiscordDark.sh)

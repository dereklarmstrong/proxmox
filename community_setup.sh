# Author: Derek Armstrong
# Date: 2022-10-15
# Version: 0.1
# Description: This script will setup a new Proxmox VE server
# GitHub: https://github.com/dereklarmstrong/proxmox

# This sets up the basic configs from a base proxmox install
# this is a work in progress and is not complete
# use at your own risk

# Example usage:
# bash community_setup.sh

# setup help argument
usage = "-------------------------------
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

# remove the license warning from the web interface
echo "Removing the license warning from the web interface"
cd /usr/share/javascript/proxmox-widget-toolkit/
# backup the original file
cp proxmoxlib.js proxmoxlib.js.bak
# replace only the first instance of "Ext.Msg.show" with "void"
sed -i 's/Ext.Msg.show/void/' proxmoxlib.js
# restart pveproxy
systemctl restart pveproxy.service


# setup community repo
echo "" >> /etc/apt/sources.list
echo "# Not for production use" >> /etc/apt/sources.list
echo "deb http://download.proxmox.com/debian buster pve-no-subscription" >> /etc/apt/sources.list
cd /etc/apt/sources.list.d
# backup the existing file
cp pve-enterprise.list pve-enterprise.list.bak
# comment out the line that starts with "deb"
sed -i 's/^deb/#deb/' pve-enterprise.list

# Update the system
$ apt update -y

# Distro upgrade
apt dist-upgrade -y 

# Setup dark theme
bash <(curl -s https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/master/PVEDiscordDark.sh ) install

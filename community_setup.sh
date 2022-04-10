# Author: Docmeir
# Date: 2022/04/10


# this sets up the basic configs from a base proxmox install to the free community version


# turn off license warning
cd /usr/share/javascript/proxmox-widget-toolkit/
cp proxmoxlib.js proxmoxlib.js.bak
# TODO: need to find another way of replacing this as it occurs multiple times
#sed '/s/"Ext.Msg.show"/void/g' -i proxmoxlib.js
systemctl restart pveproxy.service


# setup community repo
echo "" >> /etc/apt/sources.list
echo "# Not for production use" >> /etc/apt/sources.list
echo "deb http://download.proxmox.com/debian buster pve-no-subscription" >> /etc/apt/sources.list
cd /etc/apt/sources.list.d
cp pve-enterprise.list pve-enterprise.list.bak
# TODO: need to find another way of replacing this as it occurs multiple times
#sed -i '/s/deb https://enterprise.proxmox.com/debian/pve buster pve-enterprise/#deb https://enterprise.proxmox.com/debian/pve buster pve-enterprise/g' pve-enterprise.list

# Update the system
$ apt update -y

# Distro upgrade
apt dist-upgrade -y 

# Setup dark theme
bash <(curl -s https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/master/PVEDiscordDark.sh ) install

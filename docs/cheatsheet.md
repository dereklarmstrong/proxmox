# Proxmox CLI Cheatsheet

## VM (qm)
- List VMs: `qm list`
- Create VM: `qm create <id> --name <name> --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0`
- Start/Stop: `qm start <id>` / `qm stop <id>`
- Shutdown/Reboot: `qm shutdown <id>` / `qm reboot <id>`
- Console: `qm terminal <id>`
- Snapshot: `qm snapshot <id> <snapname>`; rollback `qm rollback <id> <snapname>`; delete `qm delsnapshot <id> <snapname>`
- Clone template: `qm clone <template_id> <new_id> --name <name> --full`
- Cloud-init: `qm set <id> --ciuser ubuntu --sshkey ~/.ssh/id_rsa.pub --ipconfig0 ip=192.168.1.50/24,gw=192.168.1.1`
- Migrate: `qm migrate <id> <target-node> --online 1`

## Containers (pct)
- List CTs: `pct list`
- Create: `pct create <id> <template> --hostname <name> --net0 name=eth0,bridge=vmbr0,ip=dhcp`
- Start/Stop: `pct start <id>` / `pct stop <id>`
- Console: `pct enter <id>`
- Resize disk: `pct resize <id> rootfs +10G`

## Templates
- List LXC templates: `pveam available`
- Download LXC template: `pveam download local debian-12-standard_12.0-1_amd64.tar.zst`

## Backups
- Backup VM/CT: `vzdump <id> --storage local --mode snapshot --compress zstd`
- Restore VM: `qmrestore /var/lib/vz/dump/vzdump-qemu-<id>.vma.zst <new_id> --storage local-lvm`
- Restore CT: `vzrestore /var/lib/vz/dump/vzdump-lxc-<id>.tar.zst <new_id>`

## Storage
- List storages: `pvesm status`
- Add NFS: `pvesm add nfs <id> <server>:<path> --export <path> --path /mnt/pve/<id> --content images,iso,backup`

## Misc
- Check version: `pveversion -v`
- Services: `systemctl status pvedaemon.service pveproxy.service pvestatd.service`

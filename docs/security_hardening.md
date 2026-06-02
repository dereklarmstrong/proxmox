# Security Hardening for Proxmox VE 8.x

## SSH Hardening

- Disable root password authentication
- Use key-based auth only
- Change default SSH port (optional)

```bash
# /etc/ssh/sshd_config
PermitRootLogin prohibit-password
PasswordAuthentication no
```

## Web UI Access Control

* Restrict Proxmox web UI to management VLAN/subnet
* Use firewall rules to block port 8006 from untrusted networks

```bash
# Example: allow only 10.0.1.0/24 to access web UI
iptables -A INPUT -p tcp --dport 8006 -s 10.0.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 8006 -j DROP
```

## Two-Factor Authentication

* Enable TOTP for Proxmox web UI users
* Navigate to: Datacenter → Permissions → Two Factor → Add TOTP

## API Token Security

* Use API tokens instead of password authentication for all scripts
* Apply principle of least privilege — scope tokens to specific paths
* Use `--privsep 1` to separate token permissions from user permissions

```bash
pveum user token add root@pam automation --privsep 1
pveum acl modify / --token 'root@pam!automation' --role PVEAuditor
```

## Automatic Security Updates

```bash
apt install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

Verify:

```bash
cat /etc/apt/apt.conf.d/20auto-upgrades
```

## Firewall — Host Level

Enable Proxmox's built-in firewall:

```bash
# /etc/pve/firewall/cluster.fw
[OPTIONS]
enable: 1

[RULES]
IN ACCEPT -source 10.0.1.0/24 -p tcp -dport 8006
IN ACCEPT -source 10.0.1.0/24 -p tcp -dport 22
IN DROP
```

## Audit Logging

* Proxmox logs to `/var/log/pveproxy/access.log` (web UI)
* Task logs in `/var/log/pve/tasks/`
* Auth logs in `/var/log/auth.log`
* Consider forwarding to a central syslog server

## Backup Encryption

When using Proxmox Backup Server:

```bash
proxmox-backup-client key create --kdf scrypt /etc/pve/priv/backup.key
```

Reference the key in backup jobs for at-rest encryption.

## CIS Benchmark Highlights (Debian 12)

* Ensure filesystem permissions on `/etc/passwd`, `/etc/shadow`
* Disable unused filesystems (cramfs, freevxfs, jffs2, hfs, hfsplus, udf)
* Ensure `aide` or `tripwire` is installed for file integrity monitoring
* Ensure `auditd` is running for system call auditing

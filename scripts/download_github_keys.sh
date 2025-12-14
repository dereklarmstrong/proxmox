#!/usr/bin/env bash
# Download GitHub user public keys and add to authorized_keys (interactive)

set -o errexit
set -o pipefail
set -o nounset

default_user="dereklarmstrong"
user="${1:-$default_user}"

if [ $# -eq 0 ]; then
	echo "Usage: $(basename "$0") [github_username]" >&2
	echo "No username provided; defaulting to $default_user. Pass a GitHub username to override." >&2
fi

read -r -p "Download SSH keys for '$user' and add to ~/.ssh/authorized_keys? [y/N]: " reply
if [[ ! "$reply" =~ ^[Yy]$ ]]; then
	echo "Aborted." >&2
	exit 1
fi

mkdir -p ~/.ssh
chmod 700 ~/.ssh

tmp_keys=$(mktemp)
if ! curl -fsSL "https://github.com/${user}.keys" -o "$tmp_keys"; then
	echo "Failed to download keys for ${user}" >&2
	rm -f "$tmp_keys"
	exit 1
fi

cat "$tmp_keys" >> ~/.ssh/authorized_keys
rm -f "$tmp_keys"
chmod 600 ~/.ssh/authorized_keys
echo "Added keys for ${user} to ~/.ssh/authorized_keys"


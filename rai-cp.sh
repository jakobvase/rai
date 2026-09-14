#!/bin/bash
# rai cp - Copy a local file to the same relative path in the current repo on the VM

SERVER_NAME="${RAI_SERVER:-rai}"
RAI_USER="${RAI_USER:-user}"
REMOTE_BASE="${RAI_REMOTE_BASE:-/home/$RAI_USER/workspaces}"

src="$1"
dest="$2"

if [ -z "$src" ] || [ -z "$dest" ]; then
  echo "Usage: rai cp <local_path> <remote_path>"
  exit 1
fi

ip=$(hcloud server describe "$SERVER_NAME" -o json | jq -r '.public_net.ipv4.ip')

repo_name=$(basename "$(git rev-parse --show-toplevel)")
remote_path="$REMOTE_BASE/$repo_name/$dest"

scp "$src" "$RAI_USER@$ip:$remote_path"
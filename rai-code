#!/bin/bash
# rai code - Open VS Code connected to the VM at the current repo

SERVER_NAME="${RAI_SERVER:-rai}"
RAI_USER="${RAI_USER:-user}"
REMOTE_BASE="${RAI_REMOTE_BASE:-/home/$RAI_USER/workspaces}"

ip=$(hcloud server describe "$SERVER_NAME" -o json | jq -r '.public_net.ipv4.ip')
repo_name=$(basename "$(git rev-parse --show-toplevel)")

code --remote ssh-remote+"$RAI_USER@$ip" "$REMOTE_BASE/$repo_name"
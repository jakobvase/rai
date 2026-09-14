#!/bin/bash
# rai ssh - SSH into the VM at the current repo's workspace directory

SERVER_NAME="${RAI_SERVER:-rai}"
RAI_USER="${RAI_USER:-user}"
REMOTE_BASE="${RAI_REMOTE_BASE:-/home/$RAI_USER/workspaces}"

ip=$(hcloud server describe "$SERVER_NAME" -o json | jq -r '.public_net.ipv4.ip')

repo_name=$(basename "$(git rev-parse --show-toplevel)")
remote_path="$REMOTE_BASE/$repo_name"

ssh -t "$RAI_USER@$ip" "cd '$remote_path' && exec \$SHELL"
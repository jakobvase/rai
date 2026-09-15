#!/bin/bash
# rai push - Push current git repo to RAI VM

SERVER_NAME="${RAI_SERVER:-rai}"
RAI_USER="${RAI_USER:-user}"
REMOTE_BASE="${RAI_REMOTE_BASE:-/home/$RAI_USER/workspaces}"

ip=$(hcloud server describe "$SERVER_NAME" -o json | jq -r '.public_net.ipv4.ip')

if [ -z "$ip" ] || [ "$ip" = "null" ]; then
  echo "Could not get VM IP. Is the server running?"
  exit 1
fi

repo_name=$(basename "$(git rev-parse --show-toplevel)")
remote_path="$REMOTE_BASE/$repo_name"
remote_url="ssh://$RAI_USER@$ip$remote_path"

# Set up repo on VM if needed
ssh "$RAI_USER@$ip" "
  if [ ! -d '$remote_path/.git' ]; then
    mkdir -p '$remote_path'
    git init '$remote_path'
    git -C '$remote_path' config receive.denyCurrentBranch updateInstead
  fi
"

branch=$(git rev-parse --abbrev-ref HEAD)
git push "$remote_url" "$branch"
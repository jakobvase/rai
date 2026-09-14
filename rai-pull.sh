#!/bin/bash
# rai pull - Pull changes from VM back to local repo

SERVER_NAME="${RAI_SERVER:-rai}"
RAI_USER="${RAI_USER:-user}"
REMOTE_BASE="${RAI_REMOTE_BASE:-/home/$RAI_USER/workspaces}"

ip=$(hcloud server describe "$SERVER_NAME" -o json | jq -r '.public_net.ipv4.ip')

if [ -z "$ip" ] || [ "$ip" = "null" ]; then
  echo "Could not get VM IP. Is the server running?"
  exit 1
fi

repo_name=$(basename "$(git rev-parse --show-toplevel)")
remote_url="ssh://$RAI_USER@$ip$REMOTE_BASE/$repo_name"

branch=$(git rev-parse --abbrev-ref HEAD)
git fetch "$remote_url" "$branch" && git merge FETCH_HEAD
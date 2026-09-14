#!/bin/bash
# rai unlock - Unlock the encrypted workspace volume

SERVER_NAME="${RAI_SERVER:-rai}"
RAI_USER="${RAI_USER:-user}"
RAI_REMOTE_BASE="${RAI_REMOTE_BASE:-/home/$RAI_USER/workspaces}"
RAI_VOLUME="${RAI_VOLUME:-/dev/sdb}"

ip=$(hcloud server describe "$SERVER_NAME" -o json | jq -r '.public_net.ipv4.ip')

if [ -z "$ip" ] || [ "$ip" = "null" ]; then
  echo "Could not get VM IP. Is the server running?"
  exit 1
fi

ssh -t "$RAI_USER@$ip" "sudo cryptsetup luksOpen $RAI_VOLUME data && sudo mount /dev/mapper/data $RAI_REMOTE_BASE"
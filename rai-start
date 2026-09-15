#!/bin/bash
# rai start - Start Hetzner VM if not running

SERVER_NAME="${RAI_SERVER:-rai}"

status=$(hcloud server describe "$SERVER_NAME" -o json | jq -r '.status')

if [ "$status" = "running" ]; then
  echo "Already running."
else
  echo "Starting $SERVER_NAME..."
  hcloud server poweron "$SERVER_NAME"

  echo -n "Waiting for server..."
  while [ "$(hcloud server describe "$SERVER_NAME" -o json | jq -r '.status')" != "running" ]; do
    sleep 2
    echo -n "."
  done
  echo " done."
fi

ip=$(hcloud server describe "$SERVER_NAME" -o json | jq -r '.public_net.ipv4.ip')
echo "IP: $ip"
echo "SSH: ssh user@$ip"
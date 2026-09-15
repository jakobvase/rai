# Remote AI

Scripts to manage working on codebases on a remote vm running ai/llm tools, if you don't trust them to run on your own machine.

To install, add `export PATH="$HOME/rai:$PATH"` to your `~/.bashrc`.

## Requirements

- `jq`, `git`, `ssh`, and `scp`.

Currently assumes hetzner cloud. `hcloud` must be installed and `HCLOUD_TOKEN` must be a valid hetzner api token.

For `rai code` to work, you must install VS Code's `code` cli. Open the Command Palette (Cmd+Shift+P), search for "Shell Command: Install 'code' command in PATH", and run it.

# Configuration

These are all optional:

- RAI_SERVER - VM name (default: rai)
- RAI_USER - SSH user (default: user)
- RAI_REMOTE_BASE - workspace root on VM (default: /home/$RAI_USER/workspaces)
- RAI_VOLUME - volume to mount the workspaces to and from, useful if they should be encrypted (default: /dev/sdb)

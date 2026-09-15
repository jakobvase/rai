# Remote AI

Scripts to manage working on codebases on a remote vm running ai/llm tools, if you don't trust them to run on your own machine.

To install, add `export PATH="$HOME/rai:$PATH"` to your `~/.bashrc`.

## Requirements

- `jq`, `git`, `ssh`, and `scp`.

VM management goes through a provider, set via `RAI_PROVIDER` (default: `hcloud`). Built-in providers:

- `hcloud` - Hetzner Cloud. `hcloud` must be installed and `HCLOUD_TOKEN` must be a valid hetzner api token.
- `local` - a static/always-on machine (e.g. your own physical box), addressed via `RAI_STATIC_IP`. There's nothing to start/stop.

For `rai code` to work, you must install VS Code's `code` cli. Open the Command Palette (Cmd+Shift+P), search for "Shell Command: Install 'code' command in PATH", and run it.

# Configuration

All `rai-*` scripts source `rai-config`, which loads these variables, all optional:

- RAI_SERVER - VM name (default: rai)
- RAI_USER - SSH user (default: user)
- RAI_REMOTE_BASE - workspace root on VM (default: /home/$RAI_USER/workspaces)
- RAI_VOLUME - volume to mount the workspaces to and from, useful if they should be encrypted (default: /dev/sdb)
- RAI_PROVIDER - which provider to use to find/start/stop the VM: `hcloud` or `local` (default: hcloud)
- RAI_STATIC_IP - IP or hostname of the machine, only used when RAI_PROVIDER=local

They can be set, in increasing order of precedence:

- In `~/.rai/config` - personal/per-machine overrides; don't commit this one, and use it for anything you don't want in the repo (e.g. secrets).
- In `<repo-root>/.rai/config` - repo defaults, meant to be committed and shared with the team.
- As already-exported environment variables (`RAI_SERVER=foo rai start`), which always win.

Both files are plain `KEY=value` shell files that get sourced directly, so
they can run arbitrary shell - only use `.rai/config` files you trust.

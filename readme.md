# Remote AI

Scripts to manage working on codebases on a remote vm running ai/llm tools, if you don't trust them to run on your own machine.

To install, add `export PATH="$HOME/rai:$PATH"` to your `~/.bashrc`.

## Requirements

- `jq`, `git`, `ssh`, and `scp`.

VM management goes through a provider, set via `RAI_PROVIDER` (default: `hetzner`). Built-in providers:

- `hetzner` - Hetzner Cloud. `hcloud` must be installed and `HCLOUD_TOKEN` must be a valid hetzner api token.
- `selfhosted` - a static/always-on machine (e.g. a hypervisor you control), addressed via `RAI_STATIC_IP`. There's nothing to start/stop.

For `rai code` to work, you must install VS Code's `code` cli. Open the Command Palette (Cmd+Shift+P), search for "Shell Command: Install 'code' command in PATH", and run it.

For `rai mosh` to work, you must install `mosh` locally, and the VM needs `mosh-server` and `tmux` installed - there's no provisioning script for this today, so it's a manual, one-time step on the VM (see "mosh" below).

## Configuration

All `rai-*` scripts source `rai-config`, which loads these variables, all optional:

- RAI_SERVER - VM name (default: rai)
- RAI_USER - SSH user (default: user)
- RAI_REMOTE_BASE - workspace root on VM (default: /home/$RAI_USER/workspaces)
- RAI_VOLUME - volume to mount the workspaces to and from, useful if they should be encrypted (default: /dev/sdb)
- RAI_PROVIDER - which provider to use to find/start/stop the VM: `hetzner` or `selfhosted` (default: hetzner)
- RAI_STATIC_IP - IP or hostname of the machine, only used when RAI_PROVIDER=selfhosted
- RAI_MOSH_PORT - UDP port for `rai mosh` to pin `mosh-server` to, instead of letting it pick from its default 60000-61000 range (default: unset, i.e. mosh's own default range)

They can be set, in increasing order of precedence:

- In `~/.rai/rai.conf` - personal/per-machine overrides; don't commit this one, and use it for anything you don't want in the repo (e.g. secrets).
- In `<repo-root>/.rai/rai.conf` - repo defaults. Can be committed and shared with a team, but mainly for being able to override values on a repo-by-repo basis (in case you want some repo running somewhere else for some reason).
- As already-exported environment variables (`RAI_SERVER=foo rai start`), which always win.

Both files are plain `KEY=value` text files, one assignment per line, and
are parsed (not sourced) - only lines assigning one of the variables above
are applied, a value can optionally be wrapped in matching single or double
quotes, and everything else (blank lines, `#` comments, unrecognized keys,
malformed lines) is ignored with a warning. There's no `$(...)`, backtick,
or variable-expansion support, so a `.rai/rai.conf` file can't run arbitrary
shell - safe to commit and share with the team.

## Encrypted volumes

If `RAI_VOLUME` points at a LUKS-encrypted volume, `rai unlock` opens and
mounts it over SSH via `sudo cryptsetup` and `sudo mount`. For that to work
non-interactively, the VM needs a sudoers rule granting `RAI_USER`
passwordless access to exactly those two commands - add these two commands to
`/etc/sudoers.d/rai-unlock` on the VM:

```
rai ALL=(root) NOPASSWD: /usr/sbin/cryptsetup luksOpen /dev/sdb data
rai ALL=(root) NOPASSWD: /usr/bin/mount /dev/mapper/data /home/rai/workspaces
```

- Replace `rai` with the actual `RAI_USER`, and the paths/args with the real
  `RAI_VOLUME`/`RAI_REMOTE_BASE` - sudoers matches commands literally, so any
  mismatch (wrong absolute path, different args) falls back to requiring a
  password instead of granting access.
- Use absolute paths from `which cryptsetup` / `which mount` on the VM.
- The rule is scoped to that one user and those two exact commands - `rai`
  gets no other passwordless sudo access.

## mosh

`rai mosh` is an alternative to `rai ssh` for connecting to the VM over
[mosh](https://mosh.org/) instead of plain SSH. It attaches to (or creates) a
tmux session scoped to the current repo, so closing the laptop lid, changing
networks, and running `rai mosh` again drops you back into the same shell,
with whatever was running still running. This is different from `rai ssh`,
which always starts a fresh shell in the repo's remote directory - `rai mosh`
only `cd`s there when the session is first created; reattaching to an
existing session keeps whatever directory it's already sitting in.

Two different repos checked out against the same VM get two independent
sessions (named `rai-<repo dir name>`), so they don't collide with each
other.

Requirements, not automated by any script here:

- `mosh` installed locally.
- `mosh-server` and `tmux` installed on the VM.
- utf-8 on installed on the server. I had to run:
  ```bash
  sudo locale-gen en_US.UTF-8
  sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
  ```
- A firewall in front of the VM (if any) allowing the UDP port(s) mosh
  needs: by default that's mosh's whole 60000-61000 range, since it picks a
  port from there at connection time; set `RAI_MOSH_PORT` to pin it to one
  specific port instead, so only that single port needs to be open. This
  repo does no firewall automation for either provider, so opening the
  port(s) is on you.

## Tests

`bats test/` runs the test suite (requires [bats-core](https://github.com/bats-core/bats-core), tested against 1.13; `jq` is stubbed, not required). Tests run end-to-end against the real scripts with `ssh`/`mosh`/`scp`/`hcloud`/`jq` stubbed - see `test/test_helper.bash` for the stubbing helpers.

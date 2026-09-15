# Plan for todo.md items

## Status

- [x] **Shared config file with overrides** — implemented (`rai-config`,
  `.rai/config`, `~/.rai/config`, readme documented). See "Done" section
  below for the as-built precedence, which differs slightly from the
  original plan. This work introduced a regression (the `declare -A` bug
  below), which is the top priority below since it undermines the feature
  that just shipped.

Remaining work, in priority order:

1. ~~Fix `rai-config`'s `declare -A` portability bug~~ — done, see below.
2. Provider abstraction (todo: cloud-provider independence).
3. `rai-ssh` missing remote dir (todo item 1).
4. `rai-cp` full-path support via `--raw` (todo item 2).
5. `rai-push` branch switching (todo item 4).

Note: the `LC_CTYPE`/locale warning also reported against `rai ssh` isn't
addressed here — it's a mismatch between the local SSH client's
`SendEnv LANG LC_*` and the remote's locale not being generated, which would
happen on a plain `ssh user@host` to that box too. Not a bug in rai's
scripts, so it's out of scope for this plan.

---

## Done: shared config file with overrides

Shipped as `rai-config`, sourced by every `rai-*` script, plus
`<repo-root>/.rai/config` and `~/.rai/config`. As built, precedence
(highest to lowest) is:

1. Already-exported environment variables
2. `<repo-root>/.rai/config` (repo defaults, committed)
3. `~/.rai/config` (personal/per-machine override, not committed)
4. Hardcoded fallback defaults in `rai-config`

Note this is **repo-over-home**, the opposite of the original draft plan —
deliberate per commit `a71a44f` ("Swap precedence: repo config now wins over
home config"), and now documented in `readme.md`. Also sets
`RAI_REPO_ROOT` once (via `git rev-parse --show-toplevel`), which every
script now reads instead of recomputing it. No further action needed here
beyond the two bugfixes below.

---

## 1. `rai-config`: `declare -A` fails on bash without associative arrays — DONE

Reported error:
```
/rai/rai-config: line 21: declare: -A: invalid option
declare: usage: declare [-afFirtx] [-p] [name[=value] ...]
/rai/rai-config: line 24: _rai_preset[$_rai_var]: bad array subscript
```

**Root cause:** `declare -A` (associative arrays) needs bash 4+. Whatever
`bash` is running this script (e.g. macOS's stock `/bin/bash`, which is
3.2) doesn't support it. Since there's no `set -e`, the script keeps going
after the failed `declare` and the subsequent `bad array subscript` errors,
so it "succeeds" — but `_rai_preset` never actually holds the caller's
pre-set env vars. That silently breaks the precedence guarantee
`rai-config`/`readme.md` document: an exported `RAI_SERVER=foo` can get
clobbered by a `.rai/config` file instead of winning, with no error to
indicate it happened.

**Fix:** Drop the associative array; the preset-capture/restore logic only
needs to remember values for a small, fixed list of variable names
(`$_rai_config_vars`), which doesn't require an associative array at all.
Reuse the indirect-expansion style already used elsewhere in the file
(`${!_rai_var}`, which *is* bash-3.2-safe) plus per-variable scalar names
built with `eval`/`printf -v`, e.g. capture into `_rai_preset_RAI_SERVER`
etc. and a parallel `_rai_preset_set_RAI_SERVER` flag (to distinguish "was
exported empty" from "wasn't exported"), then restore the same way after
sourcing both config files. This keeps the file portable to any POSIX-ish
bash without needing bash 4.
- Clean up the temp `_rai_preset_*`/`_rai_preset_set_*` variables at the end
  alongside the existing `unset _rai_preset _rai_var _rai_config_vars`.
- Sanity-check by running `rai-config` under the actual bash version that
  reported the bug (`bash --version`), not just whatever bash the dev
  machine defaults to — this class of bug only shows up on older bash, so
  it's easy to silently reintroduce.

**Files touched:** `rai-config`.

---

## 2. Cloud-provider independence (todo item 3)

Every script that needs the VM's IP or power state calls `hcloud` directly:
`rai-start`, `rai-stop`, `rai-code`, `rai-cp`, `rai-pull`, `rai-push`,
`rai-ssh`, `rai-unlock`. To eventually run on a physical box with a
hypervisor, these calls need to go through a provider interface instead.

**Design:**
- Define a minimal provider contract as a set of shell functions a provider
  script must implement:
  - `provider_ip` → prints the VM's reachable IP (or hostname)
  - `provider_status` → prints `running` / `stopped` / etc.
  - `provider_start` → powers the machine on (idempotent if already running)
  - `provider_stop` → powers the machine off (or shuts down gracefully)
- Ship `rai-provider-hcloud` implementing these four functions using the
  existing `hcloud server describe ... | jq ...` logic (moved verbatim from
  the current scripts).
- `rai-config` gains `RAI_PROVIDER="${RAI_PROVIDER:-hcloud}"`; each `rai-*`
  script sources `rai-provider-$RAI_PROVIDER` (after `rai-config`) and calls
  `provider_ip` / `provider_status` / etc. instead of inlining `hcloud`.
- Add a second, trivial provider, `rai-provider-local` (or `-static`), that
  just returns a configured `RAI_STATIC_IP`/hostname and always reports
  "running" — this both proves the abstraction works and directly satisfies
  the "run it on my own physical machine" goal without waiting on real
  hypervisor integration. `provider_start`/`provider_stop` can be no-ops or
  print a message for this provider.
- Update `readme.md`: move the "Currently assumes hetzner cloud" caveat to
  describe `RAI_PROVIDER` and list built-in providers.

**Files touched:** new `rai-provider-hcloud`, new `rai-provider-local`; edit
`rai-start`, `rai-stop`, `rai-code`, `rai-cp`, `rai-pull`, `rai-push`,
`rai-ssh`, `rai-unlock` to call `provider_*` functions instead of `hcloud`
directly; `readme.md`.

---

## 3. `rai-ssh` fails if the remote project doesn't exist yet (todo item 1)

`rai-ssh` runs `ssh -t "$RAI_USER@$ip" "cd '$remote_path' && exec \$SHELL"`.
If `$remote_path` doesn't exist (no `rai push` has happened yet), `cd` fails
and the whole SSH session aborts instead of dropping the user somewhere useful.

**Design:**
- Before the `cd`, create the directory if missing:
  `mkdir -p '$remote_path'` prepended to the remote command — cheap, idempotent,
  and matches what `rai-push` already does for the git init case.
- This mirrors the guard rai-push already has (`if [ ! -d '$remote_path/.git' ]`)
  but rai-ssh doesn't need it to be a git repo, just a directory to land in, so
  a plain `mkdir -p` suffices.
- Resulting remote command: `mkdir -p '$remote_path' && cd '$remote_path' && exec \$SHELL`.

**Files touched:** `rai-ssh`.

---

## 4. `rai-cp` should handle full paths outside git repos (todo item 2)

`rai-cp` unconditionally does:
```bash
repo_name=$(basename "$RAI_REPO_ROOT")
remote_path="$RAI_REMOTE_BASE/$repo_name/$dest"
```
This breaks in two ways:
- Run from outside any git repo, `$RAI_REPO_ROOT` is empty (`rai-config`
  already tolerates this — it redirects the `git rev-parse` stderr — but
  `rai-cp` doesn't check for it) and `basename ""` silently produces `.`,
  giving a bogus `remote_path` instead of a clear error.
- Even inside a repo, there's no way to target a path outside
  `$RAI_REMOTE_BASE/$repo_name` (e.g. `~/.ssh/authorized_keys`).

**Design:**
- No path sniffing. Add an explicit `--raw` flag to opt into full-path mode;
  behavior is otherwise unchanged. (Deliberately not `-a`/`--abs` — `cp -a`
  already means "archive mode" in `cp`/`rsync`/`tar`, and reusing it here for
  something unrelated on a tool named `rai cp` would be a trap. No short
  alias either, to avoid colliding with `-r`/`-R` = recursive expectations.)
  - `rai cp <src> <dest>` (no flag): today's behavior — requires a git repo
    (now: error clearly if `$RAI_REPO_ROOT` is empty, instead of silently
    computing a bogus path), `dest` is relative to
    `$RAI_REMOTE_BASE/$repo_name/`.
  - `rai cp --raw <src> <dest>`: `dest` is used as-is as the scp target path,
    no repo lookup performed at all (so it also works outside any git repo).
- Parse the flag with a simple manual loop (no getopts needed for one flag),
  keeping `src`/`dest` as the next two positional args either way.
- Update the usage message to
  `Usage: rai cp [--raw] <local_path> <remote_path>`.

**Files touched:** `rai-cp`.

---

## 5. `rai-push` doesn't switch the remote's checked-out branch (todo item 4)

`rai-push` relies on `receive.denyCurrentBranch=updateInstead`, which only
updates the remote's working tree when the pushed branch matches the branch
currently checked out on the remote. If the remote repo was initialized on
one branch (e.g. its default `master`/`main` from `git init`) and you push a
different local branch, the ref updates but the working tree doesn't follow,
silently leaving stale files checked out.

**Design:**
- After the push succeeds, ssh in and switch the remote's HEAD to the pushed
  branch: `git -C '$remote_path' checkout '$branch'`. Since the push just
  created/updated `refs/heads/$branch` on the remote, the checkout will
  succeed (branch now exists) and — because it's now the current branch —
  brings the working tree in sync too.
- Order matters: the checkout must happen strictly after the push, not folded
  into the earlier pre-push `ssh` block that does `git init`.
- Handle the "remote has uncommitted local changes blocking checkout" case by
  surfacing git's own error rather than swallowing it — this is a rare/edge
  scenario and the user should see it and resolve manually.
- Combine with item 3's `mkdir -p` guard implicitly: `rai-push`'s existing
  pre-push block already does `mkdir -p` + `git init`, so no change needed
  there.

**Files touched:** `rai-push`.

---

## Verification

- No test suite exists; verification is manual against a real (or a throwaway
  local-provider) VM:
  - Run `rai-config` (e.g. `bash --version` check first) on the bash version
    that originally hit the `declare -A` error, with an env var exported
    before the call and a conflicting value in both `.rai/config` files —
    confirm the env var wins and no warnings print.
  - `rai ssh` into a repo that was never pushed → should land in an empty dir
    instead of erroring.
  - `rai cp --raw ~/.ssh/id_ed25519.pub ~/.ssh/authorized_keys` from outside
    any git repo → should scp successfully; `rai cp` (no flag) from outside a
    repo → clear error instead of a bogus path.
  - Switch `RAI_PROVIDER=local` with a static IP configured → `rai start`,
    `rai ssh`, `rai push` all work without touching `hcloud`.
  - Push a new local branch that differs from the remote's initial branch,
    then `rai ssh` in and confirm `git status`/`ls` reflect the pushed branch.

# TODO for rai

Viewed through the lens of: what's needed before open-sourcing this.

- [x] I get an "Already on main" whenever I push, which is annoying.
  - Fixed: remote checkout now runs `git checkout -q`, which suppresses the "Already on"/"Switched to" message without hiding real errors or affecting exit codes.
- [x] User friendlyness
  - [x] If you push with local changes, you should probably receive a warning that only committed changes get pushed, and be asked if you want to continue?
    - Implemented: rai-push warns (stderr) on uncommitted tracked/staged changes before doing any remote work. Untracked-only files don't trigger it - `git push` never carries them either way, so they're a weak signal. Interactive (tty): prompts y/N, aborts on anything else. Non-interactive (scripts/CI/tests): prints the warning and proceeds without blocking - rai-push needs to stay scriptable, and a hard block would need a new flag nobody's asked for.
- [] Handling abrupt stops in connection well - specifically `rai-ssh`, not `rai-code` (VS Code Remote-SSH already handles its own reconnects).
  - Goal: don't lose work in a remote shell (e.g. a long-running agent task) when the SSH connection drops (laptop sleep, wifi blip, etc).
  - Undecided - this isn't a space we've worked in before, needs more research. Options on the table:
    - SSH keepalive tuning (`ServerAliveInterval`/`ServerAliveCountMax`) - reduces how often drops happen, doesn't help once one does.
    - Persistent remote session: `rai-ssh` attaches to a named tmux/screen session on the VM instead of a bare shell, so a drop just means reconnect-and-reattach, nothing running is lost.
    - Both.
  - Next step: figure out which failure mode actually hurts in practice before picking a design.
- [] Consider if `rai` should create/delete instead of start/stop, as that would save cloud costs. At least on hetzner. Maybe both should be supported?
  - Not a blocker for open-sourcing - a feature/design decision, not a correctness or legal issue. Recommendation: defer, file as a GitHub issue at launch so it's visible as a known direction instead of silently absent.
  - Tradeoff: delete+recreate saves more (Hetzner still bills for a stopped server's attached volume/reserved resources), but loses the server itself (new IP, volume reattachment, reprovisioning) - bigger blast radius, and provider-specific (meaningless for `selfhosted`, which has nothing to create/delete).
- [] Consider user installation. Would be good if this could be easily published to brew/apt/other package repos, what's required for that?
  - Not a blocker for open-sourcing - readme already documents a manual PATH install, which is normal for a fresh OSS release. Defer until there's actual demand for it.

## Open-source readiness (new)

- [] Add a LICENSE file. Blocker: without one, nobody knows what they're legally permitted to do with the code. Pick MIT or Apache-2.0 (common defaults for a tool like this).
- [] Add a more visible "Security" callout to readme.md: `.rai/config` files (both `~/.rai/config` and `<repo>/.rai/config`) are sourced as plain shell and can run arbitrary code. Already mentioned once in the Configuration section, but strangers reading this on GitHub won't necessarily read as carefully as you did - worth its own heading.
- [] Consider a CONTRIBUTING.md - optional for a small personal-tool release, can add later if/when the project gets external contributors.

Checked already, no action needed: scanned full git history for leaked tokens/secrets/credentials - clean. No git remote configured yet either.

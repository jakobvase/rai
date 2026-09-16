# TODO for rai

Viewed through the lens of: what's needed before open-sourcing this.

- [] User friendlyness
  - [] anything else here? Better messages for what's happening? I think letting the subcommands' output bleed through is generally a good idea, but maybe there should be some `-q` flags to suppress most of it?
- [] Handling abrupt stops in connection well - specifically `rai-ssh`.
  - [x] Garbage-input-after-drop bug: fixed. An abrupt drop skipped whatever remote program (vim/tmux/agent TUI) was running its own cleanup, leaving xterm mouse-reporting modes stuck on locally, so mouse movement showed up as keystrokes. `rai-ssh` now resets terminal state (`stty sane` + disables all common mouse-tracking escape sequences) in a `trap ... EXIT`, so it always runs regardless of how the session ended, without swallowing ssh's real exit code.
  - [] Bigger gap: "close the laptop lid on the train, walk to work, resume exactly where I was" - a full roaming/reconnect scenario, not just a blip. Standard answer is **mosh + tmux** (mosh rides UDP and survives IP changes/sleep instead of ssh's single TCP connection; tmux keeps whatever's running alive server-side so you reattach instead of getting a fresh shell). Design sketched, not built:
    - `rai-ssh` would become `mosh $RAI_USER@$ip -- tmux new-session -A -s rai` (attach-or-create) when enabled; the "is the volume mounted" check would need to move to an ssh preflight or into the tmux session's startup command, since mosh has no "run a check first" hook. `rai-code` is out of scope - it goes through VS Code Remote-SSH, which owns that connection and already has its own reconnect handling.
    - New dependency: `mosh` on both the laptop and the VM, `tmux` on the VM only. There's no VM-provisioning script in this repo today (`rai-provider-hetzner` only does `hcloud server describe/poweron/shutdown`, no `create`), so this lands as a readme/docs requirement, not a code change to the provider.
    - Firewall: mosh needs a reachable UDP port range (default 60000-61000, narrowable to one port via `mosh-server -p`) in addition to ssh's TCP 22. `rai-provider-hetzner` does no firewall management today (no `hcloud firewall` calls) - if that ever gets added, it'd need a UDP rule; for now this is a docs note about opening one port.
    - Recommendation: **opt-in** via a `RAI_USE_MOSH` config var (fits the existing `rai-config` precedence system as one more optional var), not the new default - it's a hard new dependency, and every `rai ssh` landing in a shared persistent tmux session is a real behavior change that shouldn't surprise existing users.
    - Rough size: medium. Not a new architecture (one more branch in `rai-ssh` + a config flag + docs), but the actual "does reconnect-after-sleep work" story isn't really testable through the existing bats ssh-stubbing approach - would need a manual verification checklist. Suggested order: config plumbing + the mosh/tmux branch, then docs (Requirements section + a mosh section covering VM install and the firewall port), then manual verification of the real lid-close scenario, then decide tmux session-naming (per-VM vs per-repo - leaning per-repo, matching how `rai-ssh` already scopes by `remote_repo_path`, to avoid different projects colliding in one session).
- [] Consider if `rai` should create/delete instead of start/stop, as that would save cloud costs. At least on hetzner. Maybe both should be supported?
  - Not a blocker for open-sourcing - a feature/design decision, not a correctness or legal issue. Recommendation: defer, file as a GitHub issue at launch so it's visible as a known direction instead of silently absent.
  - Tradeoff: delete+recreate saves more (Hetzner still bills for a stopped server's attached volume/reserved resources), but loses the server itself (new IP, volume reattachment, reprovisioning) - bigger blast radius, and provider-specific (meaningless for `selfhosted`, which has nothing to create/delete).
- [] Consider user installation. Would be good if this could be easily published to brew/apt/other package repos, what's required for that?
  - Not a blocker for open-sourcing - readme already documents a manual PATH install, which is normal for a fresh OSS release. Defer until there's actual demand for it.
- [x] Add a LICENSE file. Fixed: MIT license added.
- [] Consider a CONTRIBUTING.md - optional for a small personal-tool release, can add later if/when the project gets external contributors.
- [] `git lfs` maybe breaks rai?
- [] `rai push` should maybe only push the last N commits? (like the depth in github actions)

Checked already, no action needed: scanned full git history for leaked tokens/secrets/credentials - clean. No git remote configured yet either.

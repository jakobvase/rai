# TODO for rai

Viewed through the lens of: what's needed before open-sourcing this.

- [] User friendlyness
  - [] anything else here? Better messages for what's happening? I think letting the subcommands' output bleed through is generally a good idea, but maybe there should be some `-q` flags to suppress most of it?
- [] Handling abrupt stops in connection well - specifically `rai-ssh`.
  - Goal: don't lose work in a remote shell (e.g. a long-running agent task) when the SSH connection drops (laptop sleep, wifi blip, etc).
  - Undecided - this isn't a space we've worked in before, needs more research. Options on the table:
    - SSH keepalive tuning (`ServerAliveInterval`/`ServerAliveCountMax`) - reduces how often drops happen, doesn't help once one does.
    - Persistent remote session: `rai-ssh` attaches to a named tmux/screen session on the VM instead of a bare shell, so a drop just means reconnect-and-reattach, nothing running is lost.
    - Both.
  - Next step: figure out which failure mode actually hurts in practice before picking a design.
    - One thing that happens is that when the connection is lost, it returns to the local terminal and then _moving the mouse causes inputs in the terminal_, which is really annoying.
    - I often work from a train, close the lid on my laptop and walk to the workplace and want to continue what I was just doing. How? Are there tools that already do this that we should be using?
- [] Consider if `rai` should create/delete instead of start/stop, as that would save cloud costs. At least on hetzner. Maybe both should be supported?
  - Not a blocker for open-sourcing - a feature/design decision, not a correctness or legal issue. Recommendation: defer, file as a GitHub issue at launch so it's visible as a known direction instead of silently absent.
  - Tradeoff: delete+recreate saves more (Hetzner still bills for a stopped server's attached volume/reserved resources), but loses the server itself (new IP, volume reattachment, reprovisioning) - bigger blast radius, and provider-specific (meaningless for `selfhosted`, which has nothing to create/delete).
- [] Consider user installation. Would be good if this could be easily published to brew/apt/other package repos, what's required for that?
  - Not a blocker for open-sourcing - readme already documents a manual PATH install, which is normal for a fresh OSS release. Defer until there's actual demand for it.
- [] Add a LICENSE file. Blocker: without one, nobody knows what they're legally permitted to do with the code. Pick MIT or Apache-2.0 (common defaults for a tool like this).
- [] Consider a CONTRIBUTING.md - optional for a small personal-tool release, can add later if/when the project gets external contributors.
- [] `git lfs` maybe breaks rai?
- [] `rai push` should maybe only push the last N commits? (like the depth in github actions)

Checked already, no action needed: scanned full git history for leaked tokens/secrets/credentials - clean. No git remote configured yet either.

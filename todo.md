# TODO for rai

Viewed through the lens of: what's needed before open-sourcing this.

- [] User friendlyness
  - [] anything else here? Better messages for what's happening? I think letting the subcommands' output bleed through is generally a good idea, but maybe there should be some `-q` flags to suppress most of it?
- [] Consider if `rai` should create/delete instead of start/stop, as that would save cloud costs. At least on hetzner. Maybe both should be supported?
  - Not a blocker for open-sourcing - a feature/design decision, not a correctness or legal issue. Recommendation: defer, file as a GitHub issue at launch so it's visible as a known direction instead of silently absent.
  - Tradeoff: delete+recreate saves more (Hetzner still bills for a stopped server's attached volume/reserved resources), but loses the server itself (new IP, volume reattachment, reprovisioning) - bigger blast radius, and provider-specific (meaningless for `selfhosted`, which has nothing to create/delete).
- [] Consider user installation. Would be good if this could be easily published to brew/apt/other package repos, what's required for that?
  - Not a blocker for open-sourcing - readme already documents a manual PATH install, which is normal for a fresh OSS release. Defer until there's actual demand for it.
- [] Consider a CONTRIBUTING.md - optional for a small personal-tool release, can add later if/when the project gets external contributors.
- [] `git lfs` maybe breaks rai?
  - For this to work, the VM needs git lfs too. Another provisioning item, possibly.
- [] `rai push` should maybe only push the last N commits? (like the depth in github actions)
  - Would be nice, but needs to be thought through. The `--force-with-lease` tracking needs to keep working. But for the initial setup, which is also where most of the gain lies, this shouldn't be too complex.

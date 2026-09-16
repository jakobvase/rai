# Tests for rai-mosh, run end-to-end against the real script (real git, real
# `rai-config`/`rai-provider-selfhosted`/`rai-common`), with only `mosh` and
# `mountpoint` stubbed - see test_helper.bash's stub_mosh_eval for why `mosh`
# specifically is stubbed via a capture-then-eval trick rather than just a
# dumb recorder.

load test_helper

setup() {
  setup_stub_dir
  export RAI_PROVIDER=selfhosted
  export RAI_STATIC_IP=127.0.0.1
  export RAI_USER=testuser
  # A writable stand-in for the default /home/$RAI_USER/workspaces, since
  # the stub_mosh_eval trick really does run `mkdir -p`/`tmux` against this
  # path (it's the local machine standing in for the remote one).
  export RAI_REMOTE_BASE="$STUB_DIR/remote_base"

  # Pretend the workspace volume is already mounted, so the script gets
  # past the mountpoint check to the mkdir/tmux line we're testing.
  make_stub mountpoint 'exit 0'
  # The remote command ends in `exec tmux new-session ...`; stub tmux so
  # eval'ing it (see stub_mosh_eval) doesn't try to attach a real terminal.
  make_stub tmux '{ printf "%s\n" "$@"; echo "---"; } >> "$STUB_DIR/tmux_invocation"'

  stub_mosh_eval
}

teardown() {
  teardown_stub_dir
}

# Create a git repo at $BATS_TEST_TMPDIR/repos/<dirname> so `git
# rev-parse --show-toplevel` (used by rai-config to set RAI_REPO_ROOT)
# works for real. rai-mosh only cares about the repo's *directory name*
# (via remote_repo_path's basename), not its history, so no commit needed.
make_repo() {
  local dirname="$1"
  local repo="$BATS_TEST_TMPDIR/repos/$dirname"
  mkdir -p "$repo"
  ( cd "$repo" && git init -q )
  printf '%s' "$repo"
}

@test "rai-mosh: normal repo dir name produces a working remote command" {
  repo=$(make_repo "myrepo")

  # `env -C` (not a hand-built `cd ... && ...` string) so a malicious repo
  # dir name in the injection test below can't break *our own* test
  # harness's quoting - argv here is passed straight through, no shell
  # re-parsing of $repo.
  run env -C "$repo" "$REPO_ROOT/rai-mosh"
  [ "$status" -eq 0 ]

  invocation="$(cat "$STUB_DIR/mosh_invocation")"
  [[ "$invocation" == *"myrepo"* ]]

  tmux_invocation="$(cat "$STUB_DIR/tmux_invocation")"
  [[ "$tmux_invocation" == *"new-session"* ]]
  [[ "$tmux_invocation" == *"rai-myrepo"* ]]
  [[ "$tmux_invocation" == *"myrepo"* ]]
}

@test "rai-mosh: injection-attempt repo dir name is not executed by the remote shell" {
  pwn_sentinel="$STUB_DIR/pwned"
  # Reference the sentinel by an *exported env var name*, not its expanded
  # path: a directory name is a single path component and can't itself
  # contain a literal '/', so baking an absolute path directly into it
  # would make `mkdir -p` create nested directories instead of the one
  # maliciously-named leaf directory we actually want to test.
  export PWN_MARKER="$pwn_sentinel"
  malicious_name="foo; touch \$PWN_MARKER; echo done"
  repo=$(make_repo "$malicious_name")

  run env -C "$repo" "$REPO_ROOT/rai-mosh"

  # The real assertion: shell_quote() held for both $q_remote_path and the
  # new $q_session, so evaluating the captured remote command (see
  # stub_mosh_eval) never ran the injected `touch`.
  [ ! -e "$pwn_sentinel" ]
  [ "$status" -eq 0 ]
}

@test "rai-mosh: mountpoint not mounted exits nonzero with the unlock message, never reaching tmux" {
  make_stub mountpoint 'exit 1'
  repo=$(make_repo "myrepo")

  run env -C "$repo" "$REPO_ROOT/rai-mosh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Workspace volume is not mounted. Run \`rai unlock\` first."* ]]
  [ ! -e "$STUB_DIR/tmux_invocation" ]
}

# Tests for rai-ssh, run end-to-end against the real script (real git, real
# `rai-config`/`rai-provider-selfhosted`/`rai-common`), with only `ssh` and
# `mountpoint` stubbed - see test_helper.bash's stub_ssh_eval for why `ssh`
# specifically is stubbed via a capture-then-eval trick rather than just a
# dumb recorder.

load test_helper

setup() {
  setup_stub_dir
  export RAI_PROVIDER=selfhosted
  export RAI_STATIC_IP=127.0.0.1
  export RAI_USER=testuser
  # A writable stand-in for the default /home/$RAI_USER/workspaces, since
  # the stub_ssh_eval trick really does run `mkdir -p`/`cd` against this
  # path (it's the local machine standing in for the remote one).
  export RAI_REMOTE_BASE="$STUB_DIR/remote_base"

  # Pretend the workspace volume is already mounted, so the script gets
  # past the mountpoint check to the mkdir/cd/exec line we're testing.
  make_stub mountpoint 'exit 0'
  # The remote command ends in `exec $SHELL`; make that a no-op so eval'ing
  # it (see stub_ssh_eval) doesn't replace our test process with a shell.
  export SHELL=/bin/true

  stub_ssh_eval
}

teardown() {
  teardown_stub_dir
}

# Create a git repo at $BATS_TEST_TMPDIR/repos/<dirname> so `git
# rev-parse --show-toplevel` (used by rai-config to set RAI_REPO_ROOT)
# works for real. rai-ssh only cares about the repo's *directory name*
# (via remote_repo_path's basename), not its history, so no commit needed.
make_repo() {
  local dirname="$1"
  local repo="$BATS_TEST_TMPDIR/repos/$dirname"
  mkdir -p "$repo"
  ( cd "$repo" && git init -q )
  printf '%s' "$repo"
}

@test "rai-ssh: normal repo dir name produces a working remote command" {
  repo=$(make_repo "myrepo")

  # `env -C` (not a hand-built `cd ... && ...` string) so a malicious repo
  # dir name in the injection test below can't break *our own* test
  # harness's quoting - argv here is passed straight through, no shell
  # re-parsing of $repo.
  run env -C "$repo" "$REPO_ROOT/rai-ssh"
  [ "$status" -eq 0 ]

  invocation="$(cat "$STUB_DIR/ssh_invocation")"
  [[ "$invocation" == *"myrepo"* ]]
}

@test "rai-ssh: injection-attempt repo dir name is not executed by the remote shell" {
  pwn_sentinel="$STUB_DIR/pwned"
  # Reference the sentinel by an *exported env var name*, not its expanded
  # path: a directory name is a single path component and can't itself
  # contain a literal '/', so baking an absolute path directly into it
  # would make `mkdir -p` create nested directories instead of the one
  # maliciously-named leaf directory we actually want to test.
  export PWN_MARKER="$pwn_sentinel"
  malicious_name="foo; touch \$PWN_MARKER; echo done"
  repo=$(make_repo "$malicious_name")

  run env -C "$repo" "$REPO_ROOT/rai-ssh"

  # The real assertion: shell_quote() held, so evaluating the captured
  # remote command (see stub_ssh_eval) never ran the injected `touch`.
  [ ! -e "$pwn_sentinel" ]
  [ "$status" -eq 0 ]
}

@test "rai-ssh: terminal is reset on a clean ssh exit" {
  repo=$(make_repo "myrepo")

  run env -C "$repo" "$REPO_ROOT/rai-ssh"

  [ "$status" -eq 0 ]
  # The mouse-tracking disable sequences (see rai-ssh's reset_terminal) -
  # proof the EXIT trap actually ran, not just that the script exited 0.
  [[ "$output" == *$'\e[?1000l'* ]]
  [[ "$output" == *$'\e[?1006l'* ]]
}

@test "rai-ssh: terminal is still reset when ssh exits nonzero, and that exit code still propagates" {
  repo=$(make_repo "myrepo")
  # Simulates an abrupt drop: ssh itself exits nonzero (as it would on a
  # killed connection) instead of running the remote command at all - the
  # exact case reset_terminal exists for, since a clean exit wouldn't have
  # left any mode stuck in the first place.
  make_stub ssh '
    { printf "%s\n" "$@"; echo "---"; } >> "$STUB_DIR/ssh_invocation"
    exit 7
  '

  run env -C "$repo" "$REPO_ROOT/rai-ssh"

  # Not swallowed or coerced to 1 by the trap - ssh's own exit code.
  [ "$status" -eq 7 ]
  [[ "$output" == *$'\e[?1000l'* ]]
  [[ "$output" == *$'\e[?1006l'* ]]
}

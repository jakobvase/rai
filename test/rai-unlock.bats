# Tests for rai-unlock, run end-to-end against the real script, with `ssh`,
# `mountpoint`, `sudo`, `cryptsetup` and `mount` stubbed (rai-unlock's remote
# command runs all of these). See test_helper.bash's stub_ssh_eval for why
# `ssh` is stubbed via a capture-then-eval trick rather than a dumb recorder.
#
# Note: this only exercises the RAI_REMOTE_BASE injection surface (used in
# both the `mountpoint` check and the final `mount` call, so it's always
# reached). RAI_VOLUME's quoting is exercised generically by
# rai-common.bats' shell_quote tests instead of end-to-end here, because the
# `sudo cryptsetup luksOpen` line is only reached when /dev/mapper/data
# doesn't already exist - real state on the host running the tests, not
# something a test can fake without touching /dev.

load test_helper

setup() {
  setup_stub_dir
  export RAI_PROVIDER=selfhosted
  export RAI_STATIC_IP=127.0.0.1
  export RAI_USER=testuser

  # Report "not mounted" so the script proceeds past the early-return to
  # the `mount` call we're testing.
  make_stub mountpoint 'exit 1'
  # Passwordless-sudo stand-in: just run what it's given.
  make_stub sudo 'exec "$@"'
  make_stub cryptsetup 'printf "%s\n" "$@" > "$STUB_DIR/cryptsetup_invocation"'
  make_stub mount 'printf "%s\n" "$@" > "$STUB_DIR/mount_invocation"'

  stub_ssh_eval
}

teardown() {
  teardown_stub_dir
}

@test "rai-unlock: normal RAI_REMOTE_BASE produces a working mount command" {
  export RAI_REMOTE_BASE="/mnt/workspaces"

  run "$REPO_ROOT/rai-unlock"
  [ "$status" -eq 0 ]

  invocation="$(cat "$STUB_DIR/mount_invocation")"
  [[ "$invocation" == *"/mnt/workspaces"* ]]
}

@test "rai-unlock: injection-attempt RAI_REMOTE_BASE is not executed by the remote shell" {
  pwn_sentinel="$STUB_DIR/pwned"
  # No quote character in the payload: RAI_REMOTE_BASE is interpolated
  # *twice* in the remote script (the mountpoint check and the mount
  # call), so a single stray `'` would pair up across the two occurrences
  # and mask a real bug instead of exercising it. A bare `;` breaks out
  # regardless of how many times the value appears.
  export RAI_REMOTE_BASE="/mnt/workspaces; touch $pwn_sentinel; echo done"

  run "$REPO_ROOT/rai-unlock"

  # The real assertion: shell_quote() held, so evaluating the captured
  # remote command (see stub_ssh_eval) never ran the injected `touch`.
  [ ! -e "$pwn_sentinel" ]
  [ "$status" -eq 0 ]

  # And it was still delivered as a single, intact argument to `mount`.
  grep -qF "$RAI_REMOTE_BASE" "$STUB_DIR/mount_invocation"
}

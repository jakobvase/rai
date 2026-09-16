# Tests for `rai` (the top-level dispatcher), locking in that
# `set -euo pipefail` plus `COMMAND="${1:-}"` guard behavior: calling it
# with no args must hit the usage message, not blow up on referencing an
# unset `$1` under `set -u`.

load test_helper

@test "rai with no args prints usage instead of failing on an unbound \$1" {
  run "$REPO_ROOT/rai"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: rai"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

@test "rai with an unrecognized command prints usage" {
  run "$REPO_ROOT/rai" bogus-command
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: rai"* ]]
}

@test "rai mosh reaches rai-mosh with args forwarded" {
  # A throwaway dir containing only a copy of the real dispatcher plus a
  # stub `rai-mosh` (the dispatcher resolves sibling scripts relative to
  # its own realpath, so this is enough to isolate the test from the real
  # rai-mosh - no git repo / provider / mosh stubbing needed just to prove
  # dispatch + arg forwarding).
  dispatch_dir="$BATS_TEST_TMPDIR/dispatch"
  mkdir -p "$dispatch_dir"
  cp "$REPO_ROOT/rai" "$dispatch_dir/rai"

  args_file="$BATS_TEST_TMPDIR/mosh_args"
  cat > "$dispatch_dir/rai-mosh" <<STUB
#!/bin/bash
printf '%s\n' "\$@" > "$args_file"
STUB
  chmod +x "$dispatch_dir/rai-mosh"

  run "$dispatch_dir/rai" mosh --foo bar

  [ "$status" -eq 0 ]
  [ "$(cat "$args_file")" = "$(printf '%s\n' --foo bar)" ]
}

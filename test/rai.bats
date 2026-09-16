# Tests for `rai` (the top-level dispatcher), locking in that
# `set -euo pipefail` plus `COMMAND="${1:-}"` guard behavior: calling it
# with no args must hit the usage message, not blow up on referencing an
# unset `$1` under `set -u`.

load test_helper

@test "rai with no args prints usage instead of failing on an unbound \$1" {
  run "$BIN_DIR/rai"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: rai"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

@test "rai with an unrecognized command prints usage" {
  run "$BIN_DIR/rai" bogus-command
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: rai"* ]]
  assert_lists_all_subcommands
}

# assert_lists_all_subcommands - the help/usage text mentions each of the
# nine subcommands, so a new one added to the case statement doesn't
# silently go undocumented.
assert_lists_all_subcommands() {
  local cmd
  for cmd in start stop push pull cp ssh mosh code unlock; do
    [[ "$output" == *"$cmd"* ]]
  done
}

@test "rai help prints help and exits 0" {
  run "$BIN_DIR/rai" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: rai"* ]]
  assert_lists_all_subcommands
}

@test "rai -h prints help and exits 0" {
  run "$BIN_DIR/rai" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: rai"* ]]
  assert_lists_all_subcommands
}

@test "rai --help prints help and exits 0" {
  run "$BIN_DIR/rai" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: rai"* ]]
  assert_lists_all_subcommands
}

@test "rai with no args lists all subcommands" {
  run "$BIN_DIR/rai"
  [ "$status" -eq 1 ]
  assert_lists_all_subcommands
}

@test "rai mosh reaches rai-mosh with args forwarded" {
  # A throwaway dir containing only a copy of the real dispatcher (in its
  # own bin/) plus a stub `rai-mosh` (in a sibling lib/) - the dispatcher
  # resolves lib scripts via ../lib relative to its own realpath, so this
  # is enough to isolate the test from the real rai-mosh - no git repo /
  # provider / mosh stubbing needed just to prove dispatch + arg
  # forwarding).
  dispatch_dir="$BATS_TEST_TMPDIR/dispatch"
  mkdir -p "$dispatch_dir/bin" "$dispatch_dir/lib"
  cp "$BIN_DIR/rai" "$dispatch_dir/bin/rai"

  args_file="$BATS_TEST_TMPDIR/mosh_args"
  cat > "$dispatch_dir/lib/rai-mosh" <<STUB
#!/bin/bash
printf '%s\n' "\$@" > "$args_file"
STUB
  chmod +x "$dispatch_dir/lib/rai-mosh"

  run "$dispatch_dir/bin/rai" mosh --foo bar

  [ "$status" -eq 0 ]
  [ "$(cat "$args_file")" = "$(printf '%s\n' --foo bar)" ]
}

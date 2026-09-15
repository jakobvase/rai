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

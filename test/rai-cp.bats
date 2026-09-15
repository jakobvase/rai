# Tests for rai-cp, locking in two things:
# - the `set -euo pipefail` + unbound-positional-param guards (zero/one arg
#   must hit the usage message, not blow up referencing unset $1/$2)
# - normal flow still scp's to the right place, for both --raw and the
#   default (inside-a-git-repo) modes

load test_helper

setup() {
  setup_stub_dir
  export RAI_PROVIDER=selfhosted
  export RAI_STATIC_IP=127.0.0.1
  export RAI_USER=testuser
  make_stub scp 'printf "%s\n" "$@" > "$STUB_DIR/scp_invocation"'
}

teardown() {
  teardown_stub_dir
}

@test "rai-cp with zero args prints usage instead of failing on unbound \$1/\$2" {
  run "$REPO_ROOT/rai-cp"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: rai cp"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

@test "rai-cp with one arg prints usage instead of failing on unbound \$2" {
  run "$REPO_ROOT/rai-cp" only-one-arg
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: rai cp"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

@test "rai-cp --raw with two args scp's straight to the given remote path" {
  run "$REPO_ROOT/rai-cp" --raw localfile /remote/dest/path
  [ "$status" -eq 0 ]
  invocation="$(cat "$STUB_DIR/scp_invocation")"
  [[ "$invocation" == *"localfile"* ]]
  [[ "$invocation" == *"testuser@127.0.0.1:/remote/dest/path"* ]]
}

@test "rai-cp without --raw, outside a git repo, fails with a clear error" {
  run env -C "$BATS_TEST_TMPDIR" "$REPO_ROOT/rai-cp" localfile dest/path
  [ "$status" -eq 1 ]
  [[ "$output" == *"not inside a git repository"* ]]
}

@test "rai-cp without --raw, inside a git repo, scp's to the computed remote repo path" {
  repo="$BATS_TEST_TMPDIR/myrepo"
  mkdir -p "$repo"
  ( cd "$repo" && git init -q )

  run env -C "$repo" "$REPO_ROOT/rai-cp" localfile dest/path
  [ "$status" -eq 0 ]
  invocation="$(cat "$STUB_DIR/scp_invocation")"
  [[ "$invocation" == *"myrepo/dest/path"* ]]
}

# Tests for rai-init, run end-to-end against the real script (real
# rai-config/rai-provider-*/rai-common), with an isolated $HOME and a
# throwaway git repo standing in for the caller's repo - same setup as
# test/rai-config.bats.
#
# Interactive prompts are fed via piped stdin (`printf '...' | env -C ...
# rai-init`) rather than a tty: rai-init's mode switch is the -y/--yes flag,
# not an isatty check like rai-push's confirmation, so `read` behaves the
# same whether stdin is a real terminal or a pipe - piping input is enough
# to drive the interactive flow in a test.

load test_helper

setup() {
  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE_HOME/.rai"
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  ( cd "$REPO" && git init -q )
}

@test "rai-init: not in a git repo fails with a clear error and writes nothing" {
  NOTREPO="$BATS_TEST_TMPDIR/notrepo"
  mkdir -p "$NOTREPO"

  run env -C "$NOTREPO" HOME="$FAKE_HOME" "$LIB_DIR/rai-init" --yes

  [ "$status" -ne 0 ]
  [[ "$output" == *"not inside a git repository"* ]]
  [ ! -e "$NOTREPO/.rai/rai.conf" ]
}

@test "rai-init: --yes with default resolved config writes RAI_PROVIDER and RAI_SERVER" {
  run env -C "$REPO" HOME="$FAKE_HOME" "$LIB_DIR/rai-init" --yes

  [ "$status" -eq 0 ]
  [ -f "$REPO/.rai/rai.conf" ]
  grep -q '^RAI_PROVIDER=hetzner$' "$REPO/.rai/rai.conf"
  grep -q '^RAI_SERVER=rai$' "$REPO/.rai/rai.conf"
  ! grep -q '^RAI_STATIC_IP=' "$REPO/.rai/rai.conf"
}

@test "rai-init: --yes with selfhosted and no RAI_STATIC_IP fails, writes nothing" {
  run env -C "$REPO" HOME="$FAKE_HOME" RAI_PROVIDER=selfhosted "$LIB_DIR/rai-init" --yes

  [ "$status" -ne 0 ]
  [[ "$output" == *"RAI_STATIC_IP"* ]]
  [ ! -e "$REPO/.rai/rai.conf" ]
}

@test "rai-init: --yes with selfhosted and RAI_STATIC_IP writes both values" {
  run env -C "$REPO" HOME="$FAKE_HOME" RAI_PROVIDER=selfhosted RAI_STATIC_IP=9.8.7.6 \
    "$LIB_DIR/rai-init" --yes

  [ "$status" -eq 0 ]
  grep -q '^RAI_PROVIDER=selfhosted$' "$REPO/.rai/rai.conf"
  grep -q '^RAI_STATIC_IP=9.8.7.6$' "$REPO/.rai/rai.conf"
  ! grep -q '^RAI_SERVER=' "$REPO/.rai/rai.conf"
}

@test "rai-init: interactive, choosing selfhosted and typing an IP writes both values" {
  run bash -c "printf '2\n1.2.3.4\n' | env -C '$REPO' HOME='$FAKE_HOME' '$LIB_DIR/rai-init'"

  [ "$status" -eq 0 ]
  grep -q '^RAI_PROVIDER=selfhosted$' "$REPO/.rai/rai.conf"
  grep -q '^RAI_STATIC_IP=1.2.3.4$' "$REPO/.rai/rai.conf"
}

@test "rai-init: interactive, pressing Enter at each prompt accepts the resolved defaults" {
  run bash -c "printf '\n\n' | env -C '$REPO' HOME='$FAKE_HOME' '$LIB_DIR/rai-init'"

  [ "$status" -eq 0 ]
  grep -q '^RAI_PROVIDER=hetzner$' "$REPO/.rai/rai.conf"
  grep -q '^RAI_SERVER=rai$' "$REPO/.rai/rai.conf"
}

@test "rai-init: existing rai.conf, interactive decline (default No) leaves it untouched" {
  mkdir -p "$REPO/.rai"
  echo "RAI_SERVER=precious" > "$REPO/.rai/rai.conf"

  run bash -c "printf '\n' | env -C '$REPO' HOME='$FAKE_HOME' '$LIB_DIR/rai-init'"

  [ "$status" -ne 0 ]
  [ "$(cat "$REPO/.rai/rai.conf")" = "RAI_SERVER=precious" ]
}

@test "rai-init: existing rai.conf, --yes refuses outright" {
  mkdir -p "$REPO/.rai"
  echo "RAI_SERVER=precious" > "$REPO/.rai/rai.conf"

  run env -C "$REPO" HOME="$FAKE_HOME" "$LIB_DIR/rai-init" --yes

  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
  [ "$(cat "$REPO/.rai/rai.conf")" = "RAI_SERVER=precious" ]
}

@test "rai-init: existing rai.conf, interactive confirm (y) overwrites it" {
  mkdir -p "$REPO/.rai"
  echo "RAI_SERVER=precious" > "$REPO/.rai/rai.conf"

  run bash -c "printf 'y\n1\nnewname\n' | env -C '$REPO' HOME='$FAKE_HOME' '$LIB_DIR/rai-init'"

  [ "$status" -eq 0 ]
  grep -q '^RAI_SERVER=newname$' "$REPO/.rai/rai.conf"
}

@test "rai-init: round-trip - the generated file is valid input to rai-config" {
  run env -C "$REPO" HOME="$FAKE_HOME" RAI_PROVIDER=selfhosted RAI_STATIC_IP=5.5.5.5 \
    "$LIB_DIR/rai-init" --yes
  [ "$status" -eq 0 ]

  run env -C "$REPO" HOME="$FAKE_HOME" \
    bash -c "unset RAI_PROVIDER RAI_STATIC_IP; source '$LIB_DIR/rai-config'; printf '%s|%s' \"\$RAI_PROVIDER\" \"\$RAI_STATIC_IP\""

  [ "$status" -eq 0 ]
  [ "$output" = "selfhosted|5.5.5.5" ]
}

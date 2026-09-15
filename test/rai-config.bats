# Tests for rai-config's preset/restore precedence logic: an already-
# exported RAI_* env var must always win over both `.rai/config` files.
#
# rai-config is meant to be sourced (not executed), so each test sources it
# directly inside a `bash -c` snippet, with an isolated $HOME and a
# throwaway git repo used as cwd (rai-config finds RAI_REPO_ROOT itself via
# `git rev-parse --show-toplevel` against the caller's cwd, so pointing cwd
# at the fake repo is what makes it pick up that repo's `.rai/config`).
#
# Focused on RAI_STATIC_IP specifically: it was missing from
# `_rai_config_vars`, so unlike every other RAI_* var it wasn't part of the
# preset-capture/restore dance and got silently clobbered by either config
# file even when already exported.

load test_helper

setup() {
  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE_HOME/.rai"
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.rai"
  ( cd "$REPO" && git init -q )
}

@test "rai-config: exported RAI_STATIC_IP is not overwritten by repo .rai/config" {
  echo "RAI_STATIC_IP=from-repo-config" > "$REPO/.rai/config"

  run env -C "$REPO" HOME="$FAKE_HOME" RAI_STATIC_IP=from-env \
    bash -c "source '$REPO_ROOT/rai-config'; printf '%s' \"\$RAI_STATIC_IP\""

  [ "$status" -eq 0 ]
  [ "$output" = "from-env" ]
}

@test "rai-config: exported RAI_STATIC_IP is not overwritten by home .rai/config" {
  echo "RAI_STATIC_IP=from-home-config" > "$FAKE_HOME/.rai/config"

  run env -C "$REPO" HOME="$FAKE_HOME" RAI_STATIC_IP=from-env \
    bash -c "source '$REPO_ROOT/rai-config'; printf '%s' \"\$RAI_STATIC_IP\""

  [ "$status" -eq 0 ]
  [ "$output" = "from-env" ]
}

@test "rai-config: exported RAI_STATIC_IP is not overwritten when both config files set it" {
  echo "RAI_STATIC_IP=from-home-config" > "$FAKE_HOME/.rai/config"
  echo "RAI_STATIC_IP=from-repo-config" > "$REPO/.rai/config"

  run env -C "$REPO" HOME="$FAKE_HOME" RAI_STATIC_IP=from-env \
    bash -c "source '$REPO_ROOT/rai-config'; printf '%s' \"\$RAI_STATIC_IP\""

  [ "$status" -eq 0 ]
  [ "$output" = "from-env" ]
}

@test "rai-config: unexported RAI_STATIC_IP still picks up repo .rai/config" {
  # Sanity check that the fix doesn't break the still-lower-priority case:
  # config files must still apply when the var was never exported.
  echo "RAI_STATIC_IP=from-repo-config" > "$REPO/.rai/config"

  run env -C "$REPO" HOME="$FAKE_HOME" \
    bash -c "unset RAI_STATIC_IP; source '$REPO_ROOT/rai-config'; printf '%s' \"\$RAI_STATIC_IP\""

  [ "$status" -eq 0 ]
  [ "$output" = "from-repo-config" ]
}

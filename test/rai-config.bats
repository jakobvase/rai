# Tests for rai-config's preset/restore precedence logic and its
# `_rai_load_config_file` parser.
#
# rai-config is meant to be sourced (not executed), so each test sources it
# directly inside a `bash -c` snippet, with an isolated $HOME and a
# throwaway git repo used as cwd (rai-config finds RAI_REPO_ROOT itself via
# `git rev-parse --show-toplevel` against the caller's cwd, so pointing cwd
# at the fake repo is what makes it pick up that repo's `.rai/rai.conf`).
#
# The first group is focused on RAI_STATIC_IP specifically: it was missing
# from `_rai_config_vars`, so unlike every other RAI_* var it wasn't part of
# the preset-capture/restore dance and got silently clobbered by either
# config file even when already exported.
#
# The second group covers the config files no longer being `source`-d
# directly: since <repo-root>/.rai/rai.conf is meant to be committed and
# shared with the team, it's attacker-reachable (a malicious PR, a
# compromised fork), so these prove a config file can no longer run shell,
# leak into unrelated variables, or crash a `set -euo pipefail` caller.

load test_helper

setup() {
  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE_HOME/.rai"
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.rai"
  ( cd "$REPO" && git init -q )
}

@test "rai-config: exported RAI_STATIC_IP is not overwritten by repo .rai/rai.conf" {
  echo "RAI_STATIC_IP=from-repo-config" > "$REPO/.rai/rai.conf"

  run env -C "$REPO" HOME="$FAKE_HOME" RAI_STATIC_IP=from-env \
    bash -c "source '$REPO_ROOT/rai-config'; printf '%s' \"\$RAI_STATIC_IP\""

  [ "$status" -eq 0 ]
  [ "$output" = "from-env" ]
}

@test "rai-config: exported RAI_STATIC_IP is not overwritten by home .rai/rai.conf" {
  echo "RAI_STATIC_IP=from-home-config" > "$FAKE_HOME/.rai/rai.conf"

  run env -C "$REPO" HOME="$FAKE_HOME" RAI_STATIC_IP=from-env \
    bash -c "source '$REPO_ROOT/rai-config'; printf '%s' \"\$RAI_STATIC_IP\""

  [ "$status" -eq 0 ]
  [ "$output" = "from-env" ]
}

@test "rai-config: exported RAI_STATIC_IP is not overwritten when both config files set it" {
  echo "RAI_STATIC_IP=from-home-config" > "$FAKE_HOME/.rai/rai.conf"
  echo "RAI_STATIC_IP=from-repo-config" > "$REPO/.rai/rai.conf"

  run env -C "$REPO" HOME="$FAKE_HOME" RAI_STATIC_IP=from-env \
    bash -c "source '$REPO_ROOT/rai-config'; printf '%s' \"\$RAI_STATIC_IP\""

  [ "$status" -eq 0 ]
  [ "$output" = "from-env" ]
}

@test "rai-config: unexported RAI_STATIC_IP still picks up repo .rai/rai.conf" {
  # Sanity check that the fix doesn't break the still-lower-priority case:
  # config files must still apply when the var was never exported.
  echo "RAI_STATIC_IP=from-repo-config" > "$REPO/.rai/rai.conf"

  run env -C "$REPO" HOME="$FAKE_HOME" \
    bash -c "unset RAI_STATIC_IP; source '$REPO_ROOT/rai-config'; printf '%s' \"\$RAI_STATIC_IP\""

  [ "$status" -eq 0 ]
  [ "$output" = "from-repo-config" ]
}

# The following tests cover the switch from `source`-ing config files to
# parsing them: a committed <repo-root>/.rai/rai.conf is attacker-reachable
# (clone + malicious PR), so it must not be able to run shell no matter what
# it contains.

@test "rai-config: a shell payload after the value is not executed" {
  local sentinel="$BATS_TEST_TMPDIR/sentinel"
  echo "RAI_STATIC_IP=x; touch $sentinel" > "$REPO/.rai/rai.conf"

  run env -C "$REPO" HOME="$FAKE_HOME" \
    bash -c "unset RAI_STATIC_IP; source '$REPO_ROOT/rai-config'; printf '%s' \"\$RAI_STATIC_IP\""

  [ "$status" -eq 0 ]
  [ "$output" = "x; touch $sentinel" ]
  [ ! -e "$sentinel" ]
}

@test "rai-config: command substitution and backticks in a value are not executed" {
  local sentinel="$BATS_TEST_TMPDIR/sentinel"
  {
    echo "RAI_STATIC_IP=\$(touch $sentinel)"
    echo "RAI_SERVER=\`touch $sentinel\`"
  } > "$REPO/.rai/rai.conf"

  run env -C "$REPO" HOME="$FAKE_HOME" \
    bash -c "unset RAI_STATIC_IP RAI_SERVER; source '$REPO_ROOT/rai-config'; printf '%s|%s' \"\$RAI_STATIC_IP\" \"\$RAI_SERVER\""

  [ "$status" -eq 0 ]
  [ "$output" = "\$(touch $sentinel)|\`touch $sentinel\`" ]
  [ ! -e "$sentinel" ]
}

@test "rai-config: an unrecognized key does not leak into the environment" {
  echo "EVIL_VAR=foo" > "$REPO/.rai/rai.conf"

  # rai-config warns about the unrecognized key on stderr, which `run`
  # would otherwise merge into $output, so discard it here.
  run env -C "$REPO" HOME="$FAKE_HOME" \
    bash -c "source '$REPO_ROOT/rai-config' 2>/dev/null; printf '%s' \"\${EVIL_VAR:-unset}\""

  [ "$status" -eq 0 ]
  [ "$output" = "unset" ]
}

@test "rai-config: double-quoted value is unwrapped to its literal contents" {
  echo 'RAI_STATIC_IP="quoted value"' > "$REPO/.rai/rai.conf"

  run env -C "$REPO" HOME="$FAKE_HOME" \
    bash -c "unset RAI_STATIC_IP; source '$REPO_ROOT/rai-config'; printf '%s' \"\$RAI_STATIC_IP\""

  [ "$status" -eq 0 ]
  [ "$output" = "quoted value" ]
}

@test "rai-config: single-quoted value is unwrapped to its literal contents" {
  echo "RAI_STATIC_IP='quoted value'" > "$REPO/.rai/rai.conf"

  run env -C "$REPO" HOME="$FAKE_HOME" \
    bash -c "unset RAI_STATIC_IP; source '$REPO_ROOT/rai-config'; printf '%s' \"\$RAI_STATIC_IP\""

  [ "$status" -eq 0 ]
  [ "$output" = "quoted value" ]
}

@test "rai-config: a malformed line does not abort sourcing under set -euo pipefail" {
  {
    echo "this line has no equals sign"
    echo "RAI_STATIC_IP=from-repo-config"
  } > "$REPO/.rai/rai.conf"

  # rai-config warns about the malformed line on stderr, which `run` would
  # otherwise merge into $output, so discard it here.
  run env -C "$REPO" HOME="$FAKE_HOME" \
    bash -c "set -euo pipefail; unset RAI_STATIC_IP; source '$REPO_ROOT/rai-config' 2>/dev/null; printf '%s' \"\$RAI_STATIC_IP\""

  [ "$status" -eq 0 ]
  [ "$output" = "from-repo-config" ]
}

# The following tests cover the two hardening checks added on top of the
# parser: a value starting with `-` is never legitimate for any config var
# (it risks being parsed as a CLI option by ssh/scp/hcloud, or picking an
# unexpected provider file), and the final resolved RAI_PROVIDER must be one
# of the two providers rai-provider-* actually implements.

@test "rai-config: a value starting with '-' from repo .rai/rai.conf is ignored with a warning" {
  echo "RAI_STATIC_IP=-oProxyCommand=evil" > "$REPO/.rai/rai.conf"
  local stderr_file="$BATS_TEST_TMPDIR/stderr"

  run env -C "$REPO" HOME="$FAKE_HOME" \
    bash -c "unset RAI_STATIC_IP; source '$REPO_ROOT/rai-config' 2>'$stderr_file'; printf '%s' \"\${RAI_STATIC_IP:-unset}\""

  [ "$status" -eq 0 ]
  [ "$output" = "unset" ]
  grep -q "warning: ignoring value starting with '-'" "$stderr_file"
}

@test "rai-config: a value starting with '-' from home .rai/rai.conf is ignored with a warning" {
  echo "RAI_SERVER=-x" > "$FAKE_HOME/.rai/rai.conf"
  local stderr_file="$BATS_TEST_TMPDIR/stderr"

  run env -C "$REPO" HOME="$FAKE_HOME" \
    bash -c "unset RAI_SERVER; source '$REPO_ROOT/rai-config' 2>'$stderr_file'; printf '%s' \"\$RAI_SERVER\""

  [ "$status" -eq 0 ]
  # Falls back to the hardcoded default since the malicious value was rejected.
  [ "$output" = "rai" ]
  grep -q "warning: ignoring value starting with '-'" "$stderr_file"
}

@test "rai-config: an unrecognized RAI_PROVIDER fails loudly instead of being applied" {
  echo "RAI_PROVIDER=evilprovider" > "$REPO/.rai/rai.conf"
  local stderr_file="$BATS_TEST_TMPDIR/stderr"

  run env -C "$REPO" HOME="$FAKE_HOME" \
    bash -c "unset RAI_PROVIDER; source '$REPO_ROOT/rai-config' 2>'$stderr_file'"

  [ "$status" -ne 0 ]
  grep -q "error: unknown RAI_PROVIDER 'evilprovider'" "$stderr_file"
}

@test "rai-config: RAI_PROVIDER=hetzner is accepted" {
  run env -C "$REPO" HOME="$FAKE_HOME" RAI_PROVIDER=hetzner \
    bash -c "source '$REPO_ROOT/rai-config'; printf '%s' \"\$RAI_PROVIDER\""

  [ "$status" -eq 0 ]
  [ "$output" = "hetzner" ]
}

@test "rai-config: RAI_PROVIDER=selfhosted is accepted" {
  run env -C "$REPO" HOME="$FAKE_HOME" RAI_PROVIDER=selfhosted \
    bash -c "source '$REPO_ROOT/rai-config'; printf '%s' \"\$RAI_PROVIDER\""

  [ "$status" -eq 0 ]
  [ "$output" = "selfhosted" ]
}

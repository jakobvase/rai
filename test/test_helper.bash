# test_helper - shared setup for rai's bats tests.
# Loaded via `load test_helper` at the top of each .bats file.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# setup_stub_dir - create an empty dir and put it first on PATH, so tests can
# drop fake `hcloud`/`jq`/`ssh`/etc. binaries there to intercept calls the
# real scripts make, without touching the real system tools.
setup_stub_dir() {
  STUB_DIR="$(mktemp -d)"
  export STUB_DIR
  export PATH="$STUB_DIR:$PATH"
}

teardown_stub_dir() {
  [ -n "${STUB_DIR:-}" ] && rm -rf "$STUB_DIR"
}

# make_stub NAME BODY - write an executable stub script named NAME into
# $STUB_DIR with the given shell BODY.
make_stub() {
  local name="$1"
  local body="$2"
  cat > "$STUB_DIR/$name" <<STUB
#!/bin/bash
$body
STUB
  chmod +x "$STUB_DIR/$name"
}

# stub_ssh_eval - Install a fake `ssh` for injection-hardening tests.
# It records the exact argv it was invoked with (one arg per line) to
# $STUB_DIR/ssh_invocation, then `eval`s the trailing command-string
# argument locally - mimicking what a real remote login shell does
# (sshd ultimately runs something like `$SHELL -c "<command>"` on the
# far end). If a value was embedded in that command string without going
# through shell_quote() first, this is exactly where the injection would
# fire for real, so tests built on this stub assert on a side effect (e.g.
# a sentinel file NOT appearing) rather than just eyeballing the string.
stub_ssh_eval() {
  make_stub ssh '
    { printf "%s\n" "$@"; echo "---"; } >> "$STUB_DIR/ssh_invocation"
    cmd="${@: -1}"
    eval "$cmd"
  '
}

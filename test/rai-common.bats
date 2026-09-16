load test_helper

setup() {
  setup_stub_dir
}

teardown() {
  teardown_stub_dir
}

@test "require_ip echoes the ip when provider_ip succeeds" {
  provider_ip() { echo "1.2.3.4"; }
  source "$LIB_DIR/rai-common"
  run require_ip
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3.4" ]
}

@test "require_ip fails clearly when provider_ip returns the literal 'null'" {
  provider_ip() { echo "null"; }
  source "$LIB_DIR/rai-common"
  run require_ip
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not get VM IP"* ]]
}

@test "require_ip fails clearly when provider_ip returns empty" {
  provider_ip() { echo ""; }
  source "$LIB_DIR/rai-common"
  run require_ip
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not get VM IP"* ]]
}

@test "require_ip fails when provider_ip itself returns nonzero" {
  provider_ip() { return 1; }
  source "$LIB_DIR/rai-common"
  run require_ip
  [ "$status" -eq 1 ]
}

@test "remote_repo_path computes RAI_REMOTE_BASE/basename(RAI_REPO_ROOT)" {
  RAI_REPO_ROOT=/home/user/workspaces/myrepo
  RAI_REMOTE_BASE=/home/user/workspaces
  source "$LIB_DIR/rai-common"
  run remote_repo_path
  [ "$status" -eq 0 ]
  [ "$output" = "/home/user/workspaces/myrepo" ]
}

@test "remote_repo_path fails clearly when RAI_REPO_ROOT is empty" {
  RAI_REPO_ROOT=""
  RAI_REMOTE_BASE=/home/user/workspaces
  source "$LIB_DIR/rai-common"
  run remote_repo_path
  [ "$status" -eq 1 ]
  [[ "$output" == *"not inside a git repository"* ]]
}

@test "shell_quote produces a value that re-expands to the exact original, even with injection metacharacters" {
  source "$LIB_DIR/rai-common"
  malicious="foo'; touch $STUB_DIR/pwned; echo '"
  quoted=$(shell_quote "$malicious")
  result=$(eval "printf '%s' $quoted")
  [ "$result" = "$malicious" ]
  [ ! -e "$STUB_DIR/pwned" ]
}

@test "shell_quote passes through a plain value unchanged in effect" {
  source "$LIB_DIR/rai-common"
  plain="myrepo"
  quoted=$(shell_quote "$plain")
  result=$(eval "printf '%s' $quoted")
  [ "$result" = "$plain" ]
}

@test "shell_quote handles an empty string without crashing under set -euo pipefail" {
  source "$LIB_DIR/rai-common"
  run bash -c "set -euo pipefail; source '$LIB_DIR/rai-common'; shell_quote ''"
  [ "$status" -eq 0 ]
}

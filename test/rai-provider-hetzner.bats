load test_helper

setup() {
  setup_stub_dir
  # jq isn't assumed to be installed on the dev/test machine; stub a minimal
  # `-r '.field.path'` reader sufficient for this file's two lookups.
  make_stub jq '
    input=$(cat)
    if [ -z "$input" ]; then
      exit 1
    fi
    case "$2" in
      ".status")
        echo "$input" | grep -o "\"status\":\"[a-zA-Z]*\"" | cut -d"\"" -f4
        ;;
      ".public_net.ipv4.ip")
        echo "$input" | grep -o "\"ip\":\"[0-9.]*\"" | cut -d"\"" -f4
        ;;
    esac
  '
  RAI_SERVER=test-server
}

teardown() {
  teardown_stub_dir
}

@test "provider_ip returns the ip on success" {
  make_stub hcloud 'echo "{\"public_net\":{\"ipv4\":{\"ip\":\"1.2.3.4\"}}}"'
  source "$REPO_ROOT/rai-provider-hetzner"
  run provider_ip
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3.4" ]
}

@test "provider_ip fails clearly instead of emitting null/empty when hcloud fails" {
  make_stub hcloud 'exit 1'
  source "$REPO_ROOT/rai-provider-hetzner"
  run provider_ip
  [ "$status" -eq 1 ]
  [[ "$output" == *"hcloud failed"* ]]
  [[ "$output" != *"null"* ]]
}

@test "provider_status returns the status on success" {
  make_stub hcloud 'echo "{\"status\":\"running\"}"'
  source "$REPO_ROOT/rai-provider-hetzner"
  run provider_status
  [ "$status" -eq 0 ]
  [ "$output" = "running" ]
}

@test "provider_status fails clearly instead of emitting null/empty when hcloud fails" {
  make_stub hcloud 'exit 1'
  source "$REPO_ROOT/rai-provider-hetzner"
  run provider_status
  [ "$status" -eq 1 ]
  [[ "$output" == *"hcloud failed"* ]]
}

@test "provider_start returns immediately when already running" {
  make_stub hcloud 'echo "{\"status\":\"running\"}"'
  source "$REPO_ROOT/rai-provider-hetzner"
  run provider_start
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already running"* ]]
}

@test "provider_start polls and succeeds once the server comes up" {
  cat > "$STUB_DIR/hcloud" <<'STUB'
#!/bin/bash
n=$(cat "$STUB_COUNTER_FILE" 2>/dev/null || echo 0)
n=$((n+1))
echo "$n" > "$STUB_COUNTER_FILE"
if [ "$n" -le 2 ]; then
  echo '{"status":"starting"}'
else
  echo '{"status":"running"}'
fi
STUB
  chmod +x "$STUB_DIR/hcloud"
  echo 0 > "$STUB_DIR/counter"

  run timeout 5 bash -c "
    export PATH='$STUB_DIR:$PATH'
    export STUB_COUNTER_FILE='$STUB_DIR/counter'
    export RAI_SERVER='$RAI_SERVER'
    sleep() { :; }
    source '$REPO_ROOT/rai-provider-hetzner'
    provider_start
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"done."* ]]
}

@test "provider_start fails loudly (not an infinite dot loop) when hcloud errors mid-poll" {
  cat > "$STUB_DIR/hcloud" <<'STUB'
#!/bin/bash
n=$(cat "$STUB_COUNTER_FILE" 2>/dev/null || echo 0)
n=$((n+1))
echo "$n" > "$STUB_COUNTER_FILE"
if [ "$n" -le 2 ]; then
  echo '{"status":"starting"}'
elif [ "$n" -eq 3 ]; then
  exit 1
else
  echo '{"status":"running"}'
fi
STUB
  chmod +x "$STUB_DIR/hcloud"
  echo 0 > "$STUB_DIR/counter"

  # Bounded with `timeout` so a regression (spinning forever) fails the test
  # instead of hanging the suite.
  run timeout 5 bash -c "
    export PATH='$STUB_DIR:$PATH'
    export STUB_COUNTER_FILE='$STUB_DIR/counter'
    export RAI_SERVER='$RAI_SERVER'
    sleep() { :; }
    source '$REPO_ROOT/rai-provider-hetzner'
    provider_start
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"hcloud failed"* ]]
  [ "$(cat "$STUB_DIR/counter")" -eq 3 ]
}

@test "provider_stop fails clearly when hcloud fails" {
  make_stub hcloud 'exit 1'
  source "$REPO_ROOT/rai-provider-hetzner"
  run provider_stop
  [ "$status" -eq 1 ]
  [[ "$output" == *"hcloud failed"* ]]
}

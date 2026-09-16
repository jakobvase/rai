load test_helper

@test "provider_ip fails with the clean message (not an unbound-variable crash) when RAI_STATIC_IP is truly unset" {
  run bash -c "set -euo pipefail; unset RAI_STATIC_IP; source '$LIB_DIR/rai-provider-selfhosted'; provider_ip"
  [ "$status" -eq 1 ]
  [[ "$output" == *"RAI_STATIC_IP is not set"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

@test "provider_ip returns the configured address when RAI_STATIC_IP is exported" {
  run bash -c "set -euo pipefail; export RAI_STATIC_IP=10.0.0.5; source '$LIB_DIR/rai-provider-selfhosted'; provider_ip"
  [ "$status" -eq 0 ]
  [ "$output" = "10.0.0.5" ]
}

@test "provider_status reports running" {
  source "$LIB_DIR/rai-provider-selfhosted"
  run provider_status
  [ "$status" -eq 0 ]
  [ "$output" = "running" ]
}

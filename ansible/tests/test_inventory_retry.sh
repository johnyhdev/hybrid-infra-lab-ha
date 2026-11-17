#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../inventory/retry_inventory.sh"

calls=0
sleeps=0
failures_before_success=0
timeout() {
  ((calls += 1))
  [[ "$1" == "--kill-after=5s" && "$2" == "7s" && "$3" == "generator" && "$4" == "inventory.yml" ]]
  (( calls > failures_before_success ))
}
sleep() {
  [[ "$1" == "0" ]]
  ((sleeps += 1))
}

export PHASE8_INVENTORY_MAX_ATTEMPTS=3 PHASE8_INVENTORY_RETRY_SECONDS=0 PHASE8_INVENTORY_TIMEOUT_SECONDS=7
failures_before_success=2
generate_inventory_with_retry generator inventory.yml
[[ "$calls" -eq 3 && "$sleeps" -eq 2 ]]

calls=0 sleeps=0 failures_before_success=4
if generate_inventory_with_retry generator inventory.yml; then
  echo "Expected exhausted retries to fail" >&2
  exit 1
fi
[[ "$calls" -eq 3 && "$sleeps" -eq 2 ]]

calls=0 PHASE8_INVENTORY_MAX_ATTEMPTS=0
if generate_inventory_with_retry generator inventory.yml; then
  echo "Expected invalid retry configuration to fail" >&2
  exit 1
fi
[[ "$calls" -eq 0 ]]
echo "Inventory retry tests passed"
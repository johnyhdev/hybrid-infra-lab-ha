#!/usr/bin/env bash
# Source this helper and call generate_inventory_with_retry <generator> <output>.
generate_inventory_with_retry() {
  local generator="$1" output="$2" attempt status
  local max_attempts="${PHASE8_INVENTORY_MAX_ATTEMPTS:-12}"
  local delay="${PHASE8_INVENTORY_RETRY_SECONDS:-10}"
  local attempt_timeout="${PHASE8_INVENTORY_TIMEOUT_SECONDS:-60}"

  if [[ ! "$max_attempts" =~ ^[0-9]+$ || ! "$delay" =~ ^[0-9]+$ || ! "$attempt_timeout" =~ ^[0-9]+$ ]] ||
     (( max_attempts < 1 || max_attempts > 60 || delay > 300 || attempt_timeout < 1 || attempt_timeout > 600 )); then
    echo "Invalid inventory retry settings" >&2
    return 2
  fi

  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    if timeout --kill-after=5s "${attempt_timeout}s" "$generator" "$output"; then
      return 0
    else
      status=$?
    fi
    echo "Inventory discovery failed (attempt $attempt/$max_attempts, exit $status)." >&2
    if (( attempt < max_attempts )); then
      sleep "$delay"
    fi
  done
  echo "Inventory discovery did not succeed; deployment stopped without changing hosts." >&2
  return "$status"
}
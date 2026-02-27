#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${SECURITY_GATES_ENV:-docs/ai/security-gates.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: security gates config not found: $ENV_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

run_gate() {
  local name="$1"
  local cmd="$2"

  if [[ -z "$cmd" ]]; then
    echo "ERROR: $name command is empty in $ENV_FILE" >&2
    return 1
  fi

  if [[ "$cmd" == "__REQUIRED__" ]]; then
    echo "ERROR: $name is not configured. Update $ENV_FILE." >&2
    return 1
  fi

  if [[ "$cmd" == "skip" ]]; then
    echo "[security] $name: skipped"
    return 0
  fi

  echo "[security] $name: $cmd"
  bash -lc "$cmd"
}

run_gate "dependency-audit" "${DEPENDENCY_AUDIT_CMD:-}"
run_gate "secret-scan" "${SECRET_SCAN_CMD:-}"
run_gate "sast" "${SAST_CMD:-}"

echo "security-gates: PASS"

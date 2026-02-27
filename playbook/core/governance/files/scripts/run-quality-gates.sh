#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${QUALITY_GATES_ENV:-docs/ai/quality-gates.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: quality gates config not found: $ENV_FILE" >&2
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
    echo "[quality] $name: skipped"
    return 0
  fi

  echo "[quality] $name: $cmd"
  bash -lc "$cmd"
}

run_gate "lint" "${LINT_CMD:-}"
run_gate "typecheck" "${TYPECHECK_CMD:-}"
run_gate "tests" "${TEST_CMD:-}"
run_gate "build" "${BUILD_CMD:-}"

echo "quality-gates: PASS"

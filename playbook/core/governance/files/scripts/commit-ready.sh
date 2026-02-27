#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

run_step() {
  local name="$1"
  local cmd="$2"

  echo "[commit-ready] running: $name"
  if bash -lc "$cmd"; then
    echo "[commit-ready] PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "[commit-ready] FAIL: $name"
    FAIL=$((FAIL + 1))
  fi
}

run_step "quality-gates" "bash scripts/run-quality-gates.sh"
run_step "security-gates" "bash scripts/run-security-gates.sh"
run_step "dod-gate" "bash scripts/run-dod-gate.sh"

if [[ "$FAIL" -gt 0 ]]; then
  echo "commit-ready: FAIL (pass=$PASS fail=$FAIL)"
  exit 1
fi

echo "commit-ready: PASS (pass=$PASS fail=$FAIL)"

#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

check_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    echo "PASS: file exists -> $path"
    PASS=$((PASS + 1))
  else
    echo "FAIL: missing file -> $path"
    FAIL=$((FAIL + 1))
  fi
}

check_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if grep -Fq "$pattern" "$path"; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

check_file "docs/ai/definition-of-done.md"
check_file "docs/ai/rollback-plan.md"
check_file "docs/ai/architecture/adr/ADR-TEMPLATE.md"
check_file "docs/ai/serena-workflow.md"
check_file "docs/ai/serena-memory-policy.md"

if [[ -f "docs/ai/definition-of-done.md" ]]; then
  check_contains "docs/ai/definition-of-done.md" "[MANDATORY]" "DoD has mandatory checklist markers"
  check_contains "docs/ai/definition-of-done.md" "Serena" "DoD references Serena discipline"
fi

if [[ -f ".github/PULL_REQUEST_TEMPLATE.md" ]]; then
  check_contains ".github/PULL_REQUEST_TEMPLATE.md" "## Goal" "PR template has Goal section"
  check_contains ".github/PULL_REQUEST_TEMPLATE.md" "## Serena Context Used" "PR template has Serena Context Used section"
  check_contains ".github/PULL_REQUEST_TEMPLATE.md" "## Risk" "PR template has Risk section"
  check_contains ".github/PULL_REQUEST_TEMPLATE.md" "## Test Plan" "PR template has Test Plan section"
  check_contains ".github/PULL_REQUEST_TEMPLATE.md" "## Rollback Plan" "PR template has Rollback Plan section"
else
  echo "INFO: .github/PULL_REQUEST_TEMPLATE.md not found; PR-specific checks skipped (solo mode)"
fi

if [[ -f ".github/PULL_REQUEST_TEMPLATE.md" ]]; then
  if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" || "${GITHUB_EVENT_NAME:-}" == "pull_request_target" ]]; then
    if [[ -n "${GITHUB_EVENT_PATH:-}" && -f "${GITHUB_EVENT_PATH:-}" ]]; then
      if command -v python3 >/dev/null 2>&1; then
        PR_BODY="$(python3 - "$GITHUB_EVENT_PATH" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)
print((data.get('pull_request') or {}).get('body') or '')
PY
)"

        for section in "## Goal" "## Serena Context Used" "## Risk" "## Test Plan" "## Rollback Plan"; do
          if [[ "$PR_BODY" == *"$section"* ]]; then
            echo "PASS: PR body contains $section"
            PASS=$((PASS + 1))
          else
            echo "FAIL: PR body missing $section"
            FAIL=$((FAIL + 1))
          fi
        done
      else
        echo "FAIL: python3 is required to parse PR event payload in CI"
        FAIL=$((FAIL + 1))
      fi
    else
      echo "FAIL: GITHUB_EVENT_PATH is missing for pull_request event"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "INFO: non-PR context; PR body checks skipped"
  fi
fi

if [[ "$FAIL" -gt 0 ]]; then
  echo "dod-gate: FAIL (pass=$PASS fail=$FAIL)"
  exit 1
fi

echo "dod-gate: PASS (pass=$PASS fail=$FAIL)"

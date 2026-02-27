#!/usr/bin/env bash
set -euo pipefail

REPO=""
STRICT_CONTEXT=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/project-readiness-check.sh [--repo <owner/repo>] [--help]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

PASS=0
FAIL=0

pass() {
  echo "PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL: $1"
  FAIL=$((FAIL + 1))
}

require_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    pass "file exists -> $path"
  else
    fail "missing file -> $path"
  fi
}

extract_repo_from_origin() {
  local url
  url="$(git remote get-url origin 2>/dev/null || true)"
  if [[ -z "$url" ]]; then
    return 1
  fi

  if [[ "$url" =~ github.com[:/]([^/]+/[^/.]+)(\.git)?$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

check_serena_mcp() {
  if ! command -v codex >/dev/null 2>&1; then
    fail "codex CLI is required for Serena MCP verification"
    return
  fi

  local out
  if ! out="$(codex mcp get serena 2>/dev/null)"; then
    fail "Serena MCP is not registered in Codex"
    return
  fi

  if [[ "$out" != *"--context codex"* ]]; then
    fail "Serena MCP command must include '--context codex'"
    return
  fi

  if [[ "$out" == *"--project"* ]]; then
    fail "Serena MCP command must be global and must not include '--project'"
    return
  fi

  pass "Serena MCP is registered with required command shape"
}

require_file "AGENTS.md"
require_file "docs/ai/Flow.md"
require_file "docs/ai/definition-of-done.md"
require_file "docs/ai/architecture/adr/ADR-TEMPLATE.md"
require_file "docs/ai/release-checklist.md"
require_file "docs/ai/rollback-plan.md"
require_file "docs/ai/serena-workflow.md"
require_file "docs/ai/serena-memory-policy.md"
require_file "scripts/run-quality-gates.sh"
require_file "scripts/run-security-gates.sh"
require_file "scripts/run-dod-gate.sh"
require_file "scripts/commit-ready.sh"
require_file "docs/ai/global-personalization.md"

if [[ -f "docs/ai/global-personalization.done" ]]; then
  pass "global personalization completion file exists"
else
  fail "missing docs/ai/global-personalization.done (complete manual global setup)"
fi

if [[ -f ".github/workflows/ci.yml" || -f ".github/PULL_REQUEST_TEMPLATE.md" || -n "$REPO" ]]; then
  STRICT_CONTEXT=1
fi

if [[ "$STRICT_CONTEXT" -eq 1 ]]; then
  if [[ -z "$REPO" ]] && command -v git >/dev/null 2>&1; then
    REPO="$(extract_repo_from_origin || true)"
  fi

  if [[ -z "$REPO" ]]; then
    fail "strict project requires GitHub repo for branch protection verification (pass --repo or set origin)"
  elif [[ -x "scripts/github/verify-branch-protection.sh" ]]; then
    if scripts/github/verify-branch-protection.sh --repo "$REPO" >/dev/null; then
      pass "branch protection is configured for $REPO"
    else
      fail "branch protection verification failed for $REPO"
    fi
  else
    fail "missing scripts/github/verify-branch-protection.sh"
  fi
else
  echo "INFO: solo project context detected; branch protection check skipped"
fi

check_serena_mcp

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Project readiness: FAIL (pass=$PASS fail=$FAIL)"
  echo "Action: resolve FAIL items, then re-run scripts/project-readiness-check.sh"
  exit 1
fi

echo ""
echo "Project readiness: PASS (pass=$PASS fail=$FAIL)"

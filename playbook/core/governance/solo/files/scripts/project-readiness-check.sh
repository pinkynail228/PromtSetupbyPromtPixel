#!/usr/bin/env bash
set -euo pipefail

REPO=""
STRICT_MODE=0
STRICT_CONTEXT=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/project-readiness-check.sh [--repo <owner/repo>] [--strict] [--help]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --strict)
      STRICT_MODE=1
      shift
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
WARN=0
FAIL=0

pass() {
  echo "PASS: $1"
  PASS=$((PASS + 1))
}

warn() {
  echo "WARN: $1"
  WARN=$((WARN + 1))
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

require_executable() {
  local path="$1"
  if [[ -x "$path" ]]; then
    pass "executable -> $path"
  elif [[ -f "$path" ]]; then
    fail "file exists but is not executable -> $path"
  else
    fail "missing executable -> $path"
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

check_optional_serena() {
  local out

  if ! command -v codex >/dev/null 2>&1; then
    warn "codex CLI not found; Serena MCP verification skipped"
    return
  fi

  if ! out="$(codex mcp get serena 2>/dev/null)"; then
    warn "Serena MCP not registered in Codex (optional in default readiness)"
    return
  fi

  if [[ "$out" != *"--context codex"* ]]; then
    warn "Serena MCP command shape should include '--context codex'"
    return
  fi

  if [[ "$out" == *"--project"* ]]; then
    warn "Serena MCP command should be global and omit '--project'"
    return
  fi

  pass "optional Serena MCP registration is valid"
}

require_file "AGENTS.md"
require_file "docs/ai/Flow.md"
require_file "docs/ai/definition-of-done.md"
require_file "docs/ai/architecture/adr/ADR-TEMPLATE.md"
require_file "docs/ai/release-checklist.md"
require_file "docs/ai/rollback-plan.md"
require_file "docs/ai/context-workflow.md"
require_file "docs/ai/context-memory-policy.md"
require_file "docs/ai/global-personalization.md"

require_executable "scripts/run-quality-gates.sh"
require_executable "scripts/run-security-gates.sh"
require_executable "scripts/run-dod-gate.sh"
require_executable "scripts/commit-ready.sh"

if [[ -f "docs/ai/global-personalization.done" ]]; then
  pass "global personalization completion marker exists"
else
  warn "missing docs/ai/global-personalization.done (manual global setup not acknowledged)"
fi

if [[ -f ".github/workflows/ci.yml" || -f ".github/PULL_REQUEST_TEMPLATE.md" || -n "$REPO" ]]; then
  STRICT_CONTEXT=1
fi

if [[ "$STRICT_CONTEXT" -eq 1 ]]; then
  if [[ -z "$REPO" ]] && command -v git >/dev/null 2>&1; then
    REPO="$(extract_repo_from_origin || true)"
  fi

  if [[ -z "$REPO" ]]; then
    warn "strict context detected but GitHub repo is unknown (pass --repo or set origin)"
  elif [[ -x "scripts/github/verify-branch-protection.sh" ]]; then
    if scripts/github/verify-branch-protection.sh --repo "$REPO" >/dev/null 2>&1; then
      pass "branch protection verified for $REPO"
    else
      warn "branch protection verification failed for $REPO"
    fi
  else
    warn "missing scripts/github/verify-branch-protection.sh in strict context"
  fi
else
  echo "INFO: solo project context detected; branch protection check skipped"
fi

check_optional_serena

echo ""
if [[ "$FAIL" -gt 0 ]]; then
  echo "Project readiness: FAIL (pass=$PASS warn=$WARN fail=$FAIL)"
  echo "Action: resolve FAIL items, then re-run scripts/project-readiness-check.sh"
  exit 1
fi

if [[ "$WARN" -gt 0 ]]; then
  if [[ "$STRICT_MODE" -eq 1 ]]; then
    echo "Project readiness: FAIL(strict warnings) (pass=$PASS warn=$WARN fail=$FAIL)"
    echo "Action: resolve WARN items for strict readiness."
    exit 2
  fi
  echo "Project readiness: PASS with warnings (pass=$PASS warn=$WARN fail=$FAIL)"
  echo "Action: resolve WARN items to reach strict readiness."
  exit 0
fi

echo "Project readiness: PASS (pass=$PASS warn=$WARN fail=$FAIL)"

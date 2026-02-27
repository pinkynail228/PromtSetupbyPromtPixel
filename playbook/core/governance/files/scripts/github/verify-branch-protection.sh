#!/usr/bin/env bash
set -euo pipefail

REPO=""
BRANCH="main"

usage() {
  cat <<'USAGE'
Usage:
  verify-branch-protection.sh --repo <owner/repo> [--branch <name>] [--help]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --branch)
      BRANCH="${2:-}"
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

if [[ -z "$REPO" ]]; then
  echo "ERROR: --repo is required" >&2
  usage
  exit 2
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI is required" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: gh is not authenticated (run: gh auth login)" >&2
  exit 1
fi

get_field() {
  local query="$1"
  gh api -H "Accept: application/vnd.github+json" "/repos/$REPO/branches/$BRANCH/protection" --jq "$query" 2>/dev/null || true
}

PASS=0
FAIL=0

check_eq() {
  local label="$1"
  local query="$2"
  local expected="$3"
  local actual
  actual="$(get_field "$query")"
  if [[ "$actual" == "$expected" ]]; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label (expected=$expected actual=${actual:-<empty>})"
    FAIL=$((FAIL + 1))
  fi
}

check_contains_context() {
  local ctx="$1"
  local contexts
  contexts="$(get_field '.required_status_checks.contexts[]')"
  if printf '%s\n' "$contexts" | grep -Fxq "$ctx"; then
    echo "PASS: required status check includes $ctx"
    PASS=$((PASS + 1))
  else
    echo "FAIL: required status check missing $ctx"
    FAIL=$((FAIL + 1))
  fi
}

check_eq "require PR reviews" '.required_pull_request_reviews != null' "true"
check_eq "require 1 approval" '.required_pull_request_reviews.required_approving_review_count' "1"
check_eq "dismiss stale reviews" '.required_pull_request_reviews.dismiss_stale_reviews' "true"
check_eq "enforce admins" '.enforce_admins.enabled' "true"
check_eq "strict status checks" '.required_status_checks.strict' "true"

check_contains_context "quality-gates"
check_contains_context "security-gates"
check_contains_context "dod-gate"

if [[ "$FAIL" -gt 0 ]]; then
  echo "branch-protection: FAIL (pass=$PASS fail=$FAIL)"
  exit 1
fi

echo "branch-protection: PASS (pass=$PASS fail=$FAIL)"

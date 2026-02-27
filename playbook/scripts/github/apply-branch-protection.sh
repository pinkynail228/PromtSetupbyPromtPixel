#!/usr/bin/env bash
set -euo pipefail

REPO=""
BRANCH="main"

usage() {
  cat <<'USAGE'
Usage:
  apply-branch-protection.sh --repo <owner/repo> [--branch <name>] [--help]
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

PAYLOAD="$(cat <<JSON
{
  \"required_status_checks\": {
    \"strict\": true,
    \"contexts\": [\"quality-gates\", \"security-gates\", \"dod-gate\"]
  },
  \"enforce_admins\": true,
  \"required_pull_request_reviews\": {
    \"dismiss_stale_reviews\": true,
    \"required_approving_review_count\": 1,
    \"require_code_owner_reviews\": false,
    \"require_last_push_approval\": false
  },
  \"restrictions\": null,
  \"allow_force_pushes\": false,
  \"allow_deletions\": false,
  \"block_creations\": false,
  \"required_conversation_resolution\": true
}
JSON
)"

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/branches/$BRANCH/protection" \
  --input - <<<"$PAYLOAD" >/dev/null

echo "Applied strict branch protection to $REPO:$BRANCH"

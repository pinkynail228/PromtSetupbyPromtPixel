#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  check-profile.sh <profile> [--skills-root <path>] [--profile-root <path>]

Examples:
  check-profile.sh students-core
  check-profile.sh pro-core --skills-root ~/.agent/skills
  check-profile.sh students-core --profile-root ./playbook/curation
USAGE
}

PROFILE_NAME=""
SKILLS_ROOT="${AGENT_SKILLS_ROOT:-$HOME/.agent/skills}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_ROOT="$SCRIPT_DIR"

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

PROFILE_NAME="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skills-root)
      SKILLS_ROOT="${2:-}"
      shift 2
      ;;
    --profile-root)
      PROFILE_ROOT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1"
      usage
      exit 2
      ;;
  esac
done

PROFILE_FILE="$PROFILE_ROOT/${PROFILE_NAME}.txt"
if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "ERROR: profile not found: $PROFILE_FILE"
  exit 2
fi

resolve_skills_dir() {
  local root="$1"
  if [[ -d "$root/skills" ]]; then
    echo "$root/skills"
    return
  fi
  if [[ -d "$root" ]]; then
    echo "$root"
    return
  fi
  echo ""
}

SKILLS_DIR="$(resolve_skills_dir "$SKILLS_ROOT")"
if [[ -z "$SKILLS_DIR" ]]; then
  echo "ERROR: skills root not found: $SKILLS_ROOT"
  echo "Install skills on-demand, for example:"
  echo "  npx antigravity-awesome-skills --path ~/.agent/skills"
  exit 1
fi

missing=0
total=0

echo "Profile: $PROFILE_NAME"
echo "Profile file: $PROFILE_FILE"
echo "Skills directory: $SKILLS_DIR"

while IFS= read -r skill || [[ -n "$skill" ]]; do
  [[ -z "$skill" ]] && continue
  total=$((total + 1))
  if [[ -f "$SKILLS_DIR/$skill/SKILL.md" ]]; then
    echo "OK   $skill"
  else
    echo "MISS $skill"
    missing=$((missing + 1))
  fi
done < "$PROFILE_FILE"

echo "Summary: total=$total missing=$missing"
if [[ "$missing" -gt 0 ]]; then
  echo "Hint: install/update skills in $SKILLS_ROOT and re-run this check."
  exit 1
fi

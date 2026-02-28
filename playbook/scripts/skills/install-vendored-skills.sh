#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
VENDORED_DIR="$PLAYBOOK_DIR/skills/core"

TARGET=""
SKILLS_PATH=""
MODE="copy"

usage() {
  cat <<'USAGE'
Usage:
  install-vendored-skills.sh --target <path> [--skills-path <path>] [--mode <copy|verify>] [--help]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --skills-path)
      SKILLS_PATH="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
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

if [[ -z "$TARGET" ]]; then
  echo "ERROR: --target is required" >&2
  usage
  exit 2
fi

if [[ -z "$SKILLS_PATH" ]]; then
  SKILLS_PATH="$TARGET/.agent/skills"
fi

case "$MODE" in
  copy|verify) ;;
  *)
    echo "ERROR: unsupported --mode: $MODE" >&2
    exit 2
    ;;
esac

if [[ ! -d "$VENDORED_DIR" ]]; then
  echo "ERROR: vendored skills directory not found: $VENDORED_DIR" >&2
  exit 1
fi

missing=0
for skill_dir in "$VENDORED_DIR"/*; do
  [[ -d "$skill_dir" ]] || continue
  skill_name="$(basename "$skill_dir")"
  if [[ ! -f "$skill_dir/SKILL.md" ]]; then
    echo "ERROR: missing SKILL.md in vendored skill: $skill_name" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

if [[ "$MODE" == "copy" ]]; then
  mkdir -p "$SKILLS_PATH"
  for skill_dir in "$VENDORED_DIR"/*; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    rm -rf "$SKILLS_PATH/$skill_name"
    cp -R "$skill_dir" "$SKILLS_PATH/$skill_name"
  done
  echo "Installed vendored skills to: $SKILLS_PATH"
  exit 0
fi

for skill_dir in "$VENDORED_DIR"/*; do
  [[ -d "$skill_dir" ]] || continue
  skill_name="$(basename "$skill_dir")"
  if [[ -f "$SKILLS_PATH/$skill_name/SKILL.md" ]]; then
    echo "OK   $skill_name"
  else
    echo "MISS $skill_name"
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "Verification failed for skills path: $SKILLS_PATH" >&2
  exit 1
fi

echo "Vendored skills verification passed: $SKILLS_PATH"

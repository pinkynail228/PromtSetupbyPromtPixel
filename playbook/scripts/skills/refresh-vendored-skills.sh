#!/usr/bin/env bash
set -euo pipefail

MANIFEST=""
SOURCE=""
REF=""

usage() {
  cat <<'USAGE'
Usage:
  refresh-vendored-skills.sh --manifest <path> --source <git|local> --ref <tag|sha> [--help]

Notes:
  - This script updates manifest metadata only.
  - It does not auto-fetch remote content.
  - After updating metadata, refresh skill files manually or via your internal process.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      MANIFEST="${2:-}"
      shift 2
      ;;
    --source)
      SOURCE="${2:-}"
      shift 2
      ;;
    --ref)
      REF="${2:-}"
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

if [[ -z "$MANIFEST" || -z "$SOURCE" || -z "$REF" ]]; then
  echo "ERROR: --manifest, --source, and --ref are required" >&2
  usage
  exit 2
fi

case "$SOURCE" in
  git|local) ;;
  *)
    echo "ERROR: --source must be one of: git local" >&2
    exit 2
    ;;
esac

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: manifest not found: $MANIFEST" >&2
  exit 1
fi

timestamp="$(date -u '+%Y-%m-%d')"

tmp_file="$(mktemp)"
awk -v src="$SOURCE" -v ref="$REF" -v ts="$timestamp" '
  BEGIN {updated_source=0; updated_ref=0; updated_time=0}
  /^source_mode = / {print "source_mode = \"" src "\""; updated_source=1; next}
  /^source_ref = / {print "source_ref = \"" ref "\""; updated_ref=1; next}
  /^updated_at = / {print "updated_at = \"" ts "\""; updated_time=1; next}
  {print}
  END {
    if (!updated_source) print "source_mode = \"" src "\""
    if (!updated_ref) print "source_ref = \"" ref "\""
    if (!updated_time) print "updated_at = \"" ts "\""
  }
' "$MANIFEST" > "$tmp_file"
mv "$tmp_file" "$MANIFEST"

echo "Updated manifest metadata: $MANIFEST"
echo "source_mode=$SOURCE"
echo "source_ref=$REF"
echo "updated_at=$timestamp"

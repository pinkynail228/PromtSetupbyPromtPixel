#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bootstrap.sh --target <path> [--mode <solo|strict>] [--governance <required|off>]
               [--agent <codex|claude|cursor|antigravity|none>]
               [--language <id|none>] [--skills <vendored|off>] [--skills-path <path>]
               [--with-serena] [--with-codex-mcp] [--tooling-strict]
               [--github-repo <owner/repo>] [--help]

Options:
  --target <path>               Required path to target project
  --mode <mode>                 solo|strict (default: solo)
  --governance <mode>           required|off (optional override)
  --agent <name>                codex|claude|cursor|antigravity|none (default: none)
  --language <name>             language adapter id or none (default: none)
  --skills <mode>               vendored|off (default: vendored)
  --skills-path <path>          Install path for vendored skills (default: <target>/.agent/skills)
  --with-serena                 Run optional Serena installation step
  --with-codex-mcp              Run optional Codex MCP registration (requires --with-serena)
  --tooling-strict              Fail bootstrap when optional tooling steps fail
  --github-repo <owner/repo>    Optional GitHub repo for branch protection apply in strict governance
  --help                        Show help

Governance resolution:
  mode=solo   -> governance default=off
  mode=strict -> governance default=required
  Explicit --governance overrides mode-derived default.
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_DIR="$PLAYBOOK_DIR/core"
ADAPTERS_DIR="$PLAYBOOK_DIR/adapters"
STRICT_GOVERNANCE_FILES_DIR="$CORE_DIR/governance/files"
SOLO_GOVERNANCE_FILES_DIR="$CORE_DIR/governance/solo/files"
GLOBAL_GUIDE_TEMPLATE="$CORE_DIR/templates/global-personalization.md"
SETUP_DOC="$PLAYBOOK_DIR/setup.md"
SERENA_HELPER="$SCRIPT_DIR/install-serena-mcp.sh"
SKILLS_INSTALLER="$SCRIPT_DIR/skills/install-vendored-skills.sh"
GITHUB_APPLY_HELPER="$SCRIPT_DIR/github/apply-branch-protection.sh"
SERENA_TOOLING_FILES_DIR="$ADAPTERS_DIR/tooling/serena/files"

TARGET=""
MODE="solo"
GOVERNANCE=""
AGENT="none"
LANGUAGE="none"
SKILLS="vendored"
SKILLS_PATH=""
WITH_SERENA=0
WITH_CODEX_MCP=0
TOOLING_STRICT=0
GITHUB_REPO=""
TOOLING_WARNINGS=0

list_dir_names() {
  local dir="$1"
  find "$dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

warn() {
  echo "WARN: $*" >&2
}

die() {
  echo "ERROR: $*" >&2
  exit 2
}

governance_from_mode() {
  case "$1" in
    solo) echo "off" ;;
    strict) echo "required" ;;
    *) die "unknown --mode value: $1" ;;
  esac
}

apply_files_dir() {
  local files_dir="$1"
  [[ -d "$files_dir" ]] || return 0

  while IFS= read -r -d '' src; do
    local rel dst
    rel="${src#$files_dir/}"
    dst="$TARGET/$rel"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  done < <(find "$files_dir" -type f -print0)
}

write_github_protection_status() {
  local status="$1"
  local reason="$2"
  mkdir -p "$TARGET/docs/ai"
  cat > "$TARGET/docs/ai/github-protection.status" <<EOF_STATUS
STATUS=$status
REPO=${GITHUB_REPO:-none}
REASON=$reason
EOF_STATUS
}

run_optional_tooling_step() {
  local label="$1"
  shift
  local rc=0
  local output=""

  set +e
  output="$($@ 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    echo "$output"
    return 0
  fi

  if [[ "$TOOLING_STRICT" -eq 1 ]]; then
    echo "$output" >&2
    echo "ERROR: optional tooling step failed in strict mode: $label" >&2
    exit 1
  fi

  warn "$label failed (non-blocking):"
  warn "$output"
  TOOLING_WARNINGS=$((TOOLING_WARNINGS + 1))
  return 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --governance)
      GOVERNANCE="${2:-}"
      shift 2
      ;;
    --agent)
      AGENT="${2:-}"
      shift 2
      ;;
    --language)
      LANGUAGE="${2:-}"
      shift 2
      ;;
    --skills)
      SKILLS="${2:-}"
      shift 2
      ;;
    --skills-path)
      SKILLS_PATH="${2:-}"
      shift 2
      ;;
    --with-serena)
      WITH_SERENA=1
      shift
      ;;
    --with-codex-mcp)
      WITH_CODEX_MCP=1
      shift
      ;;
    --tooling-strict)
      TOOLING_STRICT=1
      shift
      ;;
    --github-repo)
      GITHUB_REPO="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[[ -n "$TARGET" ]] || die "--target is required"
[[ "$MODE" == "solo" || "$MODE" == "strict" ]] || die "--mode must be solo or strict"

if [[ -z "$GOVERNANCE" ]]; then
  GOVERNANCE="$(governance_from_mode "$MODE")"
fi
[[ "$GOVERNANCE" == "required" || "$GOVERNANCE" == "off" ]] || die "--governance must be required or off"

if [[ "$AGENT" != "none" ]] && [[ ! -d "$ADAPTERS_DIR/agents/$AGENT" ]]; then
  die "unknown --agent: $AGENT (available: $(list_dir_names "$ADAPTERS_DIR/agents" | tr '\n' ' ') none)"
fi

if [[ "$LANGUAGE" != "none" ]] && [[ ! -d "$ADAPTERS_DIR/languages/$LANGUAGE" ]]; then
  die "unknown --language: $LANGUAGE (available: $(list_dir_names "$ADAPTERS_DIR/languages" | tr '\n' ' ') none)"
fi

[[ "$SKILLS" == "vendored" || "$SKILLS" == "off" ]] || die "--skills must be vendored or off"

if [[ "$WITH_CODEX_MCP" -eq 1 ]] && [[ "$WITH_SERENA" -ne 1 ]]; then
  die "--with-codex-mcp requires --with-serena"
fi

if [[ -z "$SKILLS_PATH" ]]; then
  SKILLS_PATH="$TARGET/.agent/skills"
fi

[[ -f "$GLOBAL_GUIDE_TEMPLATE" ]] || die "missing template: $GLOBAL_GUIDE_TEMPLATE"
[[ -x "$SKILLS_INSTALLER" ]] || die "missing skills installer: $SKILLS_INSTALLER"
[[ -x "$SERENA_HELPER" ]] || die "missing Serena helper: $SERENA_HELPER"

mkdir -p "$TARGET/docs/ai/templates"

cp "$CORE_DIR/AGENTS.md" "$TARGET/AGENTS.md"
cp "$CORE_DIR/Flow.md" "$TARGET/docs/ai/Flow.md"
cp "$CORE_DIR/templates/plan.md" "$TARGET/docs/ai/templates/plan.md"
cp "$CORE_DIR/templates/report.md" "$TARGET/docs/ai/templates/report.md"
cp "$CORE_DIR/templates/context-provider-guide.md" "$TARGET/docs/ai/templates/context-provider-guide.md"
cp "$SETUP_DOC" "$TARGET/docs/ai/setup.md"

if [[ "$GOVERNANCE" == "required" ]]; then
  apply_files_dir "$STRICT_GOVERNANCE_FILES_DIR"
else
  apply_files_dir "$SOLO_GOVERNANCE_FILES_DIR"
fi

if [[ "$AGENT" != "none" ]]; then
  apply_files_dir "$ADAPTERS_DIR/agents/$AGENT/files"
fi

if [[ "$LANGUAGE" != "none" ]]; then
  apply_files_dir "$ADAPTERS_DIR/languages/$LANGUAGE/files"
fi

if [[ "$WITH_SERENA" -eq 1 ]]; then
  apply_files_dir "$SERENA_TOOLING_FILES_DIR"
fi

if [[ "$SKILLS" == "vendored" ]]; then
  "$SKILLS_INSTALLER" --target "$TARGET" --skills-path "$SKILLS_PATH" --mode copy
fi

mkdir -p "$TARGET/docs/ai"
cp "$GLOBAL_GUIDE_TEMPLATE" "$TARGET/docs/ai/global-personalization.md"

cat > "$TARGET/docs/ai/playbook-selection.md" <<EOF_SELECTION
# Playbook selection

- mode: $MODE
- effective_governance: $GOVERNANCE
- agent: $AGENT
- language: $LANGUAGE
- skills: $SKILLS
- skills_path: $SKILLS_PATH
- with_serena: $WITH_SERENA
- with_codex_mcp: $WITH_CODEX_MCP
- tooling_strict: $TOOLING_STRICT
- github_repo: ${GITHUB_REPO:-none}
EOF_SELECTION

if [[ "$GOVERNANCE" == "required" ]]; then
  if [[ -z "$GITHUB_REPO" ]]; then
    write_github_protection_status "manual-required" "no --github-repo provided"
    warn "strict governance enabled, but --github-repo not provided"
  elif ! command -v gh >/dev/null 2>&1; then
    write_github_protection_status "manual-required" "gh CLI not available"
    warn "strict governance enabled, but gh CLI is not available"
  elif ! gh auth status >/dev/null 2>&1; then
    write_github_protection_status "manual-required" "gh CLI not authenticated"
    warn "strict governance enabled, but gh CLI is not authenticated"
  elif [[ -x "$GITHUB_APPLY_HELPER" ]] && "$GITHUB_APPLY_HELPER" --repo "$GITHUB_REPO"; then
    write_github_protection_status "applied" "auto-applied by bootstrap"
    echo "GitHub protection applied for $GITHUB_REPO"
  else
    write_github_protection_status "manual-required" "auto-apply failed"
    warn "failed to auto-apply branch protection for $GITHUB_REPO"
  fi
else
  write_github_protection_status "skipped" "governance=off"
fi

if [[ "$WITH_SERENA" -eq 1 ]]; then
  run_optional_tooling_step "Serena install" "$SERENA_HELPER" --phase install

  if [[ "$WITH_CODEX_MCP" -eq 1 ]]; then
    run_optional_tooling_step "Serena Codex MCP registration" "$SERENA_HELPER" --phase codex-mcp
    run_optional_tooling_step "Serena Codex MCP verify" "$SERENA_HELPER" --phase verify
  fi
fi

if [[ -d "$TARGET/scripts" ]]; then
  find "$TARGET/scripts" -type f -name '*.sh' -exec chmod +x {} +
fi

echo "Bootstrap complete"
echo "Target: $TARGET"
echo "Mode: $MODE"
echo "Effective governance: $GOVERNANCE"
echo "Agent adapter: $AGENT"
echo "Language adapter: $LANGUAGE"
echo "Skills: $SKILLS"
echo "Skills path: $SKILLS_PATH"
echo "Serena tooling: $([[ "$WITH_SERENA" -eq 1 ]] && echo enabled || echo disabled)"
echo "Codex MCP setup: $([[ "$WITH_CODEX_MCP" -eq 1 ]] && echo enabled || echo disabled)"
echo "Tooling strict: $TOOLING_STRICT"
echo "GitHub repo: ${GITHUB_REPO:-none}"
echo "TODO: Complete docs/ai/global-personalization.md."
echo "TODO: Optionally mark completion in docs/ai/global-personalization.done."
echo "TODO: Run scripts/commit-ready.sh before each commit."
echo "TODO: Run scripts/project-readiness-check.sh (or --strict) and resolve findings."

if [[ "$TOOLING_WARNINGS" -gt 0 ]]; then
  echo "NOTE: optional tooling produced $TOOLING_WARNINGS warning(s)."
fi

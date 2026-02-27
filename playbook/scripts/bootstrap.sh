#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bootstrap.sh --target <path> [--mode <solo|strict>] [--agent <name>] [--language <name>] [--profile <name>]
               [--governance <required|off>] [--github-repo <owner/repo>]
               [--resume] [--state-file <path>] [--force-restart]
               [--no-serena] [--serena-codex-mcp <required|off>] [--help]

Options:
  --target <path>               Required path to target project (required unless --resume with --state-file)
  --mode <mode>                 solo|strict (default: solo)
  --agent <name>                codex|claude|cursor|antigravity|none (default: none)
  --language <name>             language adapter id or none (default: none)
  --profile <name>              minimal|students|pro (default: minimal)
  --governance <mode>           required|off (default derived from --mode)
  --github-repo <owner/repo>    Optional GitHub repo for auto branch protection (main)
  --resume                      Resume from existing state file
  --state-file <path>           State file path (default: <target>/.playbook-bootstrap.state)
  --force-restart               Delete state and restart from scratch
  --no-serena                   Skip Serena install and Codex MCP registration
  --serena-codex-mcp <mode>     required|off (default: required)
  --help                        Show help

Governance resolution:
  mode=solo   -> governance default=off
  mode=strict -> governance default=required
  Explicit --governance always overrides mode-derived default.

Exit codes:
  0   success
  1   generic failure
  2   invalid arguments/preflight
  20  blocked (resume required)
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_DIR="$PLAYBOOK_DIR/core"
ADAPTERS_DIR="$PLAYBOOK_DIR/adapters"
CURATION_DIR="$PLAYBOOK_DIR/curation"
STATE_LIB="$SCRIPT_DIR/lib/state.sh"
SERENA_HELPER="$SCRIPT_DIR/install-serena-mcp.sh"
GLOBAL_GUIDE_TEMPLATE="$CORE_DIR/templates/global-personalization.md"
STRICT_GOVERNANCE_FILES_DIR="$CORE_DIR/governance/files"
SOLO_GOVERNANCE_FILES_DIR="$CORE_DIR/governance/solo/files"
GITHUB_APPLY_HELPER="$SCRIPT_DIR/github/apply-branch-protection.sh"

if [[ ! -f "$STATE_LIB" ]]; then
  echo "ERROR: missing state library: $STATE_LIB" >&2
  exit 2
fi

if [[ ! -x "$SERENA_HELPER" ]]; then
  echo "ERROR: missing Serena helper script: $SERENA_HELPER" >&2
  exit 2
fi

if [[ ! -f "$GLOBAL_GUIDE_TEMPLATE" ]]; then
  echo "ERROR: missing global personalization template: $GLOBAL_GUIDE_TEMPLATE" >&2
  exit 2
fi

if [[ ! -d "$STRICT_GOVERNANCE_FILES_DIR" ]]; then
  echo "ERROR: missing strict governance templates: $STRICT_GOVERNANCE_FILES_DIR" >&2
  exit 2
fi

if [[ ! -d "$SOLO_GOVERNANCE_FILES_DIR" ]]; then
  echo "ERROR: missing solo governance templates: $SOLO_GOVERNANCE_FILES_DIR" >&2
  exit 2
fi

if [[ ! -x "$GITHUB_APPLY_HELPER" ]]; then
  echo "ERROR: missing GitHub protection helper: $GITHUB_APPLY_HELPER" >&2
  exit 2
fi

# shellcheck disable=SC1090
source "$STATE_LIB"

TARGET=""
MODE="solo"
AGENT="none"
LANGUAGE="none"
PROFILE="minimal"
GOVERNANCE=""
GITHUB_REPO=""
RESUME=0
STATE_FILE=""
FORCE_RESTART=0
NO_SERENA=0
SERENA_CODEX_MCP="required"

MODE_SET=0
AGENT_SET=0
LANGUAGE_SET=0
PROFILE_SET=0
GOVERNANCE_SET=0
GITHUB_REPO_SET=0
NO_SERENA_SET=0
SERENA_CODEX_MCP_SET=0

STEP_BLOCK_REASON=""
STEP_BLOCK_HINT=""

list_dir_names() {
  local dir="$1"
  find "$dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
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

set_block_context() {
  STEP_BLOCK_REASON="$1"
  STEP_BLOCK_HINT="$2"
}

build_resume_hint() {
  printf '%s --target %q --resume --state-file %q' "$0" "$TARGET" "$STATE_FILE"
}

governance_from_mode() {
  local mode="$1"
  case "$mode" in
    solo) printf 'off\n' ;;
    strict) printf 'required\n' ;;
    *)
      echo "ERROR: unknown --mode value: $mode" >&2
      echo "Available: solo strict" >&2
      exit 2
      ;;
  esac
}

resolve_effective_governance() {
  if [[ "$GOVERNANCE_SET" == "1" ]]; then
    return 0
  fi
  GOVERNANCE="$(governance_from_mode "$MODE")"
}

write_github_protection_status() {
  local status="$1"
  local reason="$2"
  mkdir -p "$TARGET/docs/ai"
  cat > "$TARGET/docs/ai/github-protection.status" <<EOF_STATUS
STATUS=$status
REPO=$GITHUB_REPO
REASON=$reason
EOF_STATUS
}

validate_agent_language_profile() {
  case "$MODE" in
    solo|strict) ;;
    *)
      echo "ERROR: unknown --mode value: $MODE" >&2
      echo "Available: solo strict" >&2
      exit 2
      ;;
  esac

  if [[ "$AGENT" != "none" ]] && [[ ! -d "$ADAPTERS_DIR/agents/$AGENT" ]]; then
    echo "ERROR: unknown agent adapter: $AGENT" >&2
    echo "Available: $(list_dir_names "$ADAPTERS_DIR/agents" | tr '\n' ' ') none" >&2
    exit 2
  fi

  if [[ "$LANGUAGE" != "none" ]] && [[ ! -d "$ADAPTERS_DIR/languages/$LANGUAGE" ]]; then
    echo "ERROR: unknown language adapter: $LANGUAGE" >&2
    echo "Available: $(list_dir_names "$ADAPTERS_DIR/languages" | tr '\n' ' ') none" >&2
    exit 2
  fi

  case "$PROFILE" in
    minimal|students|pro) ;;
    *)
      echo "ERROR: unknown profile: $PROFILE" >&2
      echo "Available: minimal students pro" >&2
      exit 2
      ;;
  esac

  case "$GOVERNANCE" in
    required|off) ;;
    *)
      echo "ERROR: unknown --governance mode: $GOVERNANCE" >&2
      echo "Available: required off" >&2
      exit 2
      ;;
  esac

  case "$SERENA_CODEX_MCP" in
    required|off) ;;
    *)
      echo "ERROR: unknown --serena-codex-mcp mode: $SERENA_CODEX_MCP" >&2
      echo "Available: required off" >&2
      exit 2
      ;;
  esac
}

handle_new_run_init() {
  local cli_target="$TARGET"
  local cli_mode="$MODE"
  local cli_agent="$AGENT"
  local cli_language="$LANGUAGE"
  local cli_profile="$PROFILE"
  local cli_governance="$GOVERNANCE"
  local cli_github_repo="$GITHUB_REPO"
  local cli_no_serena="$NO_SERENA"
  local cli_serena_codex_mcp="$SERENA_CODEX_MCP"
  local effective_governance=""

  if [[ -z "$cli_target" ]]; then
    echo "ERROR: --target is required" >&2
    usage
    exit 2
  fi

  if [[ -z "$STATE_FILE" ]]; then
    STATE_FILE="$cli_target/.playbook-bootstrap.state"
  fi

  if [[ "$FORCE_RESTART" == "1" ]]; then
    rm -f "$STATE_FILE"
  fi

  TARGET="$cli_target"
  MODE="$cli_mode"
  AGENT="$cli_agent"
  LANGUAGE="$cli_language"
  PROFILE="$cli_profile"
  GOVERNANCE="$cli_governance"
  GITHUB_REPO="$cli_github_repo"
  NO_SERENA="$cli_no_serena"
  SERENA_CODEX_MCP="$cli_serena_codex_mcp"

  resolve_effective_governance
  effective_governance="$GOVERNANCE"
  validate_agent_language_profile

  state_reset_defaults
  VERSION="3"
  TARGET="$cli_target"
  MODE="$cli_mode"
  AGENT="$cli_agent"
  LANGUAGE="$cli_language"
  PROFILE="$cli_profile"
  GOVERNANCE="$effective_governance"
  GITHUB_REPO="$cli_github_repo"
  NO_SERENA="$cli_no_serena"
  SERENA_CODEX_MCP="$cli_serena_codex_mcp"

  mkdir -p "$(dirname "$STATE_FILE")"
  state_save "$STATE_FILE"
}

handle_resume_init() {
  local cli_target="$TARGET"
  local cli_mode="$MODE"
  local cli_agent="$AGENT"
  local cli_language="$LANGUAGE"
  local cli_profile="$PROFILE"
  local cli_governance="$GOVERNANCE"
  local cli_github_repo="$GITHUB_REPO"
  local cli_no_serena="$NO_SERENA"
  local cli_serena_codex_mcp="$SERENA_CODEX_MCP"

  if [[ -z "$STATE_FILE" ]]; then
    if [[ -z "$cli_target" ]]; then
      echo "ERROR: provide --target or --state-file when using --resume" >&2
      exit 2
    fi
    STATE_FILE="$cli_target/.playbook-bootstrap.state"
  fi

  if [[ ! -f "$STATE_FILE" ]]; then
    echo "ERROR: state file not found for --resume: $STATE_FILE" >&2
    exit 2
  fi

  state_load "$STATE_FILE"

  if [[ -n "$cli_target" ]] && [[ "$cli_target" != "$TARGET" ]]; then
    echo "ERROR: target mismatch between arguments and state file" >&2
    exit 2
  fi

  if [[ "$MODE_SET" == "1" ]] && [[ "$cli_mode" != "$MODE" ]]; then
    echo "ERROR: --mode cannot change on --resume" >&2
    exit 2
  fi

  if [[ "$AGENT_SET" == "1" ]] && [[ "$cli_agent" != "$AGENT" ]]; then
    echo "ERROR: --agent cannot change on --resume" >&2
    exit 2
  fi

  if [[ "$LANGUAGE_SET" == "1" ]] && [[ "$cli_language" != "$LANGUAGE" ]]; then
    echo "ERROR: --language cannot change on --resume" >&2
    exit 2
  fi

  if [[ "$PROFILE_SET" == "1" ]] && [[ "$cli_profile" != "$PROFILE" ]]; then
    echo "ERROR: --profile cannot change on --resume" >&2
    exit 2
  fi

  if [[ "$GOVERNANCE_SET" == "1" ]] && [[ "$cli_governance" != "$GOVERNANCE" ]]; then
    echo "ERROR: --governance cannot change on --resume" >&2
    exit 2
  fi

  if [[ "$GITHUB_REPO_SET" == "1" ]] && [[ "$cli_github_repo" != "$GITHUB_REPO" ]]; then
    echo "ERROR: --github-repo cannot change on --resume" >&2
    exit 2
  fi

  if [[ "$NO_SERENA_SET" == "1" ]]; then
    NO_SERENA="$cli_no_serena"
  fi

  if [[ "$SERENA_CODEX_MCP_SET" == "1" ]]; then
    SERENA_CODEX_MCP="$cli_serena_codex_mcp"
  fi

  validate_agent_language_profile
  state_save "$STATE_FILE"
}

step_core() {
  mkdir -p "$TARGET/docs/ai/templates"
  cp "$CORE_DIR/AGENTS.md" "$TARGET/AGENTS.md"
  cp "$CORE_DIR/Flow.md" "$TARGET/docs/ai/Flow.md"
  cp "$CORE_DIR/templates/plan.md" "$TARGET/docs/ai/templates/plan.md"
  cp "$CORE_DIR/templates/report.md" "$TARGET/docs/ai/templates/report.md"
  cp "$PLAYBOOK_DIR/setup.md" "$TARGET/docs/ai/setup.md"
}

step_governance_files() {
  if [[ "$GOVERNANCE" == "required" ]]; then
    apply_files_dir "$STRICT_GOVERNANCE_FILES_DIR"
  else
    apply_files_dir "$SOLO_GOVERNANCE_FILES_DIR"
  fi

  if [[ -d "$TARGET/scripts" ]]; then
    find "$TARGET/scripts" -type f -name '*.sh' -exec chmod +x {} +
  fi
}

step_adapters() {
  if [[ "$AGENT" != "none" ]]; then
    apply_files_dir "$ADAPTERS_DIR/agents/$AGENT/files"
  fi

  if [[ "$LANGUAGE" != "none" ]]; then
    apply_files_dir "$ADAPTERS_DIR/languages/$LANGUAGE/files"
  fi

  if [[ "$PROFILE" == "students" || "$PROFILE" == "pro" ]]; then
    mkdir -p "$TARGET/docs/ai/curation"
    cp "$CURATION_DIR/${PROFILE}-core.txt" "$TARGET/docs/ai/curation/skills-profile.txt"
    cp "$CURATION_DIR/README.md" "$TARGET/docs/ai/curation/README.md"
  fi
}

step_selection() {
  mkdir -p "$TARGET/docs/ai"
  cat > "$TARGET/docs/ai/playbook-selection.md" <<SELECTION
# Playbook selection

- mode: $MODE
- effective_governance: $GOVERNANCE
- agent: $AGENT
- language: $LANGUAGE
- profile: $PROFILE
- github_repo: ${GITHUB_REPO:-none}
- no_serena: $NO_SERENA
- serena_codex_mcp: $SERENA_CODEX_MCP
SELECTION
}

step_github_protection() {
  if [[ "$GOVERNANCE" != "required" ]]; then
    write_github_protection_status "skipped" "governance=off"
    return 0
  fi

  if [[ -z "$GITHUB_REPO" ]]; then
    write_github_protection_status "manual-required" "no --github-repo provided"
    echo "GitHub protection: manual-required (missing --github-repo)"
    return 0
  fi

  if ! command -v gh >/dev/null 2>&1; then
    write_github_protection_status "manual-required" "gh CLI not available"
    echo "GitHub protection: manual-required (gh CLI not available)"
    return 0
  fi

  if ! gh auth status >/dev/null 2>&1; then
    write_github_protection_status "manual-required" "gh CLI not authenticated"
    echo "GitHub protection: manual-required (gh auth status failed)"
    return 0
  fi

  if "$GITHUB_APPLY_HELPER" --repo "$GITHUB_REPO"; then
    write_github_protection_status "applied" "auto-applied by bootstrap"
    echo "GitHub protection: applied for $GITHUB_REPO"
    return 0
  fi

  write_github_protection_status "manual-required" "auto-apply failed; run scripts/github/apply-branch-protection.sh manually"
  echo "GitHub protection: manual-required (auto-apply failed)"
  return 0
}

step_global_guide() {
  mkdir -p "$TARGET/docs/ai"
  cp "$GLOBAL_GUIDE_TEMPLATE" "$TARGET/docs/ai/global-personalization.md"
}

step_serena_install() {
  local output
  local rc

  set +e
  output="$("$SERENA_HELPER" --phase install 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    printf '%s\n' "$output"
    return 0
  fi

  if [[ "$rc" -eq 20 ]]; then
    set_block_context "Serena installation blocked" "$(build_resume_hint)"
    printf '%s\n' "$output" >&2
    return 20
  fi

  printf '%s\n' "$output" >&2
  return "$rc"
}

step_serena_codex_mcp() {
  local output
  local rc

  set +e
  output="$("$SERENA_HELPER" --phase codex-mcp --target "$TARGET" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    printf '%s\n' "$output"
    return 0
  fi

  if [[ "$rc" -eq 20 ]]; then
    set_block_context "Serena Codex MCP registration blocked" "$(build_resume_hint)"
    printf '%s\n' "$output" >&2
    return 20
  fi

  printf '%s\n' "$output" >&2
  return "$rc"
}

step_serena_verify() {
  local out
  local rc

  if [[ "$SERENA_CODEX_MCP" != "required" ]]; then
    echo "Serena verify skipped: --serena-codex-mcp off"
    return 0
  fi

  if ! command -v codex >/dev/null 2>&1; then
    set_block_context "codex CLI is not available for Serena verification" "$(build_resume_hint)"
    return 20
  fi

  set +e
  out="$(codex mcp get serena 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    set_block_context "Serena MCP is not registered in codex" "$(build_resume_hint)"
    printf '%s\n' "$out" >&2
    return 20
  fi

  if [[ "$out" != *"--context codex"* ]]; then
    set_block_context "Serena MCP command is invalid: missing '--context codex'" "$(build_resume_hint)"
    printf '%s\n' "$out" >&2
    return 20
  fi

  if [[ "$out" == *"--project"* ]]; then
    set_block_context "Serena MCP command must be global and must not include '--project'" "$(build_resume_hint)"
    printf '%s\n' "$out" >&2
    return 20
  fi

  echo "Serena MCP verification passed."
  return 0
}

run_step() {
  local step_var="$1"
  local fn="$2"
  local step_status="${!step_var:-pending}"
  local rc=0

  if [[ "$step_status" == "done" ]]; then
    return 0
  fi

  STEP_BLOCK_REASON=""
  STEP_BLOCK_HINT=""

  if "$fn"; then
    state_mark_done "$step_var"
    state_save "$STATE_FILE"
    return 0
  else
    rc=$?
  fi

  if [[ "$rc" -eq 20 ]]; then
    if [[ -z "$STEP_BLOCK_HINT" ]]; then
      STEP_BLOCK_HINT="$(build_resume_hint)"
    fi
    state_mark_blocked "$step_var" "${STEP_BLOCK_REASON:-blocked at $step_var}" "$STEP_BLOCK_HINT"
    state_save "$STATE_FILE"

    printf 'BOOTSTRAP BLOCKED at %s\n' "$step_var" >&2
    printf 'Reason: %s\n' "$BLOCKED_REASON" >&2
    printf 'Resume command: %s\n' "$RESUME_HINT" >&2
    exit 20
  fi

  return "$rc"
}

skip_serena_steps_if_requested() {
  if [[ "$NO_SERENA" != "1" ]]; then
    return 0
  fi

  state_mark_done "STEP_SERENA_INSTALL"
  state_mark_done "STEP_SERENA_CODEX_MCP"
  state_mark_done "STEP_SERENA_VERIFY"
  state_save "$STATE_FILE"
  return 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --mode)
      MODE_SET=1
      MODE="${2:-}"
      shift 2
      ;;
    --agent)
      AGENT_SET=1
      AGENT="${2:-}"
      shift 2
      ;;
    --language)
      LANGUAGE_SET=1
      LANGUAGE="${2:-}"
      shift 2
      ;;
    --profile)
      PROFILE_SET=1
      PROFILE="${2:-}"
      shift 2
      ;;
    --governance)
      GOVERNANCE_SET=1
      GOVERNANCE="${2:-}"
      shift 2
      ;;
    --github-repo)
      GITHUB_REPO_SET=1
      GITHUB_REPO="${2:-}"
      shift 2
      ;;
    --resume)
      RESUME=1
      shift
      ;;
    --state-file)
      STATE_FILE="${2:-}"
      shift 2
      ;;
    --force-restart)
      FORCE_RESTART=1
      shift
      ;;
    --no-serena)
      NO_SERENA_SET=1
      NO_SERENA=1
      shift
      ;;
    --serena-codex-mcp)
      SERENA_CODEX_MCP_SET=1
      SERENA_CODEX_MCP="${2:-}"
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

if [[ "$RESUME" == "1" ]] && [[ "$FORCE_RESTART" == "1" ]]; then
  echo "ERROR: --resume and --force-restart cannot be used together" >&2
  exit 2
fi

if [[ "$RESUME" == "1" ]]; then
  handle_resume_init
else
  handle_new_run_init
fi

run_step "STEP_CORE" step_core
run_step "STEP_GOVERNANCE_FILES" step_governance_files
run_step "STEP_ADAPTERS" step_adapters
run_step "STEP_SELECTION" step_selection
run_step "STEP_GITHUB_PROTECTION" step_github_protection
run_step "STEP_GLOBAL_GUIDE" step_global_guide

if [[ "$NO_SERENA" == "1" ]]; then
  skip_serena_steps_if_requested
else
  run_step "STEP_SERENA_INSTALL" step_serena_install
  if [[ "$SERENA_CODEX_MCP" == "required" ]]; then
    run_step "STEP_SERENA_CODEX_MCP" step_serena_codex_mcp
    run_step "STEP_SERENA_VERIFY" step_serena_verify
  else
    state_mark_done "STEP_SERENA_CODEX_MCP"
    state_mark_done "STEP_SERENA_VERIFY"
    state_save "$STATE_FILE"
  fi
fi

state_mark_completed
state_save "$STATE_FILE"

echo "Bootstrap complete"
echo "Target: $TARGET"
echo "Mode: $MODE"
echo "Effective governance: $GOVERNANCE"
echo "Agent adapter: $AGENT"
echo "Language adapter: $LANGUAGE"
echo "Profile: $PROFILE"
echo "GitHub repo: ${GITHUB_REPO:-none}"
echo "Serena install: $([[ "$NO_SERENA" == "1" ]] && echo skipped || echo enabled)"
echo "Serena Codex MCP mode: $SERENA_CODEX_MCP"
echo "State file: $STATE_FILE"
echo "TODO: Complete docs/ai/global-personalization.md before first implementation task."
echo "TODO: Mark completion in docs/ai/global-personalization.done."
echo "TODO: Run scripts/commit-ready.sh before each commit."
echo "TODO: Run scripts/project-readiness-check.sh and resolve all FAIL items."
if [[ "$NO_SERENA" == "1" ]]; then
  echo "NOTE: readiness will fail until Serena MCP is configured."
fi

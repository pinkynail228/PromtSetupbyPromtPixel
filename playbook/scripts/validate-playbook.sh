#!/usr/bin/env bash
set -euo pipefail

MODE="full"
NO_LINKS=0
KEEP_TMP=0
CURL_CONNECT_TIMEOUT=8
CURL_MAX_TIME=20

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
USE_RG=0
CHECK_ERROR_DETAIL=""

usage() {
  cat <<'USAGE'
Usage:
  ./playbook/scripts/validate-playbook.sh [--full] [--smoke] [--no-links] [--keep-tmp]
                                         [--curl-connect-timeout <sec>] [--curl-max-time <sec>] [--help]

Modes:
  --full       Full regression (default)
  --smoke      Fast checks: no link-check

Flags:
  --no-links   Skip HTTP link integrity check
  --keep-tmp   Keep temporary directories for debugging

Network tuning:
  --curl-connect-timeout <sec>  Connect timeout for each URL request (default: 8)
  --curl-max-time <sec>         Max request duration per URL (default: 20)

Exit codes:
  0  all checks passed
  1  one or more checks failed
  2  environment/dependency/preflight error
USAGE
}

log_check() {
  local name="$1"
  local status="$2"
  local details="${3:-}"

  printf 'CHECK: %s ... %s\n' "$name" "$status"
  if [[ -n "$details" ]]; then
    printf '  %s\n' "$details"
  fi

  case "$status" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    SKIP) SKIP_COUNT=$((SKIP_COUNT + 1)) ;;
  esac
}

die_env() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 2
}

run_check() {
  local name="$1"
  local fn="$2"
  CHECK_ERROR_DETAIL=""

  if "$fn"; then
    log_check "$name" "PASS"
  else
    log_check "$name" "FAIL" "$CHECK_ERROR_DETAIL"
  fi
}

require_contains() {
  local text="$1"
  local needle="$2"
  local label="$3"

  if [[ "$text" != *"$needle"* ]]; then
    CHECK_ERROR_DETAIL="$label (expected to contain: $needle)"
    return 1
  fi
  return 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --full) MODE="full" ;;
      --smoke) MODE="smoke" ;;
      --no-links) NO_LINKS=1 ;;
      --keep-tmp) KEEP_TMP=1 ;;
      --curl-connect-timeout)
        CURL_CONNECT_TIMEOUT="${2:-}"
        shift
        ;;
      --curl-max-time)
        CURL_MAX_TIME="${2:-}"
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die_env "unknown option: $1"
        ;;
    esac
    shift
  done
}

preflight() {
  local cmd
  local missing_cmds=()

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PLAYBOOK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  ROOT_DIR="$(cd "$PLAYBOOK_DIR/.." && pwd)"

  CORE_DIR="$PLAYBOOK_DIR/core"
  STRICT_GOVERNANCE_DIR="$CORE_DIR/governance/files"
  SOLO_GOVERNANCE_DIR="$CORE_DIR/governance/solo/files"
  ADAPTERS_DIR="$PLAYBOOK_DIR/adapters"
  CURATION_DIR="$PLAYBOOK_DIR/curation"
  BOOTSTRAP_SCRIPT="$SCRIPT_DIR/bootstrap.sh"
  PROFILE_CHECK_SCRIPT="$CURATION_DIR/check-profile.sh"
  SETUP_FILE="$PLAYBOOK_DIR/setup.md"
  GLOBAL_TEMPLATE_FILE="$CORE_DIR/templates/global-personalization.md"
  STATE_LIB_FILE="$SCRIPT_DIR/lib/state.sh"
  SERENA_HELPER_FILE="$SCRIPT_DIR/install-serena-mcp.sh"
  GITHUB_APPLY_SCRIPT="$SCRIPT_DIR/github/apply-branch-protection.sh"
  GITHUB_VERIFY_SCRIPT="$SCRIPT_DIR/github/verify-branch-protection.sh"

  for cmd in bash awk curl mktemp grep sed cp mkdir chmod find sort env; do
    command -v "$cmd" >/dev/null 2>&1 || missing_cmds+=("$cmd")
  done

  if [[ ${#missing_cmds[@]} -gt 0 ]]; then
    die_env "missing required commands: ${missing_cmds[*]}"
  fi

  if command -v rg >/dev/null 2>&1; then
    USE_RG=1
  fi

  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/solo-playbook-validate.XXXXXX")"
}

cleanup() {
  if [[ "$KEEP_TMP" == "1" ]]; then
    return
  fi
  rm -rf "$TMP_DIR"
}

check_required_files_present() {
  local required=(
    "$CORE_DIR/AGENTS.md"
    "$CORE_DIR/Flow.md"
    "$CORE_DIR/templates/plan.md"
    "$CORE_DIR/templates/report.md"
    "$GLOBAL_TEMPLATE_FILE"
    "$SETUP_FILE"
    "$BOOTSTRAP_SCRIPT"
    "$PROFILE_CHECK_SCRIPT"
    "$STATE_LIB_FILE"
    "$SERENA_HELPER_FILE"
    "$GITHUB_APPLY_SCRIPT"
    "$GITHUB_VERIFY_SCRIPT"
  )
  local f

  for f in "${required[@]}"; do
    if [[ ! -f "$f" ]]; then
      CHECK_ERROR_DETAIL="missing required file: $f"
      return 1
    fi
  done

  return 0
}

check_strict_governance_templates_present() {
  local required=(
    "$STRICT_GOVERNANCE_DIR/.github/CODEOWNERS"
    "$STRICT_GOVERNANCE_DIR/.github/PULL_REQUEST_TEMPLATE.md"
    "$STRICT_GOVERNANCE_DIR/.github/workflows/ci.yml"
    "$STRICT_GOVERNANCE_DIR/.github/workflows/security.yml"
    "$STRICT_GOVERNANCE_DIR/.github/workflows/release.yml"
    "$STRICT_GOVERNANCE_DIR/docs/ai/definition-of-done.md"
    "$STRICT_GOVERNANCE_DIR/docs/ai/architecture/adr/ADR-TEMPLATE.md"
    "$STRICT_GOVERNANCE_DIR/docs/ai/release-checklist.md"
    "$STRICT_GOVERNANCE_DIR/docs/ai/rollback-plan.md"
    "$STRICT_GOVERNANCE_DIR/docs/ai/github-protection-checklist.md"
    "$STRICT_GOVERNANCE_DIR/docs/ai/serena-workflow.md"
    "$STRICT_GOVERNANCE_DIR/docs/ai/serena-memory-policy.md"
    "$STRICT_GOVERNANCE_DIR/scripts/run-quality-gates.sh"
    "$STRICT_GOVERNANCE_DIR/scripts/run-security-gates.sh"
    "$STRICT_GOVERNANCE_DIR/scripts/run-dod-gate.sh"
    "$STRICT_GOVERNANCE_DIR/scripts/commit-ready.sh"
    "$STRICT_GOVERNANCE_DIR/scripts/project-readiness-check.sh"
    "$STRICT_GOVERNANCE_DIR/scripts/github/apply-branch-protection.sh"
    "$STRICT_GOVERNANCE_DIR/scripts/github/verify-branch-protection.sh"
  )
  local f

  for f in "${required[@]}"; do
    if [[ ! -f "$f" ]]; then
      CHECK_ERROR_DETAIL="missing strict governance template: $f"
      return 1
    fi
  done

  return 0
}

check_solo_governance_templates_present() {
  local required=(
    "$SOLO_GOVERNANCE_DIR/docs/ai/definition-of-done.md"
    "$SOLO_GOVERNANCE_DIR/docs/ai/architecture/adr/ADR-TEMPLATE.md"
    "$SOLO_GOVERNANCE_DIR/docs/ai/release-checklist.md"
    "$SOLO_GOVERNANCE_DIR/docs/ai/rollback-plan.md"
    "$SOLO_GOVERNANCE_DIR/docs/ai/serena-workflow.md"
    "$SOLO_GOVERNANCE_DIR/docs/ai/serena-memory-policy.md"
    "$SOLO_GOVERNANCE_DIR/docs/ai/quality-gates.env"
    "$SOLO_GOVERNANCE_DIR/docs/ai/security-gates.env"
    "$SOLO_GOVERNANCE_DIR/scripts/run-quality-gates.sh"
    "$SOLO_GOVERNANCE_DIR/scripts/run-security-gates.sh"
    "$SOLO_GOVERNANCE_DIR/scripts/run-dod-gate.sh"
    "$SOLO_GOVERNANCE_DIR/scripts/commit-ready.sh"
    "$SOLO_GOVERNANCE_DIR/scripts/project-readiness-check.sh"
  )
  local f

  for f in "${required[@]}"; do
    if [[ ! -f "$f" ]]; then
      CHECK_ERROR_DETAIL="missing solo governance template: $f"
      return 1
    fi
  done

  return 0
}

check_adapter_contract() {
  local base d
  local missing=0

  for base in "$ADAPTERS_DIR/agents" "$ADAPTERS_DIR/languages"; do
    while IFS= read -r d; do
      [[ -d "$d" ]] || continue
      [[ -f "$d/README.md" ]] || { echo "MISSING: $d/README.md"; missing=1; }
      [[ -f "$d/adapter.toml" ]] || { echo "MISSING: $d/adapter.toml"; missing=1; }
      [[ -d "$d/files" ]] || { echo "MISSING: $d/files"; missing=1; }

      if [[ -f "$d/adapter.toml" ]]; then
        grep -Eq '^id\s*=' "$d/adapter.toml" || { echo "MISSING FIELD: id in $d/adapter.toml"; missing=1; }
        grep -Eq '^type\s*=' "$d/adapter.toml" || { echo "MISSING FIELD: type in $d/adapter.toml"; missing=1; }
        grep -Eq '^applies_to\s*=' "$d/adapter.toml" || { echo "MISSING FIELD: applies_to in $d/adapter.toml"; missing=1; }
        grep -Eq '^conflicts_with\s*=' "$d/adapter.toml" || { echo "MISSING FIELD: conflicts_with in $d/adapter.toml"; missing=1; }
        grep -Eq '^copy_map\s*=' "$d/adapter.toml" || { echo "MISSING FIELD: copy_map in $d/adapter.toml"; missing=1; }
      fi

      if [[ -d "$d/files" ]]; then
        if [[ -z "$(find "$d/files" -type f -print -quit)" ]]; then
          echo "MISSING: adapter files are empty in $d/files"
          missing=1
        fi
      fi
    done < <(find "$base" -mindepth 1 -maxdepth 1 -type d | sort)
  done

  if [[ "$missing" -ne 0 ]]; then
    CHECK_ERROR_DETAIL="one or more adapters violate contract"
    return 1
  fi

  return 0
}

check_core_universal_policy() {
  local core_files
  local pattern

  core_files=("$CORE_DIR/AGENTS.md" "$CORE_DIR/Flow.md")
  pattern='\b(npm|pip|poetry|swift build|swift test|cargo|go test|mvn|gradle|dotnet|bundle exec)\b'

  if grep -Ein "$pattern" "${core_files[@]}" >/dev/null 2>&1; then
    CHECK_ERROR_DETAIL="core contains stack-specific commands"
    return 1
  fi

  return 0
}

check_serena_priority_rules() {
  local required_serena_refs=(
    "$CORE_DIR/AGENTS.md"
    "$CORE_DIR/Flow.md"
    "$STRICT_GOVERNANCE_DIR/docs/ai/serena-workflow.md"
    "$STRICT_GOVERNANCE_DIR/docs/ai/serena-memory-policy.md"
    "$STRICT_GOVERNANCE_DIR/docs/ai/definition-of-done.md"
    "$STRICT_GOVERNANCE_DIR/.github/PULL_REQUEST_TEMPLATE.md"
    "$SOLO_GOVERNANCE_DIR/docs/ai/serena-workflow.md"
    "$SOLO_GOVERNANCE_DIR/docs/ai/serena-memory-policy.md"
    "$SOLO_GOVERNANCE_DIR/docs/ai/definition-of-done.md"
    "$ADAPTERS_DIR/agents/codex/files/.codex/rules/00-core.md"
    "$ADAPTERS_DIR/agents/cursor/files/.cursor/rules/00-core.mdc"
    "$ADAPTERS_DIR/agents/claude/files/CLAUDE.md"
    "$ADAPTERS_DIR/agents/antigravity/files/.agent/rules/00-core.md"
    "$ADAPTERS_DIR/agents/antigravity/files/.agent/rules/10-curated-skills-policy.md"
  )
  local f

  for f in "${required_serena_refs[@]}"; do
    if [[ ! -f "$f" ]]; then
      CHECK_ERROR_DETAIL="missing Serena policy file: $f"
      return 1
    fi

    if ! grep -qi 'serena' "$f"; then
      CHECK_ERROR_DETAIL="Serena priority missing in file: $f"
      return 1
    fi
  done

  if ! grep -Fqi 'fallback-only' "$CORE_DIR/AGENTS.md"; then
    CHECK_ERROR_DETAIL="core AGENTS.md must mark manual deep exploration as fallback-only"
    return 1
  fi

  if ! grep -Fqi 'fallback-only' "$CORE_DIR/Flow.md"; then
    CHECK_ERROR_DETAIL="core Flow.md must mark manual search as fallback-only"
    return 1
  fi

  return 0
}

check_bootstrap_cli_flags() {
  local output
  output="$($BOOTSTRAP_SCRIPT --help)" || {
    CHECK_ERROR_DETAIL="bootstrap --help failed"
    return 1
  }

  require_contains "$output" "--mode" "missing --mode flag" || return 1
  require_contains "$output" "--resume" "missing --resume flag" || return 1
  require_contains "$output" "--state-file" "missing --state-file flag" || return 1
  require_contains "$output" "--force-restart" "missing --force-restart flag" || return 1
  require_contains "$output" "--no-serena" "missing --no-serena flag" || return 1
  require_contains "$output" "--serena-codex-mcp" "missing --serena-codex-mcp flag" || return 1
  require_contains "$output" "--governance" "missing --governance flag" || return 1
  require_contains "$output" "--github-repo" "missing --github-repo flag" || return 1
  require_contains "$output" "mode=solo" "help must describe solo mode governance mapping" || return 1
  return 0
}

check_serena_helper_command_shape() {
  local add_line
  add_line="$(grep -E 'codex mcp add serena' "$SERENA_HELPER_FILE" || true)"

  if [[ -z "$add_line" ]]; then
    CHECK_ERROR_DETAIL="Serena helper missing codex mcp add command"
    return 1
  fi

  if [[ "$add_line" != *"--context codex"* ]]; then
    CHECK_ERROR_DETAIL="Serena helper must use --context codex"
    return 1
  fi

  if grep -Fq -- '--project' "$SERENA_HELPER_FILE"; then
    CHECK_ERROR_DETAIL="Serena helper must not include --project in global MCP registration"
    return 1
  fi

  return 0
}

check_no_absolute_user_paths() {
  local out
  if [[ "$USE_RG" == "1" ]]; then
    out="$(rg -n --hidden --no-ignore '/Users/' "$ROOT_DIR" --glob '!playbook/scripts/validate-playbook.sh' || true)"
  else
    out="$(grep -Rns '/Users/' "$ROOT_DIR" | grep -v 'playbook/scripts/validate-playbook.sh' || true)"
  fi

  if [[ -n "$out" ]]; then
    CHECK_ERROR_DETAIL="found user-specific absolute paths"
    printf '%s\n' "$out"
    return 1
  fi

  return 0
}

extract_urls() {
  if [[ "$USE_RG" == "1" ]]; then
    rg -o 'https://[^` )"]+' "$SETUP_FILE" | sort -u
  else
    grep -Eo 'https://[^` )"]+' "$SETUP_FILE" | sort -u
  fi
}

check_link_integrity() {
  local failed=0
  local url code attempt
  local urls

  urls="$(extract_urls)"
  if [[ -z "$urls" ]]; then
    CHECK_ERROR_DETAIL="no URLs found in setup.md"
    return 1
  fi

  while IFS= read -r url; do
    [[ -n "$url" ]] || continue
    code="ERR"
    for attempt in 1 2 3; do
      code="$(curl -L -s -o /dev/null -w '%{http_code}' --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_MAX_TIME" "$url" || true)"
      if [[ -z "$code" ]]; then
        code="ERR"
      fi
      if [[ "$code" == "200" ]]; then
        break
      fi
      sleep 1
    done
    if [[ "$code" != "200" ]]; then
      failed=1
      printf '  LINK_FAIL: %s -> %s\n' "$url" "$code"
    fi
  done <<< "$urls"

  if [[ "$failed" -eq 1 ]]; then
    CHECK_ERROR_DETAIL="one or more links returned non-200"
    return 1
  fi

  return 0
}

check_bootstrap_default_solo_no_serena() {
  local p="$TMP_DIR/bootstrap-default-solo"

  "$BOOTSTRAP_SCRIPT" \
    --target "$p" \
    --agent none \
    --language none \
    --profile minimal \
    --no-serena >/dev/null

  [[ -f "$p/AGENTS.md" ]] || { CHECK_ERROR_DETAIL="missing AGENTS.md"; return 1; }
  [[ -f "$p/docs/ai/Flow.md" ]] || { CHECK_ERROR_DETAIL="missing docs/ai/Flow.md"; return 1; }
  [[ -f "$p/docs/ai/global-personalization.md" ]] || { CHECK_ERROR_DETAIL="missing global-personalization.md"; return 1; }
  [[ -f "$p/scripts/commit-ready.sh" ]] || { CHECK_ERROR_DETAIL="missing commit-ready.sh"; return 1; }
  [[ -f "$p/scripts/project-readiness-check.sh" ]] || { CHECK_ERROR_DETAIL="missing project-readiness-check.sh"; return 1; }
  [[ -f "$p/scripts/run-quality-gates.sh" ]] || { CHECK_ERROR_DETAIL="missing run-quality-gates.sh"; return 1; }
  [[ -f "$p/scripts/run-security-gates.sh" ]] || { CHECK_ERROR_DETAIL="missing run-security-gates.sh"; return 1; }
  [[ -f "$p/scripts/run-dod-gate.sh" ]] || { CHECK_ERROR_DETAIL="missing run-dod-gate.sh"; return 1; }
  [[ -f "$p/docs/ai/definition-of-done.md" ]] || { CHECK_ERROR_DETAIL="missing definition-of-done.md"; return 1; }

  [[ ! -f "$p/.github/workflows/ci.yml" ]] || { CHECK_ERROR_DETAIL="default solo should not create .github/workflows/ci.yml"; return 1; }
  [[ ! -f "$p/.github/PULL_REQUEST_TEMPLATE.md" ]] || { CHECK_ERROR_DETAIL="default solo should not create PR template"; return 1; }

  [[ -f "$p/.playbook-bootstrap.state" ]] || { CHECK_ERROR_DETAIL="missing state file"; return 1; }
  grep -q '^MODE=solo$' "$p/.playbook-bootstrap.state" || {
    CHECK_ERROR_DETAIL="state must contain MODE=solo for default bootstrap"
    return 1
  }
  grep -q '^GOVERNANCE=off$' "$p/.playbook-bootstrap.state" || {
    CHECK_ERROR_DETAIL="state must contain GOVERNANCE=off for default bootstrap"
    return 1
  }
  grep -q '^STATUS=completed$' "$p/.playbook-bootstrap.state" || {
    CHECK_ERROR_DETAIL="state must contain STATUS=completed for default bootstrap"
    return 1
  }

  grep -Fq -- '- mode: solo' "$p/docs/ai/playbook-selection.md" || {
    CHECK_ERROR_DETAIL="playbook-selection.md must contain mode: solo"
    return 1
  }
  grep -Fq -- '- effective_governance: off' "$p/docs/ai/playbook-selection.md" || {
    CHECK_ERROR_DETAIL="playbook-selection.md must contain effective_governance: off"
    return 1
  }

  return 0
}

check_bootstrap_strict_no_serena() {
  local p="$TMP_DIR/bootstrap-strict-no-serena"

  "$BOOTSTRAP_SCRIPT" \
    --target "$p" \
    --mode strict \
    --agent none \
    --language none \
    --profile minimal \
    --no-serena >/dev/null

  [[ -f "$p/.github/PULL_REQUEST_TEMPLATE.md" ]] || { CHECK_ERROR_DETAIL="missing PR template in strict mode"; return 1; }
  [[ -f "$p/.github/workflows/ci.yml" ]] || { CHECK_ERROR_DETAIL="missing ci.yml in strict mode"; return 1; }
  [[ -f "$p/docs/ai/github-protection-checklist.md" ]] || { CHECK_ERROR_DETAIL="missing github-protection-checklist.md in strict mode"; return 1; }
  [[ -f "$p/scripts/commit-ready.sh" ]] || { CHECK_ERROR_DETAIL="missing commit-ready.sh in strict mode"; return 1; }
  [[ -f "$p/docs/ai/github-protection.status" ]] || { CHECK_ERROR_DETAIL="missing github-protection.status in strict mode"; return 1; }

  grep -q '^MODE=strict$' "$p/.playbook-bootstrap.state" || {
    CHECK_ERROR_DETAIL="state must contain MODE=strict in strict mode"
    return 1
  }
  grep -q '^GOVERNANCE=required$' "$p/.playbook-bootstrap.state" || {
    CHECK_ERROR_DETAIL="state must contain GOVERNANCE=required in strict mode"
    return 1
  }
  grep -q '^STATUS=completed$' "$p/.playbook-bootstrap.state" || {
    CHECK_ERROR_DETAIL="state must contain STATUS=completed in strict mode"
    return 1
  }

  return 0
}

check_bootstrap_mode_strict_governance_off() {
  local p="$TMP_DIR/bootstrap-strict-override-off"

  "$BOOTSTRAP_SCRIPT" \
    --target "$p" \
    --mode strict \
    --governance off \
    --no-serena >/dev/null

  [[ -f "$p/scripts/commit-ready.sh" ]] || { CHECK_ERROR_DETAIL="missing commit-ready.sh with strict+override"; return 1; }
  [[ ! -f "$p/.github/workflows/ci.yml" ]] || { CHECK_ERROR_DETAIL="strict+governance off must not create strict workflows"; return 1; }
  [[ ! -f "$p/docs/ai/github-protection-checklist.md" ]] || { CHECK_ERROR_DETAIL="strict+governance off must not create github-protection-checklist"; return 1; }

  grep -q '^MODE=strict$' "$p/.playbook-bootstrap.state" || {
    CHECK_ERROR_DETAIL="state must keep MODE=strict when governance is overridden"
    return 1
  }
  grep -q '^GOVERNANCE=off$' "$p/.playbook-bootstrap.state" || {
    CHECK_ERROR_DETAIL="state must contain GOVERNANCE=off with override"
    return 1
  }

  return 0
}

check_bootstrap_codex_swift() {
  local p="$TMP_DIR/bootstrap-codex-swift"
  "$BOOTSTRAP_SCRIPT" --target "$p" --agent codex --language swift --profile students --no-serena >/dev/null

  [[ -f "$p/.codex/rules/00-core.md" ]] || { CHECK_ERROR_DETAIL="missing codex adapter file"; return 1; }
  [[ -f "$p/docs/ai/adapters/language-swift.md" ]] || { CHECK_ERROR_DETAIL="missing swift adapter file"; return 1; }
  [[ -f "$p/docs/ai/curation/skills-profile.txt" ]] || { CHECK_ERROR_DETAIL="missing students profile file"; return 1; }
  [[ -f "$p/docs/ai/quality-gates.env" ]] || { CHECK_ERROR_DETAIL="missing quality-gates.env"; return 1; }

  grep -Fq 'swift test' "$p/docs/ai/quality-gates.env" || {
    CHECK_ERROR_DETAIL="swift adapter did not provide expected quality gates"
    return 1
  }

  return 0
}

check_bootstrap_blocked_resume_no_uv() {
  local p="$TMP_DIR/bootstrap-blocked-resume"
  local output rc

  set +e
  output="$(env PATH="/usr/bin:/bin:/usr/sbin:/sbin" "$BOOTSTRAP_SCRIPT" --target "$p" --agent none --language none --profile minimal 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -ne 20 ]]; then
    CHECK_ERROR_DETAIL="expected bootstrap to exit 20 when uv is unavailable (got: $rc)"
    printf '%s\n' "$output"
    return 1
  fi

  [[ -f "$p/.playbook-bootstrap.state" ]] || {
    CHECK_ERROR_DETAIL="missing state file after blocked run"
    return 1
  }

  grep -q '^STATUS=blocked$' "$p/.playbook-bootstrap.state" || {
    CHECK_ERROR_DETAIL="blocked run must set STATUS=blocked"
    return 1
  }

  grep -q '^STEP_SERENA_INSTALL=blocked$' "$p/.playbook-bootstrap.state" || {
    CHECK_ERROR_DETAIL="blocked run must set STEP_SERENA_INSTALL=blocked"
    return 1
  }

  require_contains "$output" "Resume command:" "blocked output must contain resume command" || return 1

  "$BOOTSTRAP_SCRIPT" --target "$p" --resume --no-serena >/dev/null || {
    CHECK_ERROR_DETAIL="resume run with --no-serena failed"
    return 1
  }

  grep -q '^STATUS=completed$' "$p/.playbook-bootstrap.state" || {
    CHECK_ERROR_DETAIL="resume run must set STATUS=completed"
    return 1
  }

  grep -q '^STEP_SERENA_INSTALL=done$' "$p/.playbook-bootstrap.state" || {
    CHECK_ERROR_DETAIL="resume run must set STEP_SERENA_INSTALL=done"
    return 1
  }

  grep -q '^STEP_SERENA_CODEX_MCP=done$' "$p/.playbook-bootstrap.state" || {
    CHECK_ERROR_DETAIL="resume run must set STEP_SERENA_CODEX_MCP=done"
    return 1
  }

  grep -q '^STEP_SERENA_VERIFY=done$' "$p/.playbook-bootstrap.state" || {
    CHECK_ERROR_DETAIL="resume run must set STEP_SERENA_VERIFY=done"
    return 1
  }

  return 0
}

check_bootstrap_github_repo_no_gh_manual_required() {
  local p="$TMP_DIR/bootstrap-no-gh"
  local output rc

  set +e
  output="$(env PATH="/usr/bin:/bin:/usr/sbin:/sbin" "$BOOTSTRAP_SCRIPT" --target "$p" --mode strict --github-repo acme/demo --no-serena 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    CHECK_ERROR_DETAIL="bootstrap with --github-repo and no gh should complete with manual-required (rc=$rc)"
    printf '%s\n' "$output"
    return 1
  fi

  require_contains "$output" "manual-required" "expected manual-required output when gh is unavailable" || return 1

  [[ -f "$p/docs/ai/github-protection.status" ]] || {
    CHECK_ERROR_DETAIL="missing github-protection.status"
    return 1
  }

  grep -q '^STATUS=manual-required$' "$p/docs/ai/github-protection.status" || {
    CHECK_ERROR_DETAIL="expected STATUS=manual-required when gh unavailable"
    return 1
  }

  return 0
}

check_legacy_resume_mode_inference() {
  local p="$TMP_DIR/bootstrap-legacy-resume"
  local state="$p/.playbook-bootstrap.state"
  local tmp_state="$TMP_DIR/legacy-state.tmp"

  "$BOOTSTRAP_SCRIPT" --target "$p" --mode strict --no-serena >/dev/null

  awk '!/^MODE=/' "$state" > "$tmp_state"
  awk '
    BEGIN { done = 0 }
    /^VERSION=/ { print "VERSION=2"; done = 1; next }
    { print }
    END { if (done == 0) print "VERSION=2" }
  ' "$tmp_state" > "$state"

  "$BOOTSTRAP_SCRIPT" --target "$p" --resume --no-serena >/dev/null || {
    CHECK_ERROR_DETAIL="resume failed for legacy state without MODE"
    return 1
  }

  grep -q '^MODE=strict$' "$state" || {
    CHECK_ERROR_DETAIL="legacy resume must infer MODE=strict from GOVERNANCE=required"
    return 1
  }

  grep -q '^STATUS=completed$' "$state" || {
    CHECK_ERROR_DETAIL="legacy resume must end in STATUS=completed"
    return 1
  }

  return 0
}

check_commit_ready_fail_and_pass() {
  local p="$TMP_DIR/commit-ready"

  "$BOOTSTRAP_SCRIPT" --target "$p" --no-serena >/dev/null

  if (cd "$p" && bash scripts/commit-ready.sh >/dev/null 2>&1); then
    CHECK_ERROR_DETAIL="commit-ready should fail with default __REQUIRED__ gates"
    return 1
  fi

  cat > "$p/docs/ai/quality-gates.env" <<'EOF_QUALITY'
LINT_CMD="skip"
TYPECHECK_CMD="skip"
TEST_CMD="skip"
BUILD_CMD="skip"
EOF_QUALITY

  cat > "$p/docs/ai/security-gates.env" <<'EOF_SECURITY'
DEPENDENCY_AUDIT_CMD="skip"
SECRET_SCAN_CMD="skip"
SAST_CMD="skip"
EOF_SECURITY

  (cd "$p" && bash scripts/commit-ready.sh >/dev/null) || {
    CHECK_ERROR_DETAIL="commit-ready should pass after configuring skip gates"
    return 1
  }

  return 0
}

check_readiness_fail_without_serena_solo() {
  local p="$TMP_DIR/readiness-solo-no-serena"
  local output rc

  "$BOOTSTRAP_SCRIPT" --target "$p" --no-serena >/dev/null
  printf 'completed\n' > "$p/docs/ai/global-personalization.done"

  set +e
  output="$(cd "$p" && bash scripts/project-readiness-check.sh 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    CHECK_ERROR_DETAIL="readiness must fail without Serena in solo context"
    printf '%s\n' "$output"
    return 1
  fi

  if [[ "$output" != *"solo project context detected"* ]]; then
    CHECK_ERROR_DETAIL="solo readiness output must indicate branch protection is skipped"
    printf '%s\n' "$output"
    return 1
  fi

  if [[ "$output" != *"Serena MCP is not registered"* ]] && [[ "$output" != *"codex CLI is required"* ]]; then
    CHECK_ERROR_DETAIL="readiness failure must explain Serena/Codex requirement"
    printf '%s\n' "$output"
    return 1
  fi

  return 0
}

check_readiness_strict_branch_protection_fail_and_pass() {
  local p="$TMP_DIR/readiness-strict"
  local fake_bin="$TMP_DIR/fake-bin"
  local output rc

  "$BOOTSTRAP_SCRIPT" --target "$p" --mode strict --no-serena >/dev/null
  printf 'completed\n' > "$p/docs/ai/global-personalization.done"
  mkdir -p "$fake_bin"

  cat > "$fake_bin/codex" <<'EOF_CODEX'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "mcp" && "${2:-}" == "get" && "${3:-}" == "serena" ]]; then
  echo 'serena -> uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context codex'
  exit 0
fi

exit 1
EOF_CODEX
  chmod +x "$fake_bin/codex"

  set +e
  output="$(cd "$p" && env PATH="$fake_bin:$PATH" bash scripts/project-readiness-check.sh 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    CHECK_ERROR_DETAIL="strict readiness must fail when branch protection cannot be verified"
    printf '%s\n' "$output"
    return 1
  fi

  require_contains "$output" "strict project requires GitHub repo" "strict readiness must fail on branch protection prereq" || return 1

  cat > "$p/scripts/github/verify-branch-protection.sh" <<'EOF_VERIFY'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF_VERIFY
  chmod +x "$p/scripts/github/verify-branch-protection.sh"

  (cd "$p" && env PATH="$fake_bin:$PATH" bash scripts/project-readiness-check.sh --repo acme/demo >/dev/null) || {
    CHECK_ERROR_DETAIL="strict readiness should pass after manual completion stubs"
    return 1
  }

  return 0
}

check_profile_script_custom_root() {
  local skills_root="$TMP_DIR/fake-skills"
  mkdir -p "$skills_root"

  while IFS= read -r skill || [[ -n "$skill" ]]; do
    [[ -z "$skill" ]] && continue
    mkdir -p "$skills_root/$skill"
    printf '# fake\n' > "$skills_root/$skill/SKILL.md"
  done < "$CURATION_DIR/students-core.txt"

  "$PROFILE_CHECK_SCRIPT" students-core --skills-root "$skills_root" --profile-root "$CURATION_DIR" >/dev/null || {
    CHECK_ERROR_DETAIL="check-profile failed for custom skills root"
    return 1
  }

  return 0
}

check_profile_script_missing_skills_message() {
  local output
  if output="$($PROFILE_CHECK_SCRIPT students-core --skills-root "$TMP_DIR/missing-skills" --profile-root "$CURATION_DIR" 2>&1)"; then
    CHECK_ERROR_DETAIL="check-profile should fail when skills root is missing"
    return 1
  fi

  require_contains "$output" "Install skills on-demand" "missing installation hint" || return 1
  return 0
}

main() {
  parse_args "$@"
  preflight
  trap cleanup EXIT

  run_check "required-files-present" check_required_files_present
  run_check "strict-governance-templates-present" check_strict_governance_templates_present
  run_check "solo-governance-templates-present" check_solo_governance_templates_present
  run_check "adapter-contract" check_adapter_contract
  run_check "core-universal-policy" check_core_universal_policy
  run_check "serena-priority-rules" check_serena_priority_rules
  run_check "bootstrap-cli-flags" check_bootstrap_cli_flags
  run_check "serena-helper-command-shape" check_serena_helper_command_shape
  run_check "no-absolute-user-paths" check_no_absolute_user_paths
  run_check "bootstrap-default-solo-no-serena" check_bootstrap_default_solo_no_serena
  run_check "bootstrap-strict-no-serena" check_bootstrap_strict_no_serena
  run_check "bootstrap-mode-strict-governance-off" check_bootstrap_mode_strict_governance_off
  run_check "bootstrap-codex-swift" check_bootstrap_codex_swift
  run_check "bootstrap-blocked-resume-no-uv" check_bootstrap_blocked_resume_no_uv
  run_check "bootstrap-github-repo-no-gh-manual-required" check_bootstrap_github_repo_no_gh_manual_required
  run_check "legacy-resume-mode-inference" check_legacy_resume_mode_inference
  run_check "commit-ready-fail-and-pass" check_commit_ready_fail_and_pass
  run_check "readiness-fail-without-serena-solo" check_readiness_fail_without_serena_solo
  run_check "readiness-strict-branch-protection-fail-and-pass" check_readiness_strict_branch_protection_fail_and_pass
  run_check "profile-script-custom-root" check_profile_script_custom_root
  run_check "profile-script-missing-skills-message" check_profile_script_missing_skills_message

  if [[ "$MODE" == "smoke" ]]; then
    log_check "link-integrity-setup-md" "SKIP" "smoke mode"
  elif [[ "$NO_LINKS" == "1" ]]; then
    log_check "link-integrity-setup-md" "SKIP" "--no-links flag"
  else
    run_check "link-integrity-setup-md" check_link_integrity
  fi

  printf '\nSummary: PASS=%d FAIL=%d SKIP=%d\n' "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
  if [[ "$KEEP_TMP" == "1" ]]; then
    printf 'Temp dir: %s\n' "$TMP_DIR"
  fi

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    printf 'CHECKS FAILED\n'
    exit 1
  fi

  printf 'ALL CHECKS PASSED\n'
}

main "$@"

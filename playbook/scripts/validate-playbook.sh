#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_DIR="$PLAYBOOK_DIR/core"
ADAPTERS_DIR="$PLAYBOOK_DIR/adapters"
SKILLS_DIR="$PLAYBOOK_DIR/skills"
BOOTSTRAP_SCRIPT="$SCRIPT_DIR/bootstrap.sh"
SERENA_HELPER="$SCRIPT_DIR/install-serena-mcp.sh"
SKILLS_INSTALLER="$SCRIPT_DIR/skills/install-vendored-skills.sh"
SETUP_DOC="$PLAYBOOK_DIR/setup.md"
README_DOC="$PLAYBOOK_DIR/../README.md"

SMOKE=0
NO_LINKS=0
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
CHECK_ERROR_DETAIL=""
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

usage() {
  cat <<'USAGE'
Usage:
  validate-playbook.sh [--smoke] [--no-links] [--help]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --smoke)
      SMOKE=1
      shift
      ;;
    --no-links)
      NO_LINKS=1
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

run_check() {
  local name="$1"
  local fn="$2"

  echo "CHECK: $name ..."
  CHECK_ERROR_DETAIL=""
  if "$fn"; then
    echo "  PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL"
    if [[ -n "$CHECK_ERROR_DETAIL" ]]; then
      echo "  $CHECK_ERROR_DETAIL"
    fi
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

skip_check() {
  local name="$1"
  local reason="$2"
  echo "CHECK: $name ... SKIP"
  echo "  $reason"
  SKIP_COUNT=$((SKIP_COUNT + 1))
}

check_required_files_present() {
  local required=(
    "$BOOTSTRAP_SCRIPT"
    "$SERENA_HELPER"
    "$SKILLS_INSTALLER"
    "$PLAYBOOK_DIR/scripts/skills/refresh-vendored-skills.sh"
    "$CORE_DIR/AGENTS.md"
    "$CORE_DIR/Flow.md"
    "$CORE_DIR/templates/context-provider-guide.md"
    "$CORE_DIR/templates/global-personalization.md"
    "$CORE_DIR/governance/files/docs/ai/context-workflow.md"
    "$CORE_DIR/governance/files/docs/ai/context-memory-policy.md"
    "$CORE_DIR/governance/solo/files/docs/ai/context-workflow.md"
    "$CORE_DIR/governance/solo/files/docs/ai/context-memory-policy.md"
    "$SKILLS_DIR/skills.lock.toml"
    "$SKILLS_DIR/NOTICE.md"
    "$SETUP_DOC"
    "$README_DOC"
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

check_legacy_removed() {
  if [[ -e "$PLAYBOOK_DIR/curation" ]]; then
    CHECK_ERROR_DETAIL="legacy directory still exists: $PLAYBOOK_DIR/curation"
    return 1
  fi

  if [[ -e "$PLAYBOOK_DIR/scripts/lib/state.sh" ]]; then
    CHECK_ERROR_DETAIL="legacy state library still exists"
    return 1
  fi

  if [[ -e "$PLAYBOOK_DIR/adapters/agents/antigravity/files/.agent/rules/10-curated-skills-policy.md" ]]; then
    CHECK_ERROR_DETAIL="legacy curated-skills antigravity rule still exists"
    return 1
  fi

  return 0
}

check_adapter_contract() {
  local base d missing=0

  for base in "$ADAPTERS_DIR/agents" "$ADAPTERS_DIR/languages" "$ADAPTERS_DIR/tooling"; do
    [[ -d "$base" ]] || continue
    while IFS= read -r d; do
      [[ -d "$d" ]] || continue
      [[ -f "$d/README.md" ]] || { echo "MISSING: $d/README.md"; missing=1; }
      [[ -f "$d/adapter.toml" ]] || { echo "MISSING: $d/adapter.toml"; missing=1; }
      [[ -d "$d/files" ]] || { echo "MISSING: $d/files"; missing=1; }

      if [[ -f "$d/adapter.toml" ]]; then
        grep -Eq '^id\s*=' "$d/adapter.toml" || { echo "MISSING FIELD: id in $d/adapter.toml"; missing=1; }
        grep -Eq '^type\s*=' "$d/adapter.toml" || { echo "MISSING FIELD: type in $d/adapter.toml"; missing=1; }
        grep -Eq '^description\s*=' "$d/adapter.toml" || { echo "MISSING FIELD: description in $d/adapter.toml"; missing=1; }
      fi

      if [[ -d "$d/files" ]] && [[ -z "$(find "$d/files" -type f -print -quit)" ]]; then
        echo "MISSING: adapter files are empty in $d/files"
        missing=1
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
  local core_files=("$CORE_DIR/AGENTS.md" "$CORE_DIR/Flow.md")
  local stack_pattern='\b(npm|pip|poetry|swift build|swift test|cargo|go test|mvn|gradle|dotnet|bundle exec)\b'

  if grep -Ein "$stack_pattern" "${core_files[@]}" >/dev/null 2>&1; then
    CHECK_ERROR_DETAIL="core contains stack-specific commands"
    return 1
  fi

  if grep -Ei 'serena-first is mandatory|codex mcp get serena' "${core_files[@]}" >/dev/null 2>&1; then
    CHECK_ERROR_DETAIL="core still contains hard Serena/Codex requirement"
    return 1
  fi

  return 0
}

check_skills_baseline() {
  local count
  count="$(find "$SKILLS_DIR/core" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  if [[ "$count" -lt 8 ]]; then
    CHECK_ERROR_DETAIL="vendored skills baseline too small: $count"
    return 1
  fi

  while IFS= read -r d; do
    [[ -f "$d/SKILL.md" ]] || {
      CHECK_ERROR_DETAIL="missing SKILL.md in vendored skill: $d"
      return 1
    }
  done < <(find "$SKILLS_DIR/core" -mindepth 1 -maxdepth 1 -type d | sort)

  grep -Eq '^source_mode\s*=\s*"' "$SKILLS_DIR/skills.lock.toml" || {
    CHECK_ERROR_DETAIL="skills.lock.toml missing source_mode"
    return 1
  }

  grep -Eq '^source_ref\s*=\s*"' "$SKILLS_DIR/skills.lock.toml" || {
    CHECK_ERROR_DETAIL="skills.lock.toml missing source_ref"
    return 1
  }

  return 0
}

check_no_absolute_user_paths() {
  local output
  output="$(rg -n '/Users/' "$PLAYBOOK_DIR" "$README_DOC" || true)"
  output="$(printf '%s\n' "$output" | rg -v 'playbook/scripts/validate-playbook.sh' || true)"
  if [[ -n "$output" ]]; then
    CHECK_ERROR_DETAIL="absolute user-specific paths found:\n$output"
    return 1
  fi

  return 0
}

check_bootstrap_cli_flags() {
  local output
  output="$($BOOTSTRAP_SCRIPT --help)"

  for flag in --target --mode --governance --agent --language --skills --skills-path --with-serena --with-codex-mcp --tooling-strict --github-repo; do
    if [[ "$output" != *"$flag"* ]]; then
      CHECK_ERROR_DETAIL="missing bootstrap flag in --help: $flag"
      return 1
    fi
  done

  for old_flag in --profile --resume --state-file --force-restart --no-serena --serena-codex-mcp; do
    if [[ "$output" == *"$old_flag"* ]]; then
      CHECK_ERROR_DETAIL="legacy flag still exposed in bootstrap --help: $old_flag"
      return 1
    fi
  done

  return 0
}

check_serena_helper_contract() {
  local output add_line
  output="$($SERENA_HELPER --help)"

  if [[ "$output" != *"install|codex-mcp|verify"* ]]; then
    CHECK_ERROR_DETAIL="Serena helper missing verify phase in --help"
    return 1
  fi

  if [[ "$output" == *"--target"* ]]; then
    CHECK_ERROR_DETAIL="Serena helper still exposes legacy --target"
    return 1
  fi

  add_line="$(grep -E 'codex mcp add serena' "$SERENA_HELPER" || true)"
  if [[ -z "$add_line" ]]; then
    CHECK_ERROR_DETAIL="Serena helper missing codex mcp add command"
    return 1
  fi

  if [[ "$add_line" != *"--context codex"* ]]; then
    CHECK_ERROR_DETAIL="Serena helper must use --context codex"
    return 1
  fi

  if [[ "$add_line" == *"--project"* ]]; then
    CHECK_ERROR_DETAIL="Serena helper must not include --project"
    return 1
  fi

  return 0
}

check_bootstrap_default_solo() {
  local p="$TMP_DIR/bootstrap-default"
  mkdir -p "$p"

  "$BOOTSTRAP_SCRIPT" --target "$p" >/dev/null

  [[ -f "$p/AGENTS.md" ]] || { CHECK_ERROR_DETAIL="missing AGENTS.md"; return 1; }
  [[ -f "$p/docs/ai/Flow.md" ]] || { CHECK_ERROR_DETAIL="missing docs/ai/Flow.md"; return 1; }
  [[ -f "$p/docs/ai/global-personalization.md" ]] || { CHECK_ERROR_DETAIL="missing global personalization guide"; return 1; }
  [[ -f "$p/scripts/commit-ready.sh" ]] || { CHECK_ERROR_DETAIL="missing scripts/commit-ready.sh"; return 1; }
  [[ -f "$p/.agent/skills/concise-planning/SKILL.md" ]] || { CHECK_ERROR_DETAIL="vendored skills not installed to default path"; return 1; }

  [[ ! -f "$p/.playbook-bootstrap.state" ]] || { CHECK_ERROR_DETAIL="legacy state file should not exist"; return 1; }
  [[ ! -f "$p/.github/workflows/ci.yml" ]] || { CHECK_ERROR_DETAIL="default solo bootstrap must not create strict .github workflows"; return 1; }

  return 0
}

check_bootstrap_strict() {
  local p="$TMP_DIR/bootstrap-strict"
  mkdir -p "$p"

  "$BOOTSTRAP_SCRIPT" --target "$p" --mode strict >/dev/null

  [[ -f "$p/.github/workflows/ci.yml" ]] || { CHECK_ERROR_DETAIL="strict bootstrap missing ci workflow"; return 1; }
  [[ -f "$p/.github/PULL_REQUEST_TEMPLATE.md" ]] || { CHECK_ERROR_DETAIL="strict bootstrap missing PR template"; return 1; }
  [[ -f "$p/docs/ai/github-protection.status" ]] || { CHECK_ERROR_DETAIL="strict bootstrap missing github-protection.status"; return 1; }

  return 0
}

check_bootstrap_mode_override() {
  local p="$TMP_DIR/bootstrap-mode-override"
  mkdir -p "$p"

  "$BOOTSTRAP_SCRIPT" --target "$p" --mode strict --governance off >/dev/null

  [[ ! -f "$p/.github/workflows/ci.yml" ]] || { CHECK_ERROR_DETAIL="mode strict + governance off should not copy strict workflows"; return 1; }
  [[ -f "$p/scripts/commit-ready.sh" ]] || { CHECK_ERROR_DETAIL="solo governance scripts missing"; return 1; }

  return 0
}

check_bootstrap_with_serena_warn_no_uv() {
  local p="$TMP_DIR/bootstrap-serena-warn"
  local output
  mkdir -p "$p"

  if ! output="$(env PATH="/usr/bin:/bin:/usr/sbin:/sbin" "$BOOTSTRAP_SCRIPT" --target "$p" --with-serena 2>&1)"; then
    CHECK_ERROR_DETAIL="bootstrap should succeed with warning when Serena tooling fails without --tooling-strict"
    return 1
  fi

  if [[ "$output" != *"WARN:"* ]]; then
    CHECK_ERROR_DETAIL="expected WARN output for missing Serena prerequisites"
    return 1
  fi

  return 0
}

check_bootstrap_with_serena_tooling_strict_no_uv() {
  local p="$TMP_DIR/bootstrap-serena-strict"
  mkdir -p "$p"

  if env PATH="/usr/bin:/bin:/usr/sbin:/sbin" "$BOOTSTRAP_SCRIPT" --target "$p" --with-serena --tooling-strict >/dev/null 2>&1; then
    CHECK_ERROR_DETAIL="bootstrap should fail when tooling fails under --tooling-strict"
    return 1
  fi

  return 0
}

check_bootstrap_with_codemcp_warn_no_codex() {
  local p="$TMP_DIR/bootstrap-codemcp-warn"
  local fakebin="$TMP_DIR/fakebin"
  local output
  mkdir -p "$p" "$fakebin"

  cat > "$fakebin/uv" <<'EOF_UV'
#!/usr/bin/env bash
exit 0
EOF_UV
  cat > "$fakebin/uvx" <<'EOF_UVX'
#!/usr/bin/env bash
exit 0
EOF_UVX
  chmod +x "$fakebin/uv" "$fakebin/uvx"

  if ! output="$(env PATH="$fakebin:/usr/bin:/bin:/usr/sbin:/sbin" "$BOOTSTRAP_SCRIPT" --target "$p" --with-serena --with-codex-mcp 2>&1)"; then
    CHECK_ERROR_DETAIL="bootstrap should succeed with warning when codex is unavailable and tooling is non-strict"
    return 1
  fi

  if [[ "$output" != *"WARN:"* ]]; then
    CHECK_ERROR_DETAIL="expected warning output for missing codex in optional mcp step"
    return 1
  fi

  return 0
}

check_readiness_warning_and_strict() {
  local p="$TMP_DIR/readiness-warn"
  local output rc
  mkdir -p "$p"

  "$BOOTSTRAP_SCRIPT" --target "$p" >/dev/null

  set +e
  output="$(cd "$p" && bash scripts/project-readiness-check.sh 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    CHECK_ERROR_DETAIL="default readiness should pass with warnings, got exit $rc"
    return 1
  fi

  if [[ "$output" != *"PASS with warnings"* ]]; then
    CHECK_ERROR_DETAIL="default readiness output should mention 'PASS with warnings'"
    return 1
  fi

  set +e
  output="$(cd "$p" && bash scripts/project-readiness-check.sh --strict 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -ne 2 ]]; then
    CHECK_ERROR_DETAIL="strict readiness should exit 2 when warnings exist, got $rc"
    return 1
  fi

  if [[ "$output" != *"FAIL(strict warnings)"* ]]; then
    CHECK_ERROR_DETAIL="strict readiness output should mention FAIL(strict warnings)"
    return 1
  fi

  return 0
}

check_strict_missing_governance_file() {
  local p="$TMP_DIR/readiness-strict-missing"
  local rc
  mkdir -p "$p"

  "$BOOTSTRAP_SCRIPT" --target "$p" --mode strict >/dev/null
  chmod -x "$p/scripts/run-quality-gates.sh"

  set +e
  (cd "$p" && bash scripts/project-readiness-check.sh --strict >/dev/null 2>&1)
  rc=$?
  set -e

  if [[ "$rc" -ne 1 ]]; then
    CHECK_ERROR_DETAIL="strict readiness should exit 1 for critical failure, got $rc"
    return 1
  fi

  return 0
}

check_no_legacy_terms() {
  local output
  output="$(rg -n 'students-core|pro-core|antigravity-awesome-skills|--profile|--resume|--state-file|--force-restart|--no-serena|--serena-codex-mcp' \
    "$PLAYBOOK_DIR" "$README_DOC" || true)"
  output="$(printf '%s\n' "$output" | rg -v 'playbook/scripts/validate-playbook.sh' || true)"
  if [[ -n "$output" ]]; then
    CHECK_ERROR_DETAIL="legacy terms still present:\n$output"
    return 1
  fi

  return 0
}

check_links_setup_md() {
  local links_raw
  local link

  links_raw="$(rg -o 'https://[^` )]+' "$SETUP_DOC" | sort -u || true)"
  if [[ -z "$links_raw" ]]; then
    CHECK_ERROR_DETAIL="no links found in setup.md"
    return 1
  fi

  while IFS= read -r link; do
    [[ -n "$link" ]] || continue
    if ! curl -fsSIL --connect-timeout 5 --max-time 15 "$link" >/dev/null 2>&1; then
      if ! curl -fsSL --connect-timeout 5 --max-time 20 "$link" >/dev/null 2>&1; then
        CHECK_ERROR_DETAIL="failed link check: $link"
        return 1
      fi
    fi
  done <<< "$links_raw"

  return 0
}

run_check "required-files-present" check_required_files_present
run_check "legacy-removed" check_legacy_removed
run_check "adapter-contract" check_adapter_contract
run_check "core-universal-policy" check_core_universal_policy
run_check "skills-baseline" check_skills_baseline
run_check "bootstrap-cli-flags" check_bootstrap_cli_flags
run_check "serena-helper-contract" check_serena_helper_contract
run_check "no-absolute-user-paths" check_no_absolute_user_paths
run_check "bootstrap-default-solo" check_bootstrap_default_solo
run_check "bootstrap-strict" check_bootstrap_strict
run_check "bootstrap-mode-override" check_bootstrap_mode_override
run_check "bootstrap-serena-warn-no-uv" check_bootstrap_with_serena_warn_no_uv
run_check "bootstrap-serena-tooling-strict-no-uv" check_bootstrap_with_serena_tooling_strict_no_uv
run_check "bootstrap-codemcp-warn-no-codex" check_bootstrap_with_codemcp_warn_no_codex
run_check "readiness-warning-and-strict" check_readiness_warning_and_strict
run_check "strict-readiness-critical-failure" check_strict_missing_governance_file
run_check "no-legacy-terms" check_no_legacy_terms

if [[ "$SMOKE" -eq 1 || "$NO_LINKS" -eq 1 ]]; then
  skip_check "link-integrity-setup-md" "$([[ "$SMOKE" -eq 1 ]] && echo smoke-mode || echo --no-links)"
else
  run_check "link-integrity-setup-md" check_links_setup_md
fi

echo ""
echo "Summary: PASS=$PASS_COUNT FAIL=$FAIL_COUNT SKIP=$SKIP_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "VALIDATION FAILED"
  exit 1
fi

echo "ALL CHECKS PASSED"

#!/usr/bin/env bash

state_reset_defaults() {
  VERSION="3"
  MODE="solo"
  TARGET=""
  AGENT="none"
  LANGUAGE="none"
  PROFILE="minimal"
  GOVERNANCE="off"
  GITHUB_REPO=""
  NO_SERENA="0"
  SERENA_CODEX_MCP="required"

  STEP_CORE="pending"
  STEP_ADAPTERS="pending"
  STEP_SELECTION="pending"
  STEP_GOVERNANCE_FILES="pending"
  STEP_GITHUB_PROTECTION="pending"
  STEP_GLOBAL_GUIDE="pending"
  STEP_SERENA_INSTALL="pending"
  STEP_SERENA_CODEX_MCP="pending"
  STEP_SERENA_VERIFY="pending"

  STATUS="running"
  BLOCKED_STEP=""
  BLOCKED_REASON=""
  RESUME_HINT=""
}

state_quote() {
  printf "%q" "${1:-}"
}

state_load() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  VERSION=""
  MODE=""
  TARGET=""
  AGENT=""
  LANGUAGE=""
  PROFILE=""
  GOVERNANCE=""
  GITHUB_REPO=""
  NO_SERENA=""
  SERENA_CODEX_MCP=""
  STEP_CORE=""
  STEP_ADAPTERS=""
  STEP_SELECTION=""
  STEP_GOVERNANCE_FILES=""
  STEP_GITHUB_PROTECTION=""
  STEP_GLOBAL_GUIDE=""
  STEP_SERENA_INSTALL=""
  STEP_SERENA_CODEX_MCP=""
  STEP_SERENA_VERIFY=""
  STATUS=""
  BLOCKED_STEP=""
  BLOCKED_REASON=""
  RESUME_HINT=""

  # shellcheck disable=SC1090
  . "$file"

  : "${VERSION:=3}"
  : "${MODE:=}"
  : "${TARGET:=}"
  : "${AGENT:=none}"
  : "${LANGUAGE:=none}"
  : "${PROFILE:=minimal}"
  : "${GOVERNANCE:=off}"
  : "${GITHUB_REPO:=}"
  : "${NO_SERENA:=0}"
  : "${SERENA_CODEX_MCP:=required}"

  : "${STEP_CORE:=pending}"
  : "${STEP_ADAPTERS:=pending}"
  : "${STEP_SELECTION:=pending}"
  : "${STEP_GOVERNANCE_FILES:=pending}"
  : "${STEP_GITHUB_PROTECTION:=pending}"
  : "${STEP_GLOBAL_GUIDE:=pending}"
  : "${STEP_SERENA_INSTALL:=pending}"
  : "${STEP_SERENA_CODEX_MCP:=pending}"
  : "${STEP_SERENA_VERIFY:=pending}"

  : "${STATUS:=running}"
  : "${BLOCKED_STEP:=}"
  : "${BLOCKED_REASON:=}"
  : "${RESUME_HINT:=}"

  # Backward compatibility for legacy state files (VERSION<=2) without MODE.
  if [[ -z "$MODE" ]]; then
    if [[ "$GOVERNANCE" == "required" ]]; then
      MODE="strict"
    else
      MODE="solo"
    fi
  fi

  return 0
}

state_save() {
  local file="$1"

  cat > "$file" <<EOF_STATE
VERSION=$(state_quote "$VERSION")
MODE=$(state_quote "$MODE")
TARGET=$(state_quote "$TARGET")
AGENT=$(state_quote "$AGENT")
LANGUAGE=$(state_quote "$LANGUAGE")
PROFILE=$(state_quote "$PROFILE")
GOVERNANCE=$(state_quote "$GOVERNANCE")
GITHUB_REPO=$(state_quote "$GITHUB_REPO")
NO_SERENA=$(state_quote "$NO_SERENA")
SERENA_CODEX_MCP=$(state_quote "$SERENA_CODEX_MCP")
STEP_CORE=$(state_quote "$STEP_CORE")
STEP_ADAPTERS=$(state_quote "$STEP_ADAPTERS")
STEP_SELECTION=$(state_quote "$STEP_SELECTION")
STEP_GOVERNANCE_FILES=$(state_quote "$STEP_GOVERNANCE_FILES")
STEP_GITHUB_PROTECTION=$(state_quote "$STEP_GITHUB_PROTECTION")
STEP_GLOBAL_GUIDE=$(state_quote "$STEP_GLOBAL_GUIDE")
STEP_SERENA_INSTALL=$(state_quote "$STEP_SERENA_INSTALL")
STEP_SERENA_CODEX_MCP=$(state_quote "$STEP_SERENA_CODEX_MCP")
STEP_SERENA_VERIFY=$(state_quote "$STEP_SERENA_VERIFY")
STATUS=$(state_quote "$STATUS")
BLOCKED_STEP=$(state_quote "$BLOCKED_STEP")
BLOCKED_REASON=$(state_quote "$BLOCKED_REASON")
RESUME_HINT=$(state_quote "$RESUME_HINT")
EOF_STATE
}

state_mark_done() {
  local step_var="$1"

  printf -v "$step_var" '%s' "done"
  STATUS="running"
  BLOCKED_STEP=""
  BLOCKED_REASON=""
  RESUME_HINT=""
}

state_mark_blocked() {
  local step_var="$1"
  local reason="$2"
  local resume_hint="$3"

  printf -v "$step_var" '%s' "blocked"
  STATUS="blocked"
  BLOCKED_STEP="$step_var"
  BLOCKED_REASON="$reason"
  RESUME_HINT="$resume_hint"
}

state_mark_completed() {
  STATUS="completed"
  BLOCKED_STEP=""
  BLOCKED_REASON=""
  RESUME_HINT=""
}

state_step_is_done() {
  local step_var="$1"
  local value="${!step_var:-pending}"

  [[ "$value" == "done" ]]
}

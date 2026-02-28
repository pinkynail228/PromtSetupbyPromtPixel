#!/usr/bin/env bash
set -euo pipefail

PHASE="install"

usage() {
  cat <<'USAGE'
Usage:
  install-serena-mcp.sh [--phase <install|codex-mcp|verify>] [--help]

Return codes:
  0 success
  1 invalid usage/config
  2 missing prerequisites (uv/codex/uvx)
  3 command failed
USAGE
}

err() {
  echo "ERROR: $*" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase)
      PHASE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

case "$PHASE" in
  install|codex-mcp|verify) ;;
  *)
    err "unknown phase: $PHASE"
    usage
    exit 1
    ;;
esac

if [[ "$PHASE" == "install" ]]; then
  if ! command -v uv >/dev/null 2>&1; then
    err "uv is not installed or not available in PATH"
    exit 2
  fi

  if ! uv tool install "git+https://github.com/oraios/serena"; then
    err "failed to install serena using uv tool install"
    exit 3
  fi

  if command -v serena >/dev/null 2>&1; then
    echo "Serena binary is available in PATH."
    exit 0
  fi

  if uvx --from "git+https://github.com/oraios/serena" serena --help >/dev/null 2>&1; then
    echo "Serena is available via uvx."
    exit 0
  fi

  err "serena command is not available after installation"
  exit 3
fi

if [[ "$PHASE" == "codex-mcp" ]]; then
  if ! command -v codex >/dev/null 2>&1; then
    err "codex CLI is not installed or not available in PATH"
    exit 2
  fi

  if ! command -v uvx >/dev/null 2>&1; then
    err "uvx is not installed or not available in PATH"
    exit 2
  fi

  if codex mcp get serena >/dev/null 2>&1; then
    echo "Codex MCP server 'serena' already configured."
    exit 0
  fi

  if ! codex mcp add serena -- uvx --from "git+https://github.com/oraios/serena" serena start-mcp-server --context codex; then
    err "failed to register serena in codex mcp"
    exit 3
  fi

  echo "Codex MCP server 'serena' registered."
  exit 0
fi

if ! command -v codex >/dev/null 2>&1; then
  err "codex CLI is not installed or not available in PATH"
  exit 2
fi

out="$(codex mcp get serena 2>&1)" || {
  err "serena MCP is not registered in codex"
  err "$out"
  exit 3
}

if [[ "$out" != *"--context codex"* ]]; then
  err "serena MCP command must include '--context codex'"
  err "$out"
  exit 3
fi

if [[ "$out" == *"--project"* ]]; then
  err "serena MCP command must be global and must not include '--project'"
  err "$out"
  exit 3
fi

echo "Serena MCP command shape verification passed."

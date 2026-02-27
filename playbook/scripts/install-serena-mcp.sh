#!/usr/bin/env bash
set -euo pipefail

PHASE="install"
TARGET=""

usage() {
  cat <<'USAGE'
Usage:
  install-serena-mcp.sh [--phase <install|codex-mcp>] [--target <path>] [--help]

Phases:
  install      Install Serena via uv and verify availability
  codex-mcp    Ensure Codex MCP server named "serena" is registered globally
USAGE
}

blocked() {
  local reason="$1"

  printf 'SERENA_SETUP_BLOCKED: %s\n' "$reason" >&2
  printf 'Check the following and retry:\n' >&2
  printf '  1) network access is available\n' >&2
  printf '  2) write access to user-level tool directories is available\n' >&2
  printf '  3) write access to ~/.codex/* is available for MCP registration\n' >&2
  exit 20
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase)
      PHASE="${2:-}"
      shift 2
      ;;
    --target)
      TARGET="${2:-}"
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

case "$PHASE" in
  install|codex-mcp) ;;
  *)
    echo "ERROR: unknown phase: $PHASE" >&2
    usage
    exit 2
    ;;
esac

if [[ "$PHASE" == "install" ]]; then
  if ! command -v uv >/dev/null 2>&1; then
    blocked "uv is not installed or not available in PATH"
  fi

  if ! uv tool install "git+https://github.com/oraios/serena"; then
    blocked "failed to install serena using uv tool install"
  fi

  if command -v serena >/dev/null 2>&1; then
    printf 'Serena binary is available in PATH.\n'
    exit 0
  fi

  if uvx --from "git+https://github.com/oraios/serena" serena --help >/dev/null 2>&1; then
    printf 'Serena is available via uvx.\n'
    exit 0
  fi

  blocked "serena command is not available after installation"
fi

if ! command -v codex >/dev/null 2>&1; then
  blocked "codex CLI is not installed or not available in PATH"
fi

if ! command -v uvx >/dev/null 2>&1; then
  blocked "uvx is not installed or not available in PATH"
fi

if codex mcp get serena >/dev/null 2>&1; then
  printf 'Codex MCP server "serena" already configured.\n'
  exit 0
fi

if ! codex mcp add serena -- uvx --from "git+https://github.com/oraios/serena" serena start-mcp-server --context codex; then
  blocked "failed to register serena in codex mcp"
fi

printf 'Codex MCP server "serena" registered.\n'

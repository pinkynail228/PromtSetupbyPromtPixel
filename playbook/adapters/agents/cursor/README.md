# Cursor Adapter

Adds `.cursor/rules` bridge so Cursor consistently uses universal project docs.

## Behavior

- Cursor bridge points to `AGENTS.md`, `Flow.md`, and context workflow docs.
- Repository-wide manual scans are fallback after context loading.

## Limitations

- Keep Cursor-specific behavior in this adapter only.

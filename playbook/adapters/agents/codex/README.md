# Codex Adapter

Adds Codex-specific optional rules while keeping `AGENTS.md` as the primary source.

## Behavior

- Codex bridge follows project flow and context workflow if present.
- Manual deep scanning is fallback when project context records are insufficient.

## Limitations

- Codex already reads root `AGENTS.md`; this adapter is optional.

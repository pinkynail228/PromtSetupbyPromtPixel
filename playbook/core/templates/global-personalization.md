# Global Personalization (Manual Guided Step)

Complete this file before major implementation work in a new project.

## Global Engineering Principles (copy baseline)

Use these principles in every assistant:

1. Prefer minimal, reversible changes.
2. Verify behavior with targeted checks before broad checks.
3. Distinguish facts from assumptions explicitly.
4. Keep architecture boundaries and avoid opportunistic refactors.
5. Report what changed, what was verified, and what risks remain.
6. Use available context systems before deep manual repository scanning.

## Codex global setup (manual)

1. Create/update `~/.codex/AGENTS.md` with your global coding standards.
2. Optional config snippet for `~/.codex/config.toml`:

```toml
model_instructions_file = "~/.codex/AGENTS.md"
project_doc_fallback_filenames = ["AGENTS.md"]
```

## Cursor global setup (manual)

1. Open Settings.
2. Go to **Rules and Memories**.
3. Update **User Rules** with the engineering principles above.

## Antigravity global setup (manual)

1. Open global rules/customization.
2. Add the same engineering principles as global defaults.
3. Keep project-specific rules in workspace-level `.agent/rules/*`.

## Completion checklist

- [ ] Codex global file reviewed (if Codex is used)
- [ ] Cursor user rules reviewed (if Cursor is used)
- [ ] Antigravity global rules reviewed (if Antigravity is used)
- [ ] Global engineering principles aligned across used tools

## Optional completion marker

Create this file after manual setup if you want readiness checks to stop warning:

- `docs/ai/global-personalization.done`

Recommended command:

```bash
echo "completed $(date -u '+%Y-%m-%dT%H:%M:%SZ')" > docs/ai/global-personalization.done
```

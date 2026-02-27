# Global Personalization (Manual Guided Step)

Complete this file before the first implementation task in a new project.

## Global Engineering Principles (copy baseline)

Use these principles in every assistant:

1. Prefer minimal, reversible changes.
2. Verify behavior with targeted checks before broad checks.
3. Distinguish facts from assumptions explicitly.
4. Keep architecture boundaries and avoid opportunistic refactors.
5. Report what was changed, what was verified, and what risks remain.
6. Use Serena-first context workflow to reduce rediscovery and token waste.

## Codex Global Setup (manual)

### 1) Global instructions file

Create or update `~/.codex/AGENTS.md` with your personal coding standards.

### 2) Global config snippet

Add this snippet to `~/.codex/config.toml`:

```toml
model_instructions_file = "~/.codex/AGENTS.md"
project_doc_fallback_filenames = ["AGENTS.md"]
```

### 3) Codex global rule addition

Add explicit Serena-first instruction to `~/.codex/AGENTS.md`:

- "Before broad manual codebase reading, use Serena project activation and memory lookup."

## Cursor Global Setup (manual)

1. Open Cursor settings.
2. Go to **Rules and Memories**.
3. Update **User Rules** using the same engineering principles above.
4. Add an explicit Serena-first sentence in User Rules.
5. Keep project-specific behavior in repository-level rules only.

## Antigravity Global Setup (manual)

1. Open global rules/customization in Antigravity.
2. Add the same engineering principles as global defaults.
3. Add an explicit Serena-first sentence in global rules/skills policy.
4. Keep project-specific rules in workspace-level `.agent/rules/*`.
5. Keep skills curated and enable advanced/offensive skills only with explicit approval.

## Completion Checklist

- [ ] Codex global file updated (`~/.codex/AGENTS.md`)
- [ ] Codex config updated (`~/.codex/config.toml`)
- [ ] Cursor User Rules updated
- [ ] Antigravity global rules updated
- [ ] Serena-first instruction added to all global tools

## Completion marker (required for readiness)

After completing all checklist items, create:

- `docs/ai/global-personalization.done`

Recommended command:

```bash
echo "completed $(date -u '+%Y-%m-%dT%H:%M:%SZ')" > docs/ai/global-personalization.done
```

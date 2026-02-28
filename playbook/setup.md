# setup.md - Universal Playbook Bootstrap (v4.1)

Purpose: bootstrap an AI collaboration baseline for any project, language, and runtime with low default friction and optional advanced tooling.

## Design principles

- `Core first`: universal process and quality rules with no stack-specific commands.
- `Adapter-based`: add agent and language behavior only when explicitly selected.
- `Template-only`: this repository is a reusable template, not a runtime workspace.
- `Manual global personalization`: global user settings are never edited automatically.
- `Solo-first default`: local gates workflow with no mandatory PR process.
- `Strict opt-in`: GitHub PR/protection discipline when explicitly enabled.
- `Tool-agnostic core`: Serena/Codex are optional tooling, not baseline requirements.
- `Vendored skills baseline`: project-local skills are copied from this repository.

## Playbook layout

```text
playbook/
├─ core/
│  ├─ AGENTS.md
│  ├─ Flow.md
│  ├─ governance/
│  │  ├─ files/              # strict pack
│  │  └─ solo/files/         # solo pack
│  └─ templates/
│     ├─ plan.md
│     ├─ report.md
│     ├─ context-provider-guide.md
│     └─ global-personalization.md
├─ adapters/
│  ├─ agents/{codex,claude,cursor,antigravity}
│  ├─ languages/{python,swift,_template}
│  └─ tooling/serena         # optional tooling pack
├─ skills/
│  ├─ core/<skill-id>/SKILL.md
│  ├─ skills.lock.toml
│  └─ NOTICE.md
├─ scripts/
│  ├─ bootstrap.sh
│  ├─ install-serena-mcp.sh
│  ├─ skills/{install-vendored-skills,refresh-vendored-skills}.sh
│  ├─ github/{apply,verify}-branch-protection.sh
│  └─ validate-playbook.sh
└─ reports/
```

## Mode matrix

| Mode | Default governance | Workflow | Typical user |
|---|---|---|---|
| `solo` | `off` | local `commit-ready` + readiness checks | single developer (`main + commits`) |
| `strict` | `required` | GitHub PR/CI/protection discipline | team/review-heavy flow |

## Mode vs governance precedence

1. `--mode` computes default governance.
2. `solo -> off`
3. `strict -> required`
4. Explicit `--governance` overrides mode-derived default.

## Bootstrap CLI

```bash
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/new-project \
  --agent codex \
  --language python
```

Strict example:

```bash
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/new-project \
  --mode strict \
  --agent antigravity \
  --language swift \
  --github-repo owner/repo
```

Optional tooling example:

```bash
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/new-project \
  --with-serena \
  --with-codex-mcp
```

Important flags:

- `--skills <vendored|off>`: vendored skills install mode (`vendored` default)
- `--skills-path <path>`: install destination for project-local skills (default: `<target>/.agent/skills`)
- `--with-serena`: run optional Serena installation
- `--with-codex-mcp`: optional Codex MCP registration (requires `--with-serena`)
- `--tooling-strict`: make optional tooling failures blocking

## Bootstrap lifecycle

`bootstrap.sh` runs a linear pipeline:

1. Copy core files.
2. Apply governance pack (`solo` or `strict`).
3. Apply selected agent/language adapters.
4. Install vendored skills (default path: `.agent/skills`).
5. Optionally apply strict GitHub protection (if `--github-repo` + `gh auth`).
6. Create `docs/ai/global-personalization.md`.
7. Optionally run Serena tooling (`--with-serena`, `--with-codex-mcp`).
8. Print post-bootstrap TODOs.

## Vendored skills policy

- Skills are stored in `playbook/skills/core`.
- They are copied into each target project by default.
- Lock metadata is stored in `playbook/skills/skills.lock.toml`.
- Refresh is manual via:

```bash
./playbook/scripts/skills/refresh-vendored-skills.sh \
  --manifest ./playbook/skills/skills.lock.toml \
  --source local \
  --ref v4.1-baseline
```

## Readiness behavior

`bash scripts/project-readiness-check.sh` returns:

- `FAIL` (`exit 1`) for critical missing files/executables.
- `PASS with warnings` (`exit 0`) for non-critical gaps.
- `FAIL(strict warnings)` (`exit 2`) when `--strict` is used and warnings exist.

Warnings include examples like:

- missing `docs/ai/global-personalization.done`
- optional Serena tooling not configured
- branch protection not verifiable in strict context

## Daily workflow

1. Run task using project flow and context workflow.
2. Before commit:

```bash
bash scripts/commit-ready.sh
```

3. Periodically:

```bash
bash scripts/project-readiness-check.sh
# or strict interpretation
bash scripts/project-readiness-check.sh --strict
```

## Validation

```bash
./playbook/scripts/validate-playbook.sh --smoke
./playbook/scripts/validate-playbook.sh --no-links
./playbook/scripts/validate-playbook.sh
```

## External references

- OpenAI Codex docs: `https://developers.openai.com/codex`
- OpenAI Codex AGENTS.md guide: `https://developers.openai.com/codex/guides/agents-md`
- Cursor rules docs: `https://cursor.com/docs/context/rules`
- Antigravity docs: `https://antigravity.google/docs/home`
- Serena repository: `https://github.com/oraios/serena`

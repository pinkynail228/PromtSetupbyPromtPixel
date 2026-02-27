# setup.md — Universal Playbook Bootstrap (Solo-First v3)

Purpose: bootstrap an AI collaboration baseline for any project, language, and runtime, optimized for local commit workflows with Serena-first discipline.

## Design principles

- `Core first`: universal process and quality rules with no stack-specific commands.
- `Adapter-based`: add agent and language behavior only when explicitly selected.
- `Template-only`: this repository is a reusable template, not a runtime workspace.
- `Manual global personalization`: global user settings are never edited automatically.
- `Solo-first default`: bootstrap defaults to local-gates workflow without mandatory PR overhead.
- `Strict opt-in`: GitHub PR/protection discipline is available with explicit mode.
- `Serena default-on`: Serena install starts by default unless explicitly disabled.
- `Serena-first`: context discovery must start from Serena memory/workflow before broad manual codebase exploration.

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
│     └─ global-personalization.md
├─ adapters/
│  ├─ agents/{codex, claude, cursor, antigravity}
│  └─ languages/{python, swift, _template}
├─ curation/
│  ├─ students-core.txt
│  ├─ pro-core.txt
│  └─ check-profile.sh
└─ scripts/
   ├─ bootstrap.sh
   ├─ install-serena-mcp.sh
   ├─ github/{apply,verify}-branch-protection.sh
   ├─ validate-playbook.sh
   └─ lib/state.sh
```

## Mode matrix

| Mode | Default governance | Workflow | Typical user |
|---|---|---|---|
| `solo` | `off` | local `commit-ready` + readiness checks | single developer (`main + commits`) |
| `strict` | `required` | GitHub PR/CI/protection discipline | team/review-heavy flow |

## Mode vs governance precedence

1. `--mode` computes default governance:
2. `solo -> off`
3. `strict -> required`
4. Explicit `--governance` overrides mode-derived default.

Examples:

```bash
# mode-driven
./playbook/scripts/bootstrap.sh --target /abs/project --mode strict

# explicit override
./playbook/scripts/bootstrap.sh --target /abs/project --mode strict --governance off
```

## Bootstrap lifecycle

`bootstrap.sh` executes a stateful step-machine and writes state to:

- default: `<target>/.playbook-bootstrap.state`
- custom: `--state-file <path>`

Step order:

1. Core files
2. Governance files (`solo` or `strict` pack based on effective governance)
3. Adapters and profile files
4. Selection manifest (`mode` + `effective_governance`)
5. GitHub protection attempt (strict mode only when repo/gh available)
6. Global personalization guide (manual step)
7. Serena install (default-on)
8. Codex MCP registration for Serena (default mode: `required`)
9. Serena command-shape verification

## CLI

```bash
# default: mode=solo, governance=off
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/new-project \
  --agent codex \
  --language swift \
  --profile students

# strict mode
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/new-project \
  --mode strict \
  --github-repo owner/repo
```

Important flags:

- `--mode <solo|strict>`: workflow mode (`solo` default)
- `--governance <required|off>`: explicit governance override
- `--resume`: continue from state file after a blocked run
- `--state-file <path>`: custom state file location
- `--force-restart`: delete state and start from scratch
- `--github-repo <owner/repo>`: optional branch protection auto-apply target in strict mode
- `--no-serena`: skip Serena install and MCP registration
- `--serena-codex-mcp <required|off>`: MCP registration mode

## Governance packs

### Solo pack (`governance=off`)

- local-first artifacts only
- no mandatory `.github/workflows` or PR template
- includes:
  - `scripts/run-quality-gates.sh`
  - `scripts/run-security-gates.sh`
  - `scripts/run-dod-gate.sh`
  - `scripts/commit-ready.sh`
  - `scripts/project-readiness-check.sh`
  - Serena workflow/memory policy docs

### Strict pack (`governance=required`)

- full GitHub-oriented set (`.github/*`, protection checklist, verify/apply scripts)
- includes all solo gate/readiness scripts plus PR/protection discipline

## Daily workflow (solo or strict)

1. Run task with Serena-first context protocol.
2. Before commit run:

```bash
bash scripts/commit-ready.sh
```

3. Periodically run readiness:

```bash
bash scripts/project-readiness-check.sh
```

## Manual global personalization (required)

Bootstrap always creates:

- `docs/ai/global-personalization.md`

You must complete this guide before first implementation task and create:

- `docs/ai/global-personalization.done`

## Serena lifecycle

By default, bootstrap runs:

1. `uv tool install "git+https://github.com/oraios/serena"`
2. Serena availability verification
3. `codex mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context codex`
4. `codex mcp get serena` command-shape verification (`--context codex`, no `--project`)

If Serena step fails, bootstrap exits with code `20`, writes `STATUS=blocked` to state, and prints exact resume command.

Resume:

```bash
./playbook/scripts/bootstrap.sh --target /absolute/path/to/new-project --resume
```

`--no-serena` is allowed for bootstrap, but readiness remains FAIL until Serena MCP is configured.

## Readiness behavior

`scripts/project-readiness-check.sh` always enforces:

- core docs and local gate scripts
- Serena workflow docs
- `docs/ai/global-personalization.done`
- Serena MCP command shape

Strict-only branch protection enforcement:

- activated only when strict context is detected (for example `.github/workflows/ci.yml` present or `--repo` passed)
- skipped in solo projects by default

## On-demand skills

This template does not vendor skills.
Install and validate on demand:

```bash
npx antigravity-awesome-skills --path ~/.agent/skills
./playbook/curation/check-profile.sh students-core --skills-root ~/.agent/skills
```

## Validation

```bash
# Full regression
./playbook/scripts/validate-playbook.sh

# Fast checks
./playbook/scripts/validate-playbook.sh --smoke

# Skip URL checks
./playbook/scripts/validate-playbook.sh --no-links
```

## External references

- OpenAI Codex docs: `https://developers.openai.com/codex`
- OpenAI Codex AGENTS.md guide: `https://developers.openai.com/codex/guides/agents-md`
- OpenAI Codex config reference: `https://developers.openai.com/codex/config-reference`
- OpenAI Codex rules: `https://developers.openai.com/codex/rules`
- Cursor rules docs: `https://cursor.com/docs/context/rules`
- Cursor CLI rules loading: `https://cursor.com/docs/cli/using`
- Antigravity docs: `https://antigravity.google/docs/home`
- Serena repository: `https://github.com/oraios/serena`

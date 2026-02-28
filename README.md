# Universal Sandbox Playbook

[![Mode](https://img.shields.io/badge/mode-solo--first-2ea44f)](./playbook/setup.md)
[![Core](https://img.shields.io/badge/core-tool--agnostic-0366d6)](./playbook/core/AGENTS.md)
[![Skills](https://img.shields.io/badge/skills-vendored%20baseline-8250df)](./playbook/skills/NOTICE.md)
[![Type](https://img.shields.io/badge/repo-template-555)](./playbook)

Universal template for serious AI-assisted development in any stack.

## Русский

### Что это

`Sandbox` — шаблон-репозиторий для старта новых проектов.
Он задает процесс и качество, а не конкретный стек.

Ключевые свойства:

- универсальный core-процесс (`Plan -> Context -> Implement -> Verify -> Report`)
- `solo` по умолчанию (low-friction: `main + commits`)
- `strict` как opt-in (GitHub PR/protection дисциплина)
- вендоренные project-local skills (`.agent/skills`) без обязательного `npx`
- Serena/Codex остаются **опциональными** tooling-шагами

Source of truth: `playbook/`.

### Быстрый старт

1. Проверить шаблон:

```bash
./playbook/scripts/validate-playbook.sh --smoke
```

2. Запустить bootstrap (solo default):

```bash
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/project \
  --agent codex \
  --language python
```

3. Strict режим при необходимости:

```bash
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/project \
  --mode strict \
  --agent antigravity \
  --language swift \
  --github-repo owner/repo
```

4. Опционально подключить Serena tooling:

```bash
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/project \
  --with-serena \
  --with-codex-mcp
```

### После bootstrap (в target-проекте)

```bash
bash scripts/commit-ready.sh
bash scripts/project-readiness-check.sh
# strict-интерпретация warning'ов
bash scripts/project-readiness-check.sh --strict
```

## English

### What this is

`Sandbox` is a reusable template repository for starting new projects with a serious AI workflow.
It is process-first and stack-agnostic.

Highlights:

- universal core flow (`Plan -> Context -> Implement -> Verify -> Report`)
- default `solo` mode for low-friction local work
- opt-in `strict` mode for GitHub process controls
- vendored project-local skills baseline (`.agent/skills`)
- Serena/Codex integration as optional tooling (not baseline hard requirement)

Source of truth: `playbook/`.

### Quick start

1. Validate template:

```bash
./playbook/scripts/validate-playbook.sh --smoke
```

2. Bootstrap a new project (solo default):

```bash
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/project \
  --agent codex \
  --language python
```

3. Strict mode (optional):

```bash
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/project \
  --mode strict \
  --agent antigravity \
  --language swift \
  --github-repo owner/repo
```

4. Optional Serena tooling:

```bash
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/project \
  --with-serena \
  --with-codex-mcp
```

### Main scripts

Template repo scripts:

- `playbook/scripts/bootstrap.sh`
- `playbook/scripts/validate-playbook.sh`
- `playbook/scripts/install-serena-mcp.sh`
- `playbook/scripts/skills/install-vendored-skills.sh`
- `playbook/scripts/skills/refresh-vendored-skills.sh`

Generated target project scripts:

- `scripts/commit-ready.sh`
- `scripts/project-readiness-check.sh`
- `scripts/run-quality-gates.sh`
- `scripts/run-security-gates.sh`
- `scripts/run-dod-gate.sh`

### Structure

```text
playbook/
├─ core/
├─ adapters/
│  ├─ agents/
│  ├─ languages/
│  └─ tooling/serena/
├─ skills/
├─ scripts/
└─ reports/
```

See full details in `playbook/setup.md`.

# Universal Sandbox Playbook

[![Mode](https://img.shields.io/badge/mode-solo--first-2ea44f)](./playbook/setup.md)
[![Serena](https://img.shields.io/badge/serena-first-0a66c2)](./playbook/setup.md#serena-lifecycle)
[![Governance](https://img.shields.io/badge/governance-strict%20opt--in-6f42c1)](./playbook/setup.md#mode-matrix)
[![Type](https://img.shields.io/badge/repo-template-555)](./playbook)

Serena-first, solo-first template for serious AI-assisted development in any stack.

---

## TL;DR

- Default workflow is `solo`: fast `main + commits` with local quality gates.
- `strict` mode is opt-in: GitHub PR/process discipline when you need team-grade controls.
- Serena is default-on and required for full readiness quality.
- This repo is stack-agnostic: process first, adapters second.

---

## Русский

### Что это

`Sandbox` это универсальный шаблон-репозиторий для старта новых проектов.  
Он задает не конкретный стек, а дисциплину работы:

- единый core-процесс (`Plan -> Context -> Implement -> Verify -> Report`);
- Serena-first подход к контексту и памяти;
- готовые скрипты quality/security/DoD;
- режим по умолчанию для solo-разработки (`main + commits`);
- строгий GitHub-режим как opt-in.

Source of truth: `playbook/`.

### Когда использовать

- стартуешь новый проект и хочешь сразу “взрослый” процесс;
- работаешь solo, но не хочешь скатываться в хаос;
- нужна единая база под разные языки и разные AI-инструменты.

### Быстрый выбор режима

| Сценарий | Режим | Почему |
|---|---|---|
| Один разработчик, скорость важнее PR-процесса | `solo` (default) | минимум бюрократии, максимум дисциплины через local gates |
| Команда, review и GitHub policy обязательны | `strict` | PR шаблоны, workflows, branch protection проверки |

### Быстрый старт

1. Проверить шаблон:

```bash
./playbook/scripts/validate-playbook.sh --smoke
```

2. Запустить bootstrap в новый проект (solo по умолчанию):

```bash
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/project \
  --agent codex \
  --language python \
  --profile minimal
```

3. Запустить strict-режим (если нужен GitHub process):

```bash
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/project \
  --mode strict \
  --agent codex \
  --language swift \
  --profile students \
  --github-repo owner/repo
```

### Что сделать после bootstrap

В target-проекте:

1. Пройти `docs/ai/global-personalization.md`.
2. Создать `docs/ai/global-personalization.done`.
3. Перед каждым commit запускать:

```bash
bash scripts/commit-ready.sh
```

4. Периодически запускать:

```bash
bash scripts/project-readiness-check.sh
```

Важно: `--no-serena` допустим для bootstrap, но readiness останется `FAIL`, пока Serena MCP не настроена.

### Ключевые скрипты

В этом репозитории:

- `playbook/scripts/bootstrap.sh` — сборка шаблона в новый проект;
- `playbook/scripts/validate-playbook.sh` — self-check шаблона;
- `playbook/scripts/install-serena-mcp.sh` — установка Serena и MCP регистрация;
- `playbook/curation/check-profile.sh` — проверка skill-профилей.

В сгенерированном target-проекте:

- `scripts/commit-ready.sh` — локальный pre-commit quality/security/DoD gate;
- `scripts/project-readiness-check.sh` — проверка проекта на “боевую готовность”.

### Структура

```text
playbook/
├─ core/
│  ├─ AGENTS.md
│  ├─ Flow.md
│  ├─ templates/
│  └─ governance/
│     ├─ files/        # strict pack
│     └─ solo/files/   # solo pack
├─ adapters/
│  ├─ agents/
│  └─ languages/
├─ curation/
└─ scripts/
```

---

## English

### What this is

`Sandbox` is a universal template repository for starting new projects with a serious AI workflow.  
It focuses on process quality, not on a specific tech stack.

It provides:

- a universal core flow (`Plan -> Context -> Implement -> Verify -> Report`);
- Serena-first context and memory discipline;
- reusable quality/security/DoD gates;
- a default solo workflow (`main + commits`);
- an opt-in strict GitHub governance mode.

Source of truth: `playbook/`.

### When to use it

- you are starting a new project and want a production-grade process baseline;
- you work solo but still want discipline and predictable quality;
- you need one template for multiple languages and AI assistants.

### Quick mode decision

| Scenario | Mode | Why |
|---|---|---|
| single developer, high velocity | `solo` (default) | low overhead, strong local gates |
| team workflow with review/process controls | `strict` | PR templates, workflows, protection checks |

### Quick start

1. Validate template:

```bash
./playbook/scripts/validate-playbook.sh --smoke
```

2. Bootstrap a new project (default solo mode):

```bash
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/project \
  --agent codex \
  --language python \
  --profile minimal
```

3. Strict mode (GitHub discipline):

```bash
./playbook/scripts/bootstrap.sh \
  --target /absolute/path/to/project \
  --mode strict \
  --agent codex \
  --language swift \
  --profile students \
  --github-repo owner/repo
```

### Post-bootstrap checklist

In the target project:

1. Complete `docs/ai/global-personalization.md`.
2. Create `docs/ai/global-personalization.done`.
3. Run before every commit:

```bash
bash scripts/commit-ready.sh
```

4. Run periodically:

```bash
bash scripts/project-readiness-check.sh
```

Note: `--no-serena` is allowed during bootstrap, but readiness remains `FAIL` until Serena MCP is configured.

### Main scripts

In this template repo:

- `playbook/scripts/bootstrap.sh`
- `playbook/scripts/validate-playbook.sh`
- `playbook/scripts/install-serena-mcp.sh`
- `playbook/curation/check-profile.sh`

In generated target projects:

- `scripts/commit-ready.sh`
- `scripts/project-readiness-check.sh`

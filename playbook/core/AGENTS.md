# AGENTS.md — Universal AI Playbook Core

## Mission

Ship reliable changes fast with clear scope, explicit verification, and minimal risk.

## Linked docs

- Execution flow: `./docs/ai/Flow.md`
- Plan template: `./docs/ai/templates/plan.md`
- Report template: `./docs/ai/templates/report.md`
- Serena workflow (when governance enabled): `./docs/ai/serena-workflow.md`
- Serena memory policy (when governance enabled): `./docs/ai/serena-memory-policy.md`

## Non-negotiables

1. Work in phases: Plan -> Context -> Implement -> Verify -> Report.
2. Change only relevant files.
3. Keep architecture boundaries intact.
4. Add or update tests when behavior changes.
5. Never claim checks were run if they were not.
6. Separate facts from assumptions.
7. Ask before risky or destructive actions.
8. Serena-first is mandatory for context discovery when Serena is available.
9. Manual codebase spelunking is fallback-only (use when Serena is unavailable or insufficient).

## Default task protocol

1. Restate goal in 1-2 sentences.
2. Briefly assess risk and scope.
3. Build a plan for non-trivial work.
4. Run Serena preflight: activate project, check onboarding, load relevant memories.
5. Implement in small, atomic steps.
6. Run relevant checks.
7. Record durable decisions in Serena memory.
8. Summarize with concrete results and remaining risks.

## Quality gates

- Code quality: consistent style and conventions.
- Verification: targeted checks first, broad checks if scope is wide.
- Architecture: no cross-layer shortcuts.
- Documentation: update only when behavior/contracts/workflow change.

## Communication rules

- Keep updates short and factual.
- On blockers, state:
  - done work;
  - blocker;
  - available options.
- Final response must include:
  - changed files;
  - verification commands and outcomes;
  - remaining risks.

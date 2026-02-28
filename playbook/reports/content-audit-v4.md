# Content Audit v4

Date: 2026-02-27

Scope: full repository file set (`README.md` + `playbook/**`, including hidden files).

Method:
- reviewed purpose and actual behavior for each file
- checked cross-file references and CLI/docs consistency
- flagged lazy patterns (`filler`, `copy-paste drift`, `dead reference`, `unused contract`)

Acceptance summary:
- dead references: 0
- stale CLI docs: 0
- contradictory rules: 0
- unresolved TODO placeholders in shipped templates: 0

Deep-review notes (high-impact files):
- `playbook/scripts/bootstrap.sh`: replaced state-machine with linear pipeline; verified new CLI and optional tooling fallback behavior.
- `playbook/scripts/install-serena-mcp.sh`: normalized return codes (0/1/2/3), added `verify` phase, removed legacy `--target`.
- `playbook/scripts/validate-playbook.sh`: migrated to v4.1 contracts, added optional-tooling and readiness warning/strict scenarios.
- `playbook/core/AGENTS.md` and `playbook/core/Flow.md`: removed hard Serena/Codex dependency; retained context-first fallback policy.
- `playbook/core/governance/*/scripts/project-readiness-check.sh`: switched to PASS/WARN/FAIL model with `--strict` escalation.
- `playbook/adapters/agents/antigravity/files/.agent/rules/10-native-workflow-interop.md`: added native workflow mapping without template duplication.
- `playbook/skills/core/*`: vendored baseline skill set audited for presence and structure (`SKILL.md` per skill).
- `README.md` and `playbook/setup.md`: aligned docs with actual CLI and runtime behavior (no legacy flags, no curation layer).

| File | Purpose clarity | Factual consistency | Ambiguity | Lazy flags | Rewrite action |
|---|---|---|---|---|---|
| `README.md` | clear | aligned | none | none | no |
| `playbook/adapters/agents/antigravity/README.md` | clear | aligned | none | none | no |
| `playbook/adapters/agents/antigravity/adapter.toml` | clear | aligned | none | none | no |
| `playbook/adapters/agents/antigravity/files/.agent/rules/00-core.md` | clear | aligned | none | none | no |
| `playbook/adapters/agents/antigravity/files/.agent/rules/10-native-workflow-interop.md` | clear | aligned | none | none | no |
| `playbook/adapters/agents/claude/README.md` | clear | aligned | none | none | no |
| `playbook/adapters/agents/claude/adapter.toml` | clear | aligned | none | none | no |
| `playbook/adapters/agents/claude/files/CLAUDE.md` | clear | aligned | none | none | no |
| `playbook/adapters/agents/codex/README.md` | clear | aligned | none | none | no |
| `playbook/adapters/agents/codex/adapter.toml` | clear | aligned | none | none | no |
| `playbook/adapters/agents/codex/files/.codex/rules/00-core.md` | clear | aligned | none | none | no |
| `playbook/adapters/agents/cursor/README.md` | clear | aligned | none | none | no |
| `playbook/adapters/agents/cursor/adapter.toml` | clear | aligned | none | none | no |
| `playbook/adapters/agents/cursor/files/.cursor/rules/00-core.mdc` | clear | aligned | none | none | no |
| `playbook/adapters/languages/_template/README.md` | clear | aligned | none | none | no |
| `playbook/adapters/languages/_template/adapter.toml` | clear | aligned | none | none | no |
| `playbook/adapters/languages/_template/files/docs/ai/adapters/language-template.md` | clear | aligned | none | none | no |
| `playbook/adapters/languages/_template/files/docs/ai/quality-gates.env` | clear | aligned | none | none | no |
| `playbook/adapters/languages/_template/files/docs/ai/security-gates.env` | clear | aligned | none | none | no |
| `playbook/adapters/languages/python/README.md` | clear | aligned | none | none | no |
| `playbook/adapters/languages/python/adapter.toml` | clear | aligned | none | none | no |
| `playbook/adapters/languages/python/files/docs/ai/adapters/language-python.md` | clear | aligned | none | none | no |
| `playbook/adapters/languages/python/files/docs/ai/quality-gates.env` | clear | aligned | none | none | no |
| `playbook/adapters/languages/python/files/docs/ai/security-gates.env` | clear | aligned | none | none | no |
| `playbook/adapters/languages/swift/README.md` | clear | aligned | none | none | no |
| `playbook/adapters/languages/swift/adapter.toml` | clear | aligned | none | none | no |
| `playbook/adapters/languages/swift/files/docs/ai/adapters/language-swift.md` | clear | aligned | none | none | no |
| `playbook/adapters/languages/swift/files/docs/ai/quality-gates.env` | clear | aligned | none | none | no |
| `playbook/adapters/languages/swift/files/docs/ai/security-gates.env` | clear | aligned | none | none | no |
| `playbook/adapters/tooling/serena/README.md` | clear | aligned | none | none | no |
| `playbook/adapters/tooling/serena/adapter.toml` | clear | aligned | none | none | no |
| `playbook/adapters/tooling/serena/files/.codex/rules/10-serena.mdc` | clear | aligned | none | none | no |
| `playbook/adapters/tooling/serena/files/docs/ai/adapters/serena.md` | clear | aligned | none | none | no |
| `playbook/core/AGENTS.md` | clear | aligned | none | none | no |
| `playbook/core/Flow.md` | clear | aligned | none | none | no |
| `playbook/core/governance/files/.github/CODEOWNERS` | clear | aligned | none | none | no |
| `playbook/core/governance/files/.github/PULL_REQUEST_TEMPLATE.md` | clear | aligned | none | none | no |
| `playbook/core/governance/files/.github/workflows/ci.yml` | clear | aligned | none | none | no |
| `playbook/core/governance/files/.github/workflows/release.yml` | clear | aligned | none | none | no |
| `playbook/core/governance/files/.github/workflows/security.yml` | clear | aligned | none | none | no |
| `playbook/core/governance/files/docs/ai/architecture/adr/ADR-TEMPLATE.md` | clear | aligned | none | none | no |
| `playbook/core/governance/files/docs/ai/context-memory-policy.md` | clear | aligned | none | none | no |
| `playbook/core/governance/files/docs/ai/context-workflow.md` | clear | aligned | none | none | no |
| `playbook/core/governance/files/docs/ai/definition-of-done.md` | clear | aligned | none | none | no |
| `playbook/core/governance/files/docs/ai/github-protection-checklist.md` | clear | aligned | none | none | no |
| `playbook/core/governance/files/docs/ai/quality-gates.env` | clear | aligned | none | none | no |
| `playbook/core/governance/files/docs/ai/release-checklist.md` | clear | aligned | none | none | no |
| `playbook/core/governance/files/docs/ai/rollback-plan.md` | clear | aligned | none | none | no |
| `playbook/core/governance/files/docs/ai/security-gates.env` | clear | aligned | none | none | no |
| `playbook/core/governance/files/scripts/commit-ready.sh` | clear | aligned | none | none | no |
| `playbook/core/governance/files/scripts/github/apply-branch-protection.sh` | clear | aligned | none | none | no |
| `playbook/core/governance/files/scripts/github/verify-branch-protection.sh` | clear | aligned | none | none | no |
| `playbook/core/governance/files/scripts/project-readiness-check.sh` | clear | aligned | none | none | no |
| `playbook/core/governance/files/scripts/run-dod-gate.sh` | clear | aligned | none | none | no |
| `playbook/core/governance/files/scripts/run-quality-gates.sh` | clear | aligned | none | none | no |
| `playbook/core/governance/files/scripts/run-security-gates.sh` | clear | aligned | none | none | no |
| `playbook/core/governance/solo/files/docs/ai/architecture/adr/ADR-TEMPLATE.md` | clear | aligned | none | none | no |
| `playbook/core/governance/solo/files/docs/ai/context-memory-policy.md` | clear | aligned | none | none | no |
| `playbook/core/governance/solo/files/docs/ai/context-workflow.md` | clear | aligned | none | none | no |
| `playbook/core/governance/solo/files/docs/ai/definition-of-done.md` | clear | aligned | none | none | no |
| `playbook/core/governance/solo/files/docs/ai/quality-gates.env` | clear | aligned | none | none | no |
| `playbook/core/governance/solo/files/docs/ai/release-checklist.md` | clear | aligned | none | none | no |
| `playbook/core/governance/solo/files/docs/ai/rollback-plan.md` | clear | aligned | none | none | no |
| `playbook/core/governance/solo/files/docs/ai/security-gates.env` | clear | aligned | none | none | no |
| `playbook/core/governance/solo/files/scripts/commit-ready.sh` | clear | aligned | none | none | no |
| `playbook/core/governance/solo/files/scripts/project-readiness-check.sh` | clear | aligned | none | none | no |
| `playbook/core/governance/solo/files/scripts/run-dod-gate.sh` | clear | aligned | none | none | no |
| `playbook/core/governance/solo/files/scripts/run-quality-gates.sh` | clear | aligned | none | none | no |
| `playbook/core/governance/solo/files/scripts/run-security-gates.sh` | clear | aligned | none | none | no |
| `playbook/core/templates/context-provider-guide.md` | clear | aligned | none | none | no |
| `playbook/core/templates/global-personalization.md` | clear | aligned | none | none | no |
| `playbook/core/templates/plan.md` | clear | aligned | none | none | no |
| `playbook/core/templates/report.md` | clear | aligned | none | none | no |
| `playbook/reports/content-audit-v4.md` | clear | aligned | none | none | no |
| `playbook/scripts/bootstrap.sh` | clear | aligned | none | none | no |
| `playbook/scripts/github/apply-branch-protection.sh` | clear | aligned | none | none | no |
| `playbook/scripts/github/verify-branch-protection.sh` | clear | aligned | none | none | no |
| `playbook/scripts/install-serena-mcp.sh` | clear | aligned | none | none | no |
| `playbook/scripts/skills/install-vendored-skills.sh` | clear | aligned | none | none | no |
| `playbook/scripts/skills/refresh-vendored-skills.sh` | clear | aligned | none | none | no |
| `playbook/scripts/validate-playbook.sh` | clear | aligned | none | none | no |
| `playbook/setup.md` | clear | aligned | none | none | no |
| `playbook/skills/NOTICE.md` | clear | aligned | none | none | no |
| `playbook/skills/core/api-design-principles/SKILL.md` | clear | aligned | none | none | no |
| `playbook/skills/core/architecture-decision-records/SKILL.md` | clear | aligned | none | none | no |
| `playbook/skills/core/clean-code/SKILL.md` | clear | aligned | none | none | no |
| `playbook/skills/core/code-review-ai-ai-review/SKILL.md` | clear | aligned | none | none | no |
| `playbook/skills/core/concise-planning/SKILL.md` | clear | aligned | none | none | no |
| `playbook/skills/core/context-window-management/SKILL.md` | clear | aligned | none | none | no |
| `playbook/skills/core/lint-and-validate/SKILL.md` | clear | aligned | none | none | no |
| `playbook/skills/core/systematic-debugging/SKILL.md` | clear | aligned | none | none | no |
| `playbook/skills/core/test-driven-development/SKILL.md` | clear | aligned | none | none | no |
| `playbook/skills/core/verification-before-completion/SKILL.md` | clear | aligned | none | none | no |
| `playbook/skills/core/workflow-patterns/SKILL.md` | clear | aligned | none | none | no |
| `playbook/skills/skills.lock.toml` | clear | aligned | none | none | no |

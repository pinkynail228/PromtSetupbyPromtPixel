# Definition Of Done (Solo)

Machine-checkable checklist. Every item marked `[MANDATORY]` is required.

- [ ] [MANDATORY] Quality gates passed (`scripts/run-quality-gates.sh`).
- [ ] [MANDATORY] Security gates passed (`scripts/run-security-gates.sh`).
- [ ] [MANDATORY] DoD gate passed (`scripts/run-dod-gate.sh`).
- [ ] [MANDATORY] Commit-ready passed before each commit (`scripts/commit-ready.sh`).
- [ ] [MANDATORY] Tests added or updated for behavior changes.
- [ ] [MANDATORY] Rollback steps documented in `docs/ai/rollback-plan.md`.
- [ ] [MANDATORY] Architecture impact assessed; ADR created when needed.
- [ ] [MANDATORY] Serena memory updated with decisions/checks/pitfalls.

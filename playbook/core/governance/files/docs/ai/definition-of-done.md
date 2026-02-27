# Definition Of Done

Machine-checkable checklist. Every item marked `[MANDATORY]` is required.

- [ ] [MANDATORY] Quality gates passed (`scripts/run-quality-gates.sh`).
- [ ] [MANDATORY] Security gates passed (`scripts/run-security-gates.sh`).
- [ ] [MANDATORY] DoD gate passed (`scripts/run-dod-gate.sh`).
- [ ] [MANDATORY] Tests added or updated for behavior changes.
- [ ] [MANDATORY] Rollback steps documented in `docs/ai/rollback-plan.md`.
- [ ] [MANDATORY] PR contains Goal, Serena Context Used, Risk, Test Plan, and Rollback Plan sections.
- [ ] [MANDATORY] Architecture impact assessed; ADR created when needed.
- [ ] [MANDATORY] Serena memory updated with decisions/checks/pitfalls.

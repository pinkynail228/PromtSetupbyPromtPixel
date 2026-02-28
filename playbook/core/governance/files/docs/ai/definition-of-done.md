# Definition Of Done (Strict)

Machine-checkable checklist. Every item marked `[MANDATORY]` is required.

- [ ] [MANDATORY] Quality gates passed (`scripts/run-quality-gates.sh`).
- [ ] [MANDATORY] Security gates passed (`scripts/run-security-gates.sh`).
- [ ] [MANDATORY] DoD gate passed (`scripts/run-dod-gate.sh`).
- [ ] [MANDATORY] Tests added or updated for behavior changes.
- [ ] [MANDATORY] Rollback steps documented in `docs/ai/rollback-plan.md`.
- [ ] [MANDATORY] PR contains Goal, Context Evidence Used, Risk, Test Plan, and Rollback Plan sections.
- [ ] [MANDATORY] Architecture impact assessed; ADR created when needed.
- [ ] Context records updated with decisions/checks/pitfalls.

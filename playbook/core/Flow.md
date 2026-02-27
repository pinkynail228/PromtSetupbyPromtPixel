# Flow.md — Universal Execution Flow

## Quick reference

Plan -> Context -> Implement -> Verify -> Report

## 1) Plan

1. Restate task and expected artifact.
2. Identify affected files/modules.
3. Choose minimal-change approach first.
4. For non-trivial work, fill `./templates/plan.md`.

## 2) Context

1. Collect only relevant project facts.
2. Distinguish facts from assumptions.
3. Resolve ambiguities before implementation.
4. Serena-first preflight is required when Serena is available:
   - activate project;
   - check onboarding;
   - load relevant memories.
5. Manual search (`rg`, file scans, deep reads) is fallback-only when Serena is unavailable or insufficient.

## 3) Implement

1. Apply small, atomic changes.
2. Keep changes in task scope.
3. Avoid unnecessary dependency or structure changes.
4. Record durable decisions and conventions in Serena memory.

## 4) Verify

1. Run targeted checks first.
2. Run broader checks for cross-cutting changes.
3. Validate edge and failure scenarios.
4. Record actual results in `./templates/report.md`.

## 5) Report

1. Summarize outcome and status.
2. List changed files and why.
3. Include verification commands and outcomes.
4. List remaining risks and next steps.
5. Add Serena memory summary: changes, checks, pitfalls.

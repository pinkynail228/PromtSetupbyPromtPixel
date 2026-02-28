# Antigravity Native Workflow Interop

Respect Antigravity native phase model:
- `PLANNING`
- `EXECUTION`
- `VERIFICATION`

When native artifacts exist, prefer them over duplicate templates:
- `implementation_plan.md` for planning details
- `task.md` for scoped execution notes
- `walkthrough.md` for verification and outcomes

Interop mapping:
- Playbook plan intent -> native `implementation_plan.md`
- Playbook report intent -> native `walkthrough.md`
- Quality gates remain executable via `scripts/commit-ready.sh` and gate scripts

Do not force duplicate plan/report files when native Antigravity artifacts are present.

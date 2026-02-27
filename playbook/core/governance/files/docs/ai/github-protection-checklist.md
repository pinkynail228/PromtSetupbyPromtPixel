# GitHub Protection Checklist (Strict)

Required settings for `main`:

- [ ] Require pull request before merging.
- [ ] Require at least 1 approval.
- [ ] Dismiss stale approvals when new commits are pushed.
- [ ] Require status checks: `quality-gates`, `security-gates`, `dod-gate`.
- [ ] Block direct pushes to `main`.

Validation command:

```bash
bash scripts/github/verify-branch-protection.sh --repo <owner/repo>
```

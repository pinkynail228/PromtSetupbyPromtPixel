# Curated Skill Profiles

Purpose: keep a safe, predictable subset of skills while using on-demand installation.

## Profiles

- `students-core.txt`: conservative baseline for guided work.
- `pro-core.txt`: broader engineering workflow set.

## Quick start

```bash
# Validate profile entries against a local skills install
./playbook/curation/check-profile.sh students-core --skills-root ~/.agent/skills
./playbook/curation/check-profile.sh pro-core --skills-root ~/.agent/skills
```

## Policy

1. Start with `students-core` unless advanced scope is explicitly needed.
2. Use skills outside the selected profile only with explicit user approval.
3. Do not use offensive/pentest skills without explicit written approval.

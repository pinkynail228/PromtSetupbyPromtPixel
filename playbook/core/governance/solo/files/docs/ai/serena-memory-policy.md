# Serena Memory Policy

## Intent

Minimize repeated token spend on rediscovery by storing durable context in Serena.

## Must capture

- Durable conventions (naming, architecture boundaries, review rules).
- Decisions that affect future tasks.
- Common pitfalls and mitigation patterns.
- Verification outcomes that future tasks depend on.

## Must avoid

- Sensitive secrets or credentials.
- Temporary scratch notes that are no longer useful.
- Duplicated verbose logs.

## Context loading rule

Before broad manual repository reading, query Serena memories first.
Manual deep-read is allowed only if Serena is unavailable or memory is insufficient.

## Entry format

- Context: where and why.
- Decision: what was chosen.
- Evidence: checks, links, artifacts.
- Follow-up: unresolved risks or TODOs.

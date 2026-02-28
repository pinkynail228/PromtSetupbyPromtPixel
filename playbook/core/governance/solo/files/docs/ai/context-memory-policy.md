# Context Memory Policy

## Intent

Reduce repeated context discovery by storing durable engineering knowledge.

## Must capture

- Conventions (naming, architecture boundaries, review rules).
- Decisions affecting future work.
- Common pitfalls and mitigation patterns.
- Verification outcomes that future tasks depend on.

## Must avoid

- Secrets or credentials.
- Temporary scratch notes with no reuse value.
- Verbose duplicated logs.

## Loading rule

Before broad manual repository reading, load existing context records first.
Manual deep reading is allowed when records are unavailable or insufficient.

## Entry format

- Context: where and why.
- Decision: what was chosen.
- Evidence: checks, links, artifacts.
- Follow-up: unresolved risks or TODO.

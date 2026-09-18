# Testing Patterns

> This repository contains no source code and therefore no tests.

## Core Sections (Required)

### 1) Test Stack and Commands

- Primary test framework: NONE (no unit-test framework)
- Assertion/mocking tools: NONE
- Verification commands:

```bash
make status                 # smoke-test both instances (scripts/smoke-test.sh)
make smoke target=local     # smoke-test one instance
make dev-smoke              # hit local :4000 + external :4001 in dev (Makefile)
```

### 2) Test Layout

- Test file placement pattern: N/A (no unit tests)
- Verification scripts: `scripts/smoke-test.sh` (bash + curl)
- Setup files and where they run: N/A

### 3) Test Scope Matrix

| Scope | Covered? | Typical target | Notes |
|-------|----------|----------------|-------|
| Unit | no | N/A | no source code |
| Integration | partial | proxy ↔ upstreams | `scripts/smoke-test.sh` hits `/v1/chat/completions` per instance |
| E2E | partial | client → proxy → model | `make dev-smoke` exercises both dev endpoints |

### 4) Mocking and Isolation Strategy

- Main mocking approach: N/A (live upstreams are used)
- Isolation guarantees: N/A
- Common failure mode in tests: upstream model server down → smoke test reports non-2xx

### 5) Coverage and Quality Signals

- Coverage tool + threshold: N/A
- Current reported coverage: N/A
- Known gaps/flaky areas: no automated verification that every `model_list` entry resolves to a live upstream (smoke test uses one model, `SMOKE_MODEL`, default `llama3-70b`)

### 6) Evidence

- `scripts/smoke-test.sh`
- `Makefile` (`status`, `smoke`, `dev-smoke` targets)
- `docs/codebase/.codebase-scan.txt` ("No performance testing configs detected")

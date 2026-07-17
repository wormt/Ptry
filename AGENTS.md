# Ptry

Durable execution for PowerShell 7. Scriptblock steps with journaled state, retry, backoff, and optional OTel tracing.

## Commands

- **Test:** `just test` (Pester)
- **Lint:** `just lint` (PSScriptAnalyzer)
- **Check:** `just check` (lint + test)
- **Demo:** `just demo` (resume demo)
- **Dev shell:** `just dev` (`nix develop`)

## Dev

- Enter devshell with `nix develop` (pwsh + just on PATH)
- Or run individual targets directly: `nix run .#test`, `nix run .#lint`
- PsLogger is an optional dependency. Tests run without it; tracing falls back to logging.

## Directory Structure

- Public functions: `Public/`
- Private helpers: `Private/`
- Module manifest: `Ptry.psd1`, entry point: `Ptry.psm1`
- Tests: `tests/Unit/`
- Examples: `examples/`

## Code Guidelines

- Tab indentation, size 1.
- PascalCase with noun: `New-Step`, `Invoke-Workflow`, `Read-Journal`.
- Dot-source into `Ptry.psm1` (no separate function exports).
- Classes and enum defined in `Ptry.psm1`: `PtryStep`, `PtryRecord`, `PtryStatus`.
- Module-scoped variables prefixed `$Script:` for env-driven defaults.
- Private functions prefixed `Ptry` (e.g. `Write-PtryLog`, `Test-PtryStepComplete`).
- No verbose comments. Code reads itself.
- Pipeline-friendly: public functions support `-ValueFromPipeline`.
- Idioms: `Where-Object`, `Select-Object`, pipeline left filtering. No LINQ or `.Where()`.

## Testing

- Pester 6, tests in `tests/Unit/`.
- Use `Should-*` assertions (dash, no space): `Should-Be`, `Should-BeString`, `Should-Throw`, `Should-BeNull`.
- Use `InModuleScope -ModuleName $module.Name` to access private functions.
- Always pass explicit `-JournalPath` to a temp file; never touch the default journal.
- Always pass `-WorkflowId` to isolate test runs.
- Always pass `-Force` to bypass resume checks.
- Clean up temp journal files after tests.
- Test public API, not implementation details.
- Prefer `Should-Throw` with scriptblocks over capturing exceptions.
- Use `Mock` / `Should-Invoke` for mocking in Pester 6.
- Discovery and run happen per file in Pester 6.

## Journal

- Append-only JSONL at `ptry.journal.jsonl` (or `$env:PTRY_JOURNAL_PATH`).
- One line per record. Lines are JSON objects with `ConvertTo-Json -Compress`.
- Mutex-protected writes for parallel safety.
- `Read-Journal` parses and filters; `Test-PtryStepComplete` checks for last Ok record.
- Round-trip invariant: `FromJsonl(ToJsonl($record))` preserves all fields.

## Retry

- Config priority: explicit param > step property (if non-zero) > module default.
- `MaxAttempts` caps retries. `BackoffMs` sets base delay.
- Exponential: `BaseMs * 2^(attempt-1)`. First retry uses base delay.
- `ErrorsToNotRetry` uses substring match (`-like "*pattern*"`).

## Tracing

- If PsLogger commands exist, each attempt wraps in a span.
- `TraceId` and `SpanId` recorded in journal when span is active.
- Absent PsLogger: no-op, empty strings in journal.
- Span failures never break execution (caught and logged at Debug).

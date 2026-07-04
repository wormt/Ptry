# Ptry

Mini durable execution for PowerShell 7. Iterate scriptblock steps with journaled stateful execution. 

You can even can parallelize SAFELY with a mutex! You can even auto instrument traces around steps!

Steps are equivalent to Temporal activities. Workflows are equivalent to Temporal workflows.

If [PsLogger](https://github.com/wormt/PsLogger) is available, each attempt is wrapped
in a span and its TraceId/SpanId are recorded in the journal.
If PsLogger is absent, Ptry falls back to plain logging.

`Invoke-Workflow -Parallel` uses `ForEach-Object -Parallel`. steps must be self-contained.

## Quickstart

```powershell
Import-Module ./Ptry.psd1

# define steps as a variable like so:
$steps = @(
    # self-contained: takes input via -Arguments, no captured variables
    New-Step -Name 'MyIP' -ScriptBlock { (iwr https://icanhazip.com).Content.Trim() }

    New-Step -Name 'RDAP' -ScriptBlock {
        param($ip)
        (iwr "https://rdap.ss/api/query?q=$ip" -ContentType application/json).Content |
            ConvertFrom-Json | Select -ExpandProperty data | Select -ExpandProperty rawData
    } -Arguments (iwr https://icanhazip.com).Content.Trim()

    New-Step -Name 'Whatever' -ScriptBlock { param($x) Write-Host $x } -Arguments 42 `
        -MaxAttempts 5 -BackoffMs 2000 -ExponentialBackoff
)

# A stable WorkflowId is what makes this work
$steps | Invoke-Workflow -WorkflowId 'nightly-2026-06-26'

# view state
Read-Journal journal.jsonl -Status Error
```

## Public Functions

| Function | Purpose |
|---|---|
| `New-Step` | Build a `PtryStep` (name, scriptblock, args, retry policy). |
| `Invoke-Step` | Run one step or skip with retry+backoff and journaling |
| `Invoke-Workflow` | Run a sequence of steps under a WorkflowId. |
| `Read-Journal` | Read the JSONL journal back as `PtryRecord`. |

Returned objects are the `PtryRecord` / `PtryStep` classes and can be piped to other things.

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `PTRY_JOURNAL_PATH` | `./ptry.journal.jsonl` | Journal file path. |
| `PTRY_WORKFLOW_ID` | *random* | WorkflowId that will be used in journaling. |
| `PTRY_MAX_ATTEMPTS` | `3` | Retry attempts per step. |
| `PTRY_BACKOFF_MS` | `3000` | Time to wait between retries. |
| `PTRY_EXPONENTIAL_BACKOFF` | `false` | True = `PTRY_BACKOFF_MS * 2^(x-1)`. |
| `PTRY_RESUME` | `true` | `false` disables skip checks. |
| `PTRY_EVENTLOG` / `PTRY_EVENTSOURCE` | *unset* | Enable Windows event-log fallback. |
| `PTRY_SERVICENAME` / `PTRY_ENVIRONMENT` / `PTRY_HOSTNAME` | `Ptry` / `development` / machine | Resource attributes. |

## Journal example

```json
{"timestamp":"…Z","workflow_id":"…","run_id":"…","step":"Publish","status":"Ok",
 "attempt":1,"duration_ms":42.0,"trace_id":"…","span_id":"…","output":"…","error":"…",
 "resource":{"service.name":"Ptry","deployment.environment":"development"}}
```

## dev

```sh
nix develop        # devshell with pwsh on PATH
nix run .#demo     # test
nix run .#lint     # PSScriptAnalyzer
```

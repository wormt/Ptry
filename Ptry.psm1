<#
.SYNOPSIS
	Ptry - "durable" execution. Iterate deterministic scriptblocks
	with a journaled state.
#>

enum PtryStatus {
	Pending
	Running
	Ok
	Error
	Skipped
}

class PtryStep {
	[ValidateNotNullOrEmpty()] [string] $Name
	[ValidateNotNull()]   [scriptblock] $ScriptBlock
	[object[]] $Arguments          = @()
	[int]      $MaxAttempts        = 0 # 0 = use module default at run time
	[int]      $BackoffMs          = 0 # 0 = use module default at run time
	[bool]     $ExponentialBackoff = $false
	[string[]] $ErrorsToNotRetry   = @()

	[string] ToString() {
		return "PtryStep:$($this.Name)"
	}
}

class PtryRecord {
	[datetime]    $Timestamp  = (Get-Date)
	[string]      $WorkflowId
	[string]      $RunId
	[string]      $StepName
	[PtryStatus]  $Status     = [PtryStatus]::Pending
	[int]         $Attempt    = 0
	[double]      $DurationMs = 0
	[string]      $TraceId
	[string]      $SpanId
	[string]      $Output
	[string]      $ErrorMessage
	[hashtable]   $Attributes

	[string] ToString() {
		return ("[{0}] [{1}] {2}/{3} (attempt {4}, {5}ms)" -f
			$this.Timestamp.ToString('o'), $this.Status, $this.WorkflowId,
			$this.StepName, $this.Attempt, [math]::Round($this.DurationMs))
	}

	# todo: MessagePack serialization would be faster but requires a C# library
	[string] ToJsonl() {
		$record = [ordered]@{
			timestamp   = $this.Timestamp.ToUniversalTime().ToString('o')
			workflow_id = $this.WorkflowId
			run_id      = $this.RunId
			step        = $this.StepName
			status      = $this.Status.ToString()
			attempt     = $this.Attempt
			duration_ms = $this.DurationMs
			trace_id    = $this.TraceId
			span_id     = $this.SpanId
			output      = $this.Output
			error       = $this.ErrorMessage
			resource    = $Script:ResourceAttributes
		}
		if ($this.Attributes) {
			$record.attributes = $this.Attributes
		}
		return ($record | ConvertTo-Json -Depth 10 -Compress)
	}

	static [PtryRecord] FromJsonl([string]$Line) {
		$parsed = $Line | ConvertFrom-Json
		return [PtryRecord]@{
			Timestamp    = [datetime]$parsed.timestamp
			WorkflowId   = $parsed.workflow_id
			RunId        = $parsed.run_id
			StepName     = $parsed.step
			Status       = [PtryStatus]$parsed.status
			Attempt      = [int]$parsed.attempt
			DurationMs   = [double]$parsed.duration_ms
			TraceId      = $parsed.trace_id
			SpanId       = $parsed.span_id
			Output       = $parsed.output
			ErrorMessage = $parsed.error
		}
	}
}

# for PSLogger; not consumed by Ptry itself
$Script:ResourceAttributes = @{
	'service.name'           = $env:PTRY_SERVICENAME ?? 'Ptry'
	'service.version'        = $env:PTRY_SERVICEVERSION ?? "$($MyInvocation.MyCommand.ScriptBlock.Module.Version)"
	'host.name'              = $env:PTRY_HOSTNAME ?? [System.Environment]::MachineName
	'deployment.environment' = $env:PTRY_ENVIRONMENT ?? 'development'
}

$Script:MaxAttempts        = [int]($env:PTRY_MAX_ATTEMPTS ?? 3)
$Script:BackoffMs          = [int]($env:PTRY_BACKOFF_MS ?? 3000) #3 seconds
$Script:ExponentialBackoff = ($env:PTRY_EXPONENTIAL_BACKOFF -eq 'true')
$Script:Resume             = (($env:PTRY_RESUME ?? 'true') -ne 'false')

$Script:WorkflowId         = $env:PTRY_WORKFLOW_ID # $null = random
$Script:EventLog           = $env:PTRY_EVENTLOG    # $null = no Windows event log
$Script:EventSource        = $env:PTRY_EVENTSOURCE

$Script:ModuleRoot         = $PSScriptRoot
$Script:ManifestPath       = Join-Path $PSScriptRoot 'Ptry.psd1'
$Script:JournalPath        = $env:PTRY_JOURNAL_PATH ?? (Join-Path $Script:ModuleRoot 'ptry.journal.jsonl')

try {
	Get-ChildItem "$(Split-Path -Parent $MyInvocation.MyCommand.Path)/Private/*.ps1" | ForEach-Object {. $_}
	Get-ChildItem "$(Split-Path -Parent $MyInvocation.MyCommand.Path)/Public/*.ps1"  | ForEach-Object {. $_}
}
catch {
	Write-Error -Message "Importing module Ptry failed: $($_.Exception.ToString())"
}

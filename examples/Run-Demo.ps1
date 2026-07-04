#Requires -Version 7.2
[CmdletBinding()]
param(
	[string]$WorkflowId = 'demo-fixed-workflow',
	[string]$JournalPath = (Join-Path ([System.IO.Path]::GetTempPath()) 'ptry.demo.jsonl')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../Ptry.psd1') -Force

if (Test-Path -LiteralPath $JournalPath) {
	Remove-Item -LiteralPath $JournalPath
}

$steps = @(
	New-Step -Name 'Greet' -ScriptBlock { param($who) "hello, $who" } -Arguments 'world'
	New-Step -Name 'Add'   -ScriptBlock { param($a, $b) $a + $b }     -Arguments 2, 40
	New-Step -Name 'Stamp' -ScriptBlock { 'stamped' }
)

Write-Information -MessageData "`nfirst run" -InformationAction Continue
$steps | Invoke-Workflow -WorkflowId $WorkflowId -JournalPath $JournalPath -InformationAction SilentlyContinue |
	Format-Table StepName, Status, Attempt, Output -AutoSize

Write-Information -MessageData "`nseocnd" -InformationAction Continue
$steps | Invoke-Workflow -WorkflowId $WorkflowId -JournalPath $JournalPath -InformationAction SilentlyContinue |
	Format-Table StepName, Status, Attempt, Output -AutoSize

Read-Journal -JournalPath $JournalPath | Format-Table Timestamp, StepName, Status, DurationMs -AutoSize

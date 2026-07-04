function Read-Journal {
	<#
	.SYNOPSIS
		Reads the append-only JSONL journal back into PtryRecord objects.
	#>
	[CmdletBinding()]
	[OutputType('PtryRecord')]   # string form: module class types don't resolve in scope
	param(
		[Parameter()] [string]$JournalPath = $Script:JournalPath,
		[Parameter()] [string]$WorkflowId,
		[Parameter()] [string]$StepName,
		# [string] so callers don't need 'using module'
		[Parameter()] [ValidateSet('Pending', 'Running', 'Ok', 'Error', 'Skipped')] [string]$Status
	)

	end {
		if (-not (Test-Path -LiteralPath $JournalPath)) {
			Write-PtryLog -Level Debug -Message "Journal '$JournalPath' does not exist yet."
			return
		}

		$hasStatus  = $PSBoundParameters.ContainsKey('Status')
		$wantStatus = if ($hasStatus) { [PtryStatus]$Status } else { $null }

		Get-Content -LiteralPath $JournalPath |
			Where-Object {
				$_ -and
				(-not $WorkflowId -or ($_ -match [regex]::Escape($WorkflowId))) -and
				(-not $StepName   -or ($_ -match [regex]::Escape($StepName)))
			} |
			ForEach-Object { [PtryRecord]::FromJsonl($_) } |
			Where-Object {
				(-not $WorkflowId -or $_.WorkflowId -eq $WorkflowId) -and
				(-not $StepName   -or $_.StepName -eq $StepName) -and
				(-not $hasStatus  -or $_.Status -eq $wantStatus)
			}
	}
}

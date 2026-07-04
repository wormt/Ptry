function Test-PtryStepComplete {
	<#
	.SYNOPSIS
		Returns the latest OK PtryRecord for a workflow or step if one exists, else $null.
		Used to skip already-completed steps on resume.
	#>
	[CmdletBinding()]
	[OutputType([PtryRecord])]
	param(
		[Parameter(Mandatory)] [string]$WorkflowId,
		[Parameter(Mandatory)] [string]$StepName,
		[Parameter(Mandatory)] [string]$JournalPath
	)

	if (-not (Test-Path -LiteralPath $JournalPath)) {
		return $null
	}

	$match =
	Get-Content -LiteralPath $JournalPath |
		Where-Object { $_ -and ($_ -match [regex]::Escape($WorkflowId)) -and ($_ -match [regex]::Escape($StepName)) } |
		ForEach-Object { [PtryRecord]::FromJsonl($_) } |
		Where-Object { $_.WorkflowId -eq $WorkflowId -and $_.StepName -eq $StepName -and $_.Status -eq [PtryStatus]::Ok } |
		Select-Object -Last 1

	return $match
}

function Start-PtryTrace {
	<#
	.SYNOPSIS
		Begins a span for a step by delegating to PsLogger. Returns the span object, or $null
		when PsLogger is absent.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'private function. who fucking cares')]
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)] [string]$Name,
		[Parameter(Mandatory)] [string]$WorkflowId,
		[Parameter(Mandatory)] [int]$Attempt
	)

	# only instrument if PsLogger's span verbs are available
	if (@(Get-Command -Name 'Start-Span', 'Set-Span', 'Stop-Span' -ErrorAction SilentlyContinue).Count -lt 3) {
		return $null
	}

	try {
		$span = Start-Span -Name $Name
		$tag = [System.Collections.Generic.KeyValuePair[string, object]]::new('ptry.workflow_id', $WorkflowId)
		$null = $span | Set-Span -Tag $tag
		$tag = [System.Collections.Generic.KeyValuePair[string, object]]::new('ptry.attempt', $Attempt)
		$null = $span | Set-Span -Tag $tag
		return $span
	}
	catch {
		Write-PtryLog -Level Debug -Message "Start-PtryTrace failed, continuing without a span: $($_.Exception.Message)"
		return $null
	}
}

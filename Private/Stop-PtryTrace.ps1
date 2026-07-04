function Stop-PtryTrace {
	<#
	.SYNOPSIS
		Closes a span opened by Start-PtryTrace.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'private function')]
	[CmdletBinding()]
	param(
		[Parameter(Mandatory, ValueFromPipeline)] [AllowNull()] [object]$Span,
		[Parameter()] [switch]$Succeeded
	)

	process {
		if ($null -eq $Span) {
			return
		}

		$statusCode = if ($Succeeded) {
			[System.Diagnostics.ActivityStatusCode]::Ok
		}
		else {
			[System.Diagnostics.ActivityStatusCode]::Error
		}

		try {
			$null = $Span | Set-Span -StatusCode $statusCode
			$null = $Span | Stop-Span
			$null = $Span | Send-Span
		}
		catch {
			Write-PtryLog -Level Debug -Message "Stop-PtryTrace span export failed: $($_.Exception.Message)"
		}
	}
}

function Write-PtryLog {
	<#
	.SYNOPSIS
		Fallback dumb logging
	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory, Position = 0)]
		[string]$Message,

		[Parameter()]
		[ValidateSet('Debug', 'Info', 'Warn', 'Error')]
		[string]$Level = 'Info'
	)

	$formatted = "[$((Get-Date).ToString('o'))] [$Level] $Message"

	switch ($Level) {
		'Debug' { Write-Verbose     -Message     $formatted }
		'Info'  { Write-Information -MessageData $formatted -InformationAction Continue }
		'Warn'  { Write-Warning     -Message     $formatted }
		'Error' { Write-Error       -Message     $formatted -ErrorAction Continue }
	}

	# only attempt the event log when an event log + source are configured
	if (-not ($Script:EventLog -and $Script:EventSource)) {
		return
	}

	$entryType = switch ($Level) {
		'Warn'  { 'Warning' }
		'Error' { 'Error' }
		default { 'Information' }
	}

	try {
		$logArgs = @{
			LogName   = $Script:EventLog
			Source    = $Script:EventSource
			EventId   = 1000
			EntryType = $entryType
			Message   = $formatted
		}
		Write-EventLog @logArgs
	}
	catch {
		# non-Windows or missing source: never let logging break the workflow
		Write-Verbose -Message "Event log write failed: $($_.Exception.ToString())"
	}
}

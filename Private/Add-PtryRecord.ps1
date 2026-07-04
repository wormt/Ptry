function Add-PtryRecord {
	<#
	.SYNOPSIS
		Appends a PtryRecord to the append-only JSONL journal. Uses a mutex so
		concurrent writers cannot interleave.
	#>
	[CmdletBinding(SupportsShouldProcess)]
	param(
		[Parameter(Mandatory, ValueFromPipeline)] [PtryRecord]$Record,
		[Parameter(Mandatory)]                    [string]$JournalPath
	)

	process {
		if (-not $PSCmdlet.ShouldProcess($JournalPath, "Append $($Record.StepName)")) {
			return
		}

		$directory = Split-Path -Parent $JournalPath
		if ($directory -and -not (Test-Path -LiteralPath $directory)) {
			$null = New-Item -ItemType Directory -Path $directory -Force
		}

		$mutexName = 'Ptry_' + (Split-Path -Leaf $JournalPath)
		$mutex     = [System.Threading.Mutex]::new($false, $mutexName)
		try {
			[void]$mutex.WaitOne()
			Add-Content -LiteralPath $JournalPath -Value $Record.ToJsonl() -Encoding utf8
		}
		finally {
			$mutex.ReleaseMutex()
			$mutex.Dispose()
		}
	}
}

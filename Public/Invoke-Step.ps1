function Invoke-Step {
	<#
	.SYNOPSIS
		Executes a PtryStep with retry, backoff, and journaling.
	#>
	[CmdletBinding(DefaultParameterSetName = 'ByObject', SupportsShouldProcess)]
	[OutputType('PtryRecord')]
	param(
		# [object] then convert to PtryStep
		[Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
		[object]$Step,

		[Parameter(Mandatory, Position = 0, ParameterSetName = 'ByProperty')]
		[string]$Name,

		[Parameter(Mandatory, Position = 1, ParameterSetName = 'ByProperty')]
		[scriptblock]$ScriptBlock,

		[Parameter(ParameterSetName = 'ByProperty')]
		[object[]]$Arguments = @(),

		[Parameter()] [string]$WorkflowId,
		[Parameter()] [string]$RunId = [guid]::NewGuid().Guid,
		[Parameter()] [string]$JournalPath = $Script:JournalPath,

		[Parameter()] [ValidateRange(1, [int]::MaxValue)] [int]$MaxAttempts,
		[Parameter()] [ValidateRange(0, [int]::MaxValue)] [int]$BackoffMs,
		[Parameter()] [switch]$ExponentialBackoff,
		[Parameter()] [string[]]$ErrorsToNotRetry,

		[Parameter()] [switch]$Force,
		[Parameter()] [switch]$NoTrace,
		[Parameter()] [switch]$IgnoreNonTerminatingErrors
	)

	process {
		if ($PSCmdlet.ParameterSetName -eq 'ByProperty') {
			$Step = New-Step -Name $Name -ScriptBlock $ScriptBlock -Arguments $Arguments
		}
		else {
			$Step = [PtryStep]$Step
		}

		# resolve settings: param override → step default → module default
		if ($PSBoundParameters.ContainsKey('MaxAttempts')) {
			$max = $MaxAttempts
		}
		elseif ($Step.MaxAttempts -ge 1) { $max = $Step.MaxAttempts }
		else { $max = $Script:MaxAttempts }

		$backoff = if ($PSBoundParameters.ContainsKey('BackoffMs')) { $BackoffMs } else { $Step.BackoffMs }

		$exp = if ($PSBoundParameters.ContainsKey('ExponentialBackoff')) {
			[bool]$ExponentialBackoff
		}
		else { $Step.ExponentialBackoff }

		$noRetryPatterns = if ($PSBoundParameters.ContainsKey('ErrorsToNotRetry')) {
			$ErrorsToNotRetry
		}
		else { $Step.ErrorsToNotRetry }

		if (-not $WorkflowId) {
			$WorkflowId = $Script:WorkflowId
			if (-not $WorkflowId) {
				$WorkflowId = [guid]::NewGuid().Guid
				Write-PtryLog -Level Warn -Message "No WorkflowId supplied; generated '$WorkflowId'. " +
			    "Resume across runs needs a stable WorkflowId."
			}
		}

		if ($Script:Resume -and -not $Force) {
			$prior = Test-PtryStepComplete -WorkflowId $WorkflowId -StepName $Step.Name -JournalPath $JournalPath
			if ($prior) {
				Write-PtryLog -Level Info -Message "Skipping '$($Step.Name)' (already OK in workflow '$WorkflowId')."
				return [PtryRecord]@{
					WorkflowId = $WorkflowId; RunId = $RunId; StepName = $Step.Name
					Status     = [PtryStatus]::Skipped; Attempt = $prior.Attempt
					Output     = $prior.Output; TraceId = $prior.TraceId; SpanId = $prior.SpanId
				}
			}
		}

		if (-not $PSCmdlet.ShouldProcess($Step.Name, 'Invoke Step')) {
			return
		}

		$attempt = 0
		while ($true) {
			$attempt++
			$start     = Get-Date
			$succeeded = $false
			$terminal  = $false
			$waitMs    = 0
			$lastError = $null
			if ($NoTrace) {
				$span = $null
			}
			else {
				$span = Start-PtryTrace -Name $Step.Name -WorkflowId $WorkflowId -Attempt $attempt
			}
			$traceId   = if ($span) { $span.TraceId.ToHexString() } else { '' }
			$spanId    = if ($span) { $span.SpanId.ToHexString() }  else { '' }

			try {
				$output = Invoke-Command -ScriptBlock $Step.ScriptBlock -ArgumentList $Step.Arguments -ErrorVariable stepErrors
				if ($stepErrors -and -not $IgnoreNonTerminatingErrors) {
					throw $stepErrors
				}

				$succeeded = $true
				$record = [PtryRecord]@{
					Timestamp  = $start; WorkflowId = $WorkflowId; RunId = $RunId; StepName = $Step.Name
					Status     = [PtryStatus]::Ok; Attempt = $attempt
					DurationMs = ((Get-Date) - $start).TotalMilliseconds
					TraceId    = $traceId; SpanId = $spanId
					Output     = ((@($output) -join ' ') -replace '\s+', ' ').Trim()
				}
				$record | Add-PtryRecord -JournalPath $JournalPath
				Write-PtryLog -Level Info -Message $record.ToString()
				return $record
			}
			catch {
				$lastError = $_
				$errorText = $_.Exception.ToString()
				$noRetry   = $false
				foreach ($pattern in $noRetryPatterns) {
					if ($errorText -like "*$pattern*") { $noRetry = $true; break }
				}

				if ($attempt -ge $max -or $noRetry) {
					$terminal = $true
					$record = [PtryRecord]@{
						Timestamp  = $start; WorkflowId = $WorkflowId; RunId = $RunId; StepName = $Step.Name
						Status     = [PtryStatus]::Error; Attempt = $attempt
						DurationMs   = ((Get-Date) - $start).TotalMilliseconds
						TraceId    = $traceId; SpanId = $spanId
						ErrorMessage = ($errorText -replace '\s+', ' ').Trim()
					}
					$record | Add-PtryRecord -JournalPath $JournalPath
					Write-PtryLog -Level Error -Message $record.ToString()
				}
				else {
					$waitMs = Get-PtryBackoffMs -Attempt $attempt -BaseMs $backoff -Exponential:$exp
					Write-PtryLog -Level Warn -Message "Step '$($Step.Name)' attempt $attempt/$max failed: $errorText"
				}
			}
			finally {
				$span | Stop-PtryTrace -Succeeded:$succeeded
			}

			if ($terminal) {
				throw $lastError
			}
			if ($waitMs -gt 0) {
				Write-PtryLog -Level Debug -Message "Waiting ${waitMs}ms before retry of '$($Step.Name)'."
				Start-Sleep -Milliseconds $waitMs
			}
		}
	}
}

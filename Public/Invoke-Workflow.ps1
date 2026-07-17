function Invoke-Workflow {
	<#
	.SYNOPSIS
		Runs a sequence of PtryStep objects under one WorkflowId. Completed steps are skipped
		on re-run by default. -Parallel fans out steps asynchronously
	.DESCRIPTION
		Pipe steps in or pass -Step. A $WorkflowId is what makes a re-run resume rather
		than repeat. Sequential workflows stop when there is a step error.
		-Parallel runs steps independently so steps must be self-contained.
	#>
	[CmdletBinding(SupportsShouldProcess)]
	[OutputType('PtryRecord')]
	param(
		# [object[]] so callers don't need to run `using`.
		[Parameter(Mandatory, ValueFromPipeline)]
		[object[]]$Step,

		[Parameter()] [string]$WorkflowId,
		[Parameter()] [string]$JournalPath = $Script:JournalPath,

		[Parameter()] [switch]$Parallel,
		[Parameter()] [ValidateRange(1, [int]::MaxValue)] [int]$ThrottleLimit = 5,

		[Parameter()] [switch]$Force
	)

	begin {
		$steps = [System.Collections.Generic.List[PtryStep]]::new()

		if (-not $WorkflowId) {
			$WorkflowId = $Script:WorkflowId
			if (-not $WorkflowId) {
				$WorkflowId = [guid]::NewGuid().Guid
				Write-PtryLog -Level Warn -Message "No WorkflowId supplied; generated '$WorkflowId'. " +
			    "Re-runs will NOT resume without a stable WorkflowId."
			}
		}
		$runId = [guid]::NewGuid().Guid
		Write-PtryLog -Level Info -Message "Workflow '$WorkflowId' run '$runId' starting."
	}

	process {
		foreach ($item in $Step) {
			$steps.Add($item)
		}
	}

	end {
		if (-not $PSCmdlet.ShouldProcess($WorkflowId, "Invoke Workflow ($($steps.Count) steps)")) {
			return
		}

		if ($Parallel) {
			$manifest = $Script:ManifestPath
			$steps | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
				Import-Module $using:manifest -Force
				$incoming = $_
				# scriptblocks are bound to their origin runspace; rebuild from text so it runs here
				$rehydrated = [scriptblock]::Create($incoming.ScriptBlock.ToString())
				$rebuilt = New-Step -Name $incoming.Name -ScriptBlock $rehydrated -Arguments $incoming.Arguments `
					-MaxAttempts $incoming.MaxAttempts -BackoffMs $incoming.BackoffMs `
					-ErrorsToNotRetry $incoming.ErrorsToNotRetry
				Invoke-Step -Step $rebuilt -WorkflowId $using:WorkflowId -RunId $using:runId `
					-JournalPath $using:JournalPath -Force:([bool]$using:Force)
			}
		}
		else {
			# a step throws and the workflow stops
			foreach ($current in $steps) {
				Invoke-Step -Step $current -WorkflowId $WorkflowId -RunId $runId -JournalPath $JournalPath -Force:$Force
			}
		}

		Write-PtryLog -Level Info -Message "Workflow '$WorkflowId' run '$runId' complete."
	}
}

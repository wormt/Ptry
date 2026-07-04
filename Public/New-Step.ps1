function New-Step {
	<#
	.SYNOPSIS
		Creates a PtryStep. scriptblock with an optional retry policy.
	.DESCRIPTION
		this should ideally be idempotent. you can configure retry if you want.
		resumed run a previously-completed step is skipped and its recorded output replayed.
		keep orchestration in the workflow.
	.EXAMPLE
		New-Step -Name 'LookupIP' -ScriptBlock {
			param($ip)
			(iwr "https://rdap.ss/api/query?q=$ip" -ContentType application/json).Content |
			    ConvertFrom-Json | Select -ExpandProperty data | Select -ExpandProperty rawData
		} -Arguments (iwr https://icanhazip.com).Content.Trim()
	#>
	[CmdletBinding(SupportsShouldProcess)]
	[OutputType('PtryStep')]   # string form: module class types don't resolve in caller scope
	param(
		[Parameter(Mandatory, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter(Mandatory, Position = 1)]
		[ValidateNotNull()]
		[scriptblock]$ScriptBlock,

		[Parameter()]
		[object[]]$Arguments = @(),

		[Parameter()]
		[ValidateRange(1, [int]::MaxValue)]
		[int]$MaxAttempts = $Script:MaxAttempts,

		[Parameter()]
		[ValidateRange(0, [int]::MaxValue)]
		[int]$BackoffMs = $Script:BackoffMs,

		[Parameter()]
		[switch]$ExponentialBackoff,

		[Parameter()]
		[string[]]$ErrorsToNotRetry = @()
	)

	process {
		if ($PSCmdlet.ShouldProcess($Name, 'New Step')) {
			return [PtryStep]@{
				Name               = $Name
				ScriptBlock        = $ScriptBlock
				Arguments          = $Arguments
				MaxAttempts        = $MaxAttempts
				BackoffMs          = $BackoffMs
				ExponentialBackoff = [bool]$ExponentialBackoff
				ErrorsToNotRetry   = $ErrorsToNotRetry
			}
		}
	}
}

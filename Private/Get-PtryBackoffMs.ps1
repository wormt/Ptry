function Get-PtryBackoffMs {
	<#
	.SYNOPSIS
		Gets the wait before the next attempt.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Ms = milliseconds unit, not a plural noun')]
	[CmdletBinding()]
	[OutputType([int])]
	param(
		[Parameter(Mandatory)] [ValidateRange(1, [int]::MaxValue)] [int]$Attempt,
		[Parameter(Mandatory)] [ValidateRange(0, [int]::MaxValue)] [int]$BaseMs,
		[Parameter()]          [switch]$Exponential
	)

	if ($Exponential) {
		return [int]($BaseMs * [math]::Pow(2, $Attempt - 1))
	}
	return $BaseMs
}

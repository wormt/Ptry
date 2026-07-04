@{
	RootModule        = 'Ptry.psm1'
	ModuleVersion     = '0.1.0'
	GUID              = '244ae066-1d7f-4984-b6ed-e62783800c70'
	Author            = 'wormt'
	Description       = 'durable execution. Iterate deterministic scriptblocks'
	PowerShellVersion = '7.2'
	FunctionsToExport = @('New-Step', 'Invoke-Step', 'Invoke-Workflow', 'Read-Journal')
}

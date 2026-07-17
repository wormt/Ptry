if (-not (Get-Module -ListAvailable -Name Pester)) {
	Write-Information -MessageData "Installing Pester into ./.psmodules ..." -InformationAction Continue
	New-Item -ItemType Directory -Force -Path ./.psmodules | Out-Null
	Save-Module -Name Pester -Path ./.psmodules -Repository PSGallery
}
Import-Module Pester
$config = New-PesterConfiguration
$config.Run.Path = $args[0]
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config

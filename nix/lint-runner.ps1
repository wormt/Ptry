if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
	Write-Information -MessageData "Installing PSScriptAnalyzer into ./.psmodules ..." -InformationAction Continue
	New-Item -ItemType Directory -Force -Path ./.psmodules | Out-Null
	Save-Module -Name PSScriptAnalyzer -Path ./.psmodules -Repository PSGallery
}
Import-Module PSScriptAnalyzer
$files = Get-ChildItem -Recurse -Include *.ps1,*.psm1,*.psd1 |
	Where-Object { $_.FullName -notmatch '[\\/]\.psmodules[\\/]' }
$findings = $files | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings ./PSScriptAnalyzerSettings.psd1 }
if ($findings) {
	$findings | Format-Table -AutoSize Severity, RuleName, ScriptName, Line, Message
}
if ($findings | Where-Object Severity -in 'Error', 'Warning') {
	Write-Error 'PSScriptAnalyzer found Error/Warning findings.'
	exit 1
}
Write-Information -MessageData 'PSScriptAnalyzer: clean.' -InformationAction Continue

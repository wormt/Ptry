[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'cross-scope test fixture')]
param()

$module = Import-Module './Ptry.psd1' -Force -PassThru
$global:journal = Join-Path ([System.IO.Path]::GetTempPath()) "ptry.test.$(Get-Random).jsonl"

InModuleScope -ModuleName $module.Name {
	Describe 'Invoke-Workflow' {
		It 'Executes steps in order and stops on error' {
			$steps = @(
				New-Step -Name 'One' -ScriptBlock { 'ok' } -MaxAttempts 1
				New-Step -Name 'Two' -ScriptBlock { throw 'fail' } -MaxAttempts 1
				New-Step -Name 'Three' -ScriptBlock { 'ok' } -MaxAttempts 1
			)

			{ $steps | Invoke-Workflow -WorkflowId 'test-seq-stop' -JournalPath $global:journal -Force } | Should-Throw

			$lines = Get-Content -LiteralPath $global:journal
			$lines.Count | Should-Be 2

			$records = $lines | ForEach-Object { $_ | ConvertFrom-Json }
			$records[0].step | Should-BeString 'One'
			$records[0].status | Should-BeString 'Ok'
			$records[1].step | Should-BeString 'Two'
			$records[1].status | Should-BeString 'Error'
		}
	}
}

if (Test-Path -LiteralPath $global:journal) { Remove-Item -LiteralPath $global:journal -Force }

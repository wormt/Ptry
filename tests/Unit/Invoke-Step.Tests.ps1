[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

$module = Import-Module './Ptry.psd1' -Force -PassThru
$global:journal = Join-Path ([System.IO.Path]::GetTempPath()) "ptry.step.$(Get-Random).jsonl"

InModuleScope -ModuleName $module.Name {
	BeforeAll {
		$Script:Resume = $false
	}

	Describe 'Invoke-Step' {
		Context 'Success' {
			It 'Returns Ok record on successful execution' {
				$step = New-Step -Name 'ok-step' -ScriptBlock { 'hello' } -MaxAttempts 1
				$record = Invoke-Step -Step $step -WorkflowId 'w1' -JournalPath $global:journal -NoTrace
				$record.Status.ToString() | Should-BeString 'Ok'
				$record.Attempt | Should-Be 1
				$record.Output | Should-BeString 'hello'
			}

			It 'Writes record to journal on success' {
				$lines = Get-Content -LiteralPath $global:journal
				$last = $lines | Select-Object -Last 1
				$last | ConvertFrom-Json | ForEach-Object {
					$_.step | Should-BeString 'ok-step'
					$_.status | Should-BeString 'Ok'
				}
			}

			It 'Passes arguments to scriptblock' {
				$step = New-Step -Name 'args-step' -ScriptBlock { param($a, $b) $a + $b } `
					-Arguments 3, 4 -MaxAttempts 1
				$record = Invoke-Step -Step $step -WorkflowId 'w2' -JournalPath $global:journal -NoTrace
				$record.Output | Should-BeString '7'
			}
		}

		Context 'Retry' {
			It 'Retries and succeeds on second attempt' {
				$count = 0
				$step = New-Step -Name 'retry-ok' -ScriptBlock {
					$script:count++
					if ($script:count -lt 2) { throw 'transient' }
					'recovered'
				} -MaxAttempts 3 -BackoffMs 0
				$record = Invoke-Step -Step $step -WorkflowId 'w3' -JournalPath $global:journal -NoTrace
				$record.Status.ToString() | Should-BeString 'Ok'
				$record.Attempt | Should-Be 2
				$record.Output | Should-BeString 'recovered'
			}

			It 'Fails after max attempts and throws' {
				$step = New-Step -Name 'always-fail' -ScriptBlock { throw 'boom' } -MaxAttempts 2 -BackoffMs 0
				{ Invoke-Step -Step $step -WorkflowId 'w4' -JournalPath $global:journal -NoTrace } | Should-Throw
			}

			It 'Records Error status in journal on terminal failure' {
				$lines = Get-Content -LiteralPath $global:journal
				$last = $lines | Select-Object -Last 1
				$last | ConvertFrom-Json | ForEach-Object {
					$_.step | Should-BeString 'always-fail'
					$_.status | Should-BeString 'Error'
					$_.attempt | Should-Be 2
				}
			}
		}

		Context 'ErrorsToNotRetry' {
			It 'Stops immediately when error matches a non-retry pattern' {
				$step = New-Step -Name 'no-retry' -ScriptBlock { throw 'NotFound: resource' } `
					-MaxAttempts 5 -BackoffMs 0 -ErrorsToNotRetry 'NotFound'
				{ Invoke-Step -Step $step -WorkflowId 'w5' -JournalPath $global:journal -NoTrace } | Should-Throw
				$lines = Get-Content -LiteralPath $global:journal
				$last = $lines | Select-Object -Last 1
				$last | ConvertFrom-Json | ForEach-Object {
					$_.attempt | Should-Be 1
					$_.status | Should-BeString 'Error'
				}
			}
		}

		Context 'IgnoreNonTerminatingErrors' {
			It 'Succeeds when flag ignores non-terminating errors' {
				$step = New-Step -Name 'non-term' -ScriptBlock {
					$null = Write-Error 'oops' -ErrorAction Continue
					'result'
				} -MaxAttempts 1
				$record = Invoke-Step -Step $step -WorkflowId 'w6' -JournalPath $global:journal `
					-NoTrace -IgnoreNonTerminatingErrors
				$record.Status.ToString() | Should-BeString 'Ok'
			}

			It 'Fails on non-terminating errors without flag' {
				$step = New-Step -Name 'non-term-fail' -ScriptBlock {
					$null = Write-Error 'oops' -ErrorAction Continue
					'result'
				} -MaxAttempts 1
				{ Invoke-Step -Step $step -WorkflowId 'w7' -JournalPath $global:journal -NoTrace } | Should-Throw
			}
		}

		Context 'Resume and Force' {
			It 'Skips step when prior Ok record exists and Resume is enabled' {
				$Script:Resume = $true
				$prior = [PtryRecord]@{
					Timestamp  = (Get-Date); WorkflowId = 'w-resume'; RunId = 'r'; StepName = 'skip-me'
					Status     = [PtryStatus]::Ok; Attempt = 1; DurationMs = 10; Output = 'cached'
				}
				$prior | Add-PtryRecord -JournalPath $global:journal
				$step = New-Step -Name 'skip-me' -ScriptBlock { 'should-not-run' } -MaxAttempts 1
				$record = Invoke-Step -Step $step -WorkflowId 'w-resume' -JournalPath $global:journal -NoTrace
				$record.Status.ToString() | Should-BeString 'Skipped'
				$record.Output | Should-BeString 'cached'
				$Script:Resume = $false
			}

			It 'Force bypasses resume check' {
				$Script:Resume = $true
				$step = New-Step -Name 'skip-me' -ScriptBlock { 'forced' } -MaxAttempts 1
				$record = Invoke-Step -Step $step -WorkflowId 'w-resume' -JournalPath $global:journal -NoTrace -Force
				$record.Status.ToString() | Should-BeString 'Ok'
				$record.Output | Should-BeString 'forced'
				$Script:Resume = $false
			}
		}

		Context 'Config priority' {
			It 'Uses step MaxAttempts over module default' {
				$step = New-Step -Name 'step-att' -ScriptBlock { throw 'x' } -MaxAttempts 1 -BackoffMs 0
				{ Invoke-Step -Step $step -WorkflowId 'w8' -JournalPath $global:journal -NoTrace } | Should-Throw
				$lines = Get-Content -LiteralPath $global:journal
				$last = $lines | Select-Object -Last 1
				$last | ConvertFrom-Json | ForEach-Object {
					$_.attempt | Should-Be 1
				}
			}

			It 'Param MaxAttempts overrides step value' {
				$step = New-Step -Name 'param-att' -ScriptBlock { throw 'x' } -MaxAttempts 5 -BackoffMs 0
				{ Invoke-Step -Step $step -WorkflowId 'w9' -JournalPath $global:journal -NoTrace -MaxAttempts 1 } | Should-Throw
				$lines = Get-Content -LiteralPath $global:journal
				$last = $lines | Select-Object -Last 1
				$last | ConvertFrom-Json | ForEach-Object {
					$_.attempt | Should-Be 1
				}
			}
		}
	}
}

if (Test-Path -LiteralPath $global:journal) { Remove-Item -LiteralPath $global:journal -Force }

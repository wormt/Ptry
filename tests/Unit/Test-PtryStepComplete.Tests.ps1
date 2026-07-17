[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

$module = Import-Module './Ptry.psd1' -Force -PassThru

function Global:Make-Journal {
	param([string]$Content = '')
	$path = Join-Path ([System.IO.Path]::GetTempPath()) "ptry.test.complete.$(Get-Random).jsonl"
	if ($Content) { Set-Content -LiteralPath $path -Value $Content -Encoding utf8 -NoNewline }
	$path
}

InModuleScope -ModuleName $module.Name {
	Describe 'Test-PtryStepComplete' {
		It 'Returns null when journal file does not exist' {
			$nonExistent = Join-Path ([System.IO.Path]::GetTempPath()) "ptry.no.exist.$(Get-Random).jsonl"
			Should-BeNull -Actual (Test-PtryStepComplete -WorkflowId 'any' -StepName 'any' -JournalPath $nonExistent)
		}

		It 'Returns null when journal is empty' {
			$journal = Make-Journal ''
			[io.file]::Create($journal).Close()
			Should-BeNull -Actual (Test-PtryStepComplete -WorkflowId 'w1' -StepName 's1' -JournalPath $journal)
			Remove-Item -LiteralPath $journal -Force -ErrorAction SilentlyContinue
		}

		It 'Returns null when no Ok record exists for workflow+step' {
			$record = [PtryRecord]@{
				Timestamp  = (Get-Date); WorkflowId = 'w1'; RunId = 'r1'; StepName = 's1'
				Status     = [PtryStatus]::Error; Attempt = 1; DurationMs = 10
			}
			$journal = Make-Journal $record.ToJsonl()
			Should-BeNull -Actual (Test-PtryStepComplete -WorkflowId 'w1' -StepName 's1' -JournalPath $journal)
			Remove-Item -LiteralPath $journal -Force
		}

		It 'Returns the Ok record when one exists' {
			$record = [PtryRecord]@{
				Timestamp  = (Get-Date); WorkflowId = 'w1'; RunId = 'r1'; StepName = 's1'
				Status     = [PtryStatus]::Ok; Attempt = 2; DurationMs = 45; Output = 'hello'
			}
			$journal = Make-Journal $record.ToJsonl()
			$result = Test-PtryStepComplete -WorkflowId 'w1' -StepName 's1' -JournalPath $journal
			Should-NotBeNull -Actual $result
			$result.Status.ToString() | Should-BeString 'Ok'
			$result.Attempt | Should-Be 2
			$result.Output | Should-BeString 'hello'
			Remove-Item -LiteralPath $journal -Force
		}

		It 'Returns the latest Ok record when multiple exist' {
			$r1 = [PtryRecord]@{
				Timestamp  = (Get-Date); WorkflowId = 'w1'; RunId = 'r1'; StepName = 's1'
				Status     = [PtryStatus]::Ok; Attempt = 1; DurationMs = 10; Output = 'old'
			}
			$r2 = [PtryRecord]@{
				Timestamp  = (Get-Date); WorkflowId = 'w1'; RunId = 'r2'; StepName = 's1'
				Status     = [PtryStatus]::Ok; Attempt = 3; DurationMs = 20; Output = 'new'
			}
			$journal = Make-Journal -Content ($r1.ToJsonl() + "`n" + $r2.ToJsonl())
			$result = Test-PtryStepComplete -WorkflowId 'w1' -StepName 's1' -JournalPath $journal
			Should-NotBeNull -Actual $result
			$result.Attempt | Should-Be 3
			$result.Output | Should-BeString 'new'
			Remove-Item -LiteralPath $journal -Force
		}

		It 'Ignores Ok records with different workflow id' {
			$record = [PtryRecord]@{
				Timestamp  = (Get-Date); WorkflowId = 'other'; RunId = 'r1'; StepName = 's1'
				Status     = [PtryStatus]::Ok; Attempt = 1; DurationMs = 10
			}
			$journal = Make-Journal $record.ToJsonl()
			Should-BeNull -Actual (Test-PtryStepComplete -WorkflowId 'w1' -StepName 's1' -JournalPath $journal)
			Remove-Item -LiteralPath $journal -Force
		}

		It 'Ignores Ok records with different step name' {
			$record = [PtryRecord]@{
				Timestamp  = (Get-Date); WorkflowId = 'w1'; RunId = 'r1'; StepName = 'other'
				Status     = [PtryStatus]::Ok; Attempt = 1; DurationMs = 10
			}
			$journal = Make-Journal $record.ToJsonl()
			Should-BeNull -Actual (Test-PtryStepComplete -WorkflowId 'w1' -StepName 's1' -JournalPath $journal)
			Remove-Item -LiteralPath $journal -Force
		}

		It 'Handles special characters in workflow id and step name' {
			$record = [PtryRecord]@{
				Timestamp  = (Get-Date); WorkflowId = 'w-1.0*?'; RunId = 'r1'; StepName = 's[1]'
				Status     = [PtryStatus]::Ok; Attempt = 1; DurationMs = 10; Output = 'ok'
			}
			$journal = Make-Journal $record.ToJsonl()
			$result = Test-PtryStepComplete -WorkflowId 'w-1.0*?' -StepName 's[1]' -JournalPath $journal
			Should-NotBeNull -Actual $result
			$result.Output | Should-BeString 'ok'
			Remove-Item -LiteralPath $journal -Force
		}
	}
}

Remove-Item -LiteralPath function:Global:Make-Journal -Force

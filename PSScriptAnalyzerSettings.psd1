@{
	IncludeDefaultRules = $true
	Severity            = @('Error', 'Warning', 'Information')

	Rules               = @{
		PSUseConsistentIndentation = @{
			Enable          = $true
			Kind            = 'tab'
			IndentationSize = 1
		}
		PSPlaceOpenBrace           = @{
			Enable     = $true
			OnSameLine = $true
		}
		PSAlignAssignmentStatement = @{
			Enable = $true
		}
	}
}

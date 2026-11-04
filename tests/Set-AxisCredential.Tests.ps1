Describe "Set-AxisCredential" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        InModuleScope AxisPowerShell {
            if(!(Get-Command New-StoredCredential -ErrorAction SilentlyContinue)) { function script:New-StoredCredential { Param($Target,$Persist,$Credentials) } }
        }
        $Global:NewCredential = New-Object System.Management.Automation.PSCredential ("root",(ConvertTo-SecureString -Force -AsPlainText "pass"))
    }

    BeforeEach {
        Mock @m New-StoredCredential { }
    }

    It "Sets the session credential without touching the vault" {
        Set-AxisCredential -Credential $NewCredential

        InModuleScope AxisPowerShell { $Config.Credential.UserName } | Should -Be "root"
        Should @m -Invoke "New-StoredCredential" -Times 0
    }

    It "Stores the credential under the AxisPowershell target with -StoreCredential" {
        Set-AxisCredential -Credential $NewCredential -StoreCredential

        Should @m -Invoke "New-StoredCredential" -ParameterFilter {
            $Target -eq "AxisPowershell" -and $Persist -eq "Enterprise" -and $Credentials.UserName -eq "root"
        } -Times 1 -Exactly
    }

    AfterAll {
        Remove-Variable NewCredential -Scope Global -ErrorAction SilentlyContinue
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

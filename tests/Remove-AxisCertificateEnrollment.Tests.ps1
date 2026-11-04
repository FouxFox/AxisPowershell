Describe "Remove-AxisCertificateEnrollment" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        $Global:EstBasePath = "/config/rest/cert-est/v1"
    }

    BeforeEach {
        Mock @m Write-Log { }
        Mock @m Get-AxisConfigApiPath { return $EstBasePath }
        Mock @m Invoke-AxisWebApi { return [pscustomobject]@{ status = "success" } }
    }

    It "Sends DELETE for the escaped profile id and logs it" {
        Remove-AxisCertificateEnrollment -Device "192.168.0.100" -ProfileId "EST Profile"

        Should @m -Invoke "Get-AxisConfigApiPath" -ParameterFilter { $API -eq "cert-est" } -Times 1 -Exactly
        Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter { $Path -eq "$EstBasePath/profiles/EST%20Profile" -and $Method -eq "DELETE" -and $Device -eq "192.168.0.100" } -Times 1 -Exactly
        Should @m -Invoke "Write-Log" -ParameterFilter { $ID -eq "192.168.0.100" -and $Message -like "*EST Profile*" } -Times 1 -Exactly
    }

    It "Supports -WhatIf" {
        Remove-AxisCertificateEnrollment -Device "192.168.0.100" -ProfileId "AxisPowershell" -WhatIf

        Should @m -Invoke "Invoke-AxisWebApi" -Times 0
        Should @m -Invoke "Write-Log" -Times 0
    }

    It "Propagates 'Command not supported' from Get-AxisConfigApiPath" {
        Mock @m Get-AxisConfigApiPath { Throw "Command not supported on this device" }

        { Remove-AxisCertificateEnrollment -Device "192.168.0.100" -ProfileId "AxisPowershell" } | Should -Throw "Command not supported on this device"
    }

    It "Throws on a device error status" {
        Mock @m Invoke-AxisWebApi { return [pscustomobject]@{ status = "error"; error = [pscustomobject]@{ message = "Profile not found" } } }

        { Remove-AxisCertificateEnrollment -Device "192.168.0.100" -ProfileId "Nope" } | Should -Throw "*Unable to delete EST profile 'Nope' on 192.168.0.100: Profile not found"
        Should @m -Invoke "Write-Log" -Times 0
    }

    It "Uses 'Unknown error' when the device gives no message" {
        Mock @m Invoke-AxisWebApi { return [pscustomobject]@{ status = "error" } }

        { Remove-AxisCertificateEnrollment -Device "192.168.0.100" -ProfileId "Nope" } | Should -Throw "*Unknown error"
    }

    It "Wraps transport errors" {
        Mock @m Invoke-AxisWebApi { Throw "500 Internal Server Error" }

        { Remove-AxisCertificateEnrollment -Device "192.168.0.100" -ProfileId "AxisPowershell" } | Should -Throw "*Unable to delete EST profile 'AxisPowershell' on 192.168.0.100*500*"
    }

    AfterAll {
        Remove-Variable EstBasePath -Scope Global -ErrorAction SilentlyContinue
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

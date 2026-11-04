Describe "Get-AxisCertificateEnrollment" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        $Global:EstBasePath = "/config/rest/cert-est/v1"
    }

    BeforeEach {
        Mock @m Get-AxisConfigApiPath { return $EstBasePath }
        Mock @m Invoke-AxisWebApi {
            return [pscustomobject]@{ status = "success"; data = @(
                [pscustomobject]@{ id = "AxisPowershell"; server = "pki.example.com:8443/.well-known/est/cameras"; caCertificates = @("EST-Root-CA"); certificate = "Axis device ID ECC-P256"; subject = [pscustomobject]@{ cn = "cam01.example.com" }; subjectAlternativeNames = @("DNS:cam01.example.com","DNS:cam01"); services = @("WEBSERVER"); status = "ENROLLED" }
                [pscustomobject]@{ id = "Second"; server = "est.example.com/.well-known/est/cams"; caCertificates = @(); certificate = "Other"; subject = [pscustomobject]@{ cn = "cam02" }; subjectAlternativeNames = @(); services = @("WEBSERVER","RTSPS"); status = "UNCONNECTED" }
            ) }
        }
    }

    It "Resolves the cert-est path and GETs the profiles collection" {
        $Result = @(Get-AxisCertificateEnrollment -Device "192.168.0.100")

        Should @m -Invoke "Get-AxisConfigApiPath" -ParameterFilter { $Device -eq "192.168.0.100" -and $API -eq "cert-est" } -Times 1 -Exactly
        Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter { $Path -eq "$EstBasePath/profiles" -and !$Method -and !$Body } -Times 1 -Exactly
        $Result.Count | Should -Be 2
    }

    It "Maps every profile field" {
        $Result = @(Get-AxisCertificateEnrollment -Device "192.168.0.100")

        $Result[0].Device | Should -Be "192.168.0.100"
        $Result[0].ProfileId | Should -Be "AxisPowershell"
        $Result[0].Server | Should -Be "pki.example.com:8443/.well-known/est/cameras"
        @($Result[0].CACertificates)[0] | Should -Be "EST-Root-CA"
        $Result[0].ClientCertificate | Should -Be "Axis device ID ECC-P256"
        $Result[0].CommonName | Should -Be "cam01.example.com"
        @($Result[0].SubjectAlternativeNames).Count | Should -Be 2
        @($Result[0].Services)[0] | Should -Be "WEBSERVER"
        $Result[0].Status | Should -Be "ENROLLED"
        @($Result[1].Services).Count | Should -Be 2
        @($Result[1].CACertificates).Count | Should -Be 0
        $Result[1].Status | Should -Be "UNCONNECTED"
    }

    It "Filters by -ProfileId" {
        $Result = @(Get-AxisCertificateEnrollment -Device "192.168.0.100" -ProfileId "Second")

        $Result.Count | Should -Be 1
        $Result[0].ProfileId | Should -Be "Second"
        @(Get-AxisCertificateEnrollment -Device "192.168.0.100" -ProfileId "Nope").Count | Should -Be 0
    }

    It "Returns nothing for an empty profile list" {
        Mock @m Invoke-AxisWebApi { return [pscustomobject]@{ status = "success"; data = @() } }

        @(Get-AxisCertificateEnrollment -Device "192.168.0.100").Count | Should -Be 0
    }

    It "Propagates 'Command not supported' from Get-AxisConfigApiPath" {
        Mock @m Get-AxisConfigApiPath { Throw "Command not supported on this device" }

        { Get-AxisCertificateEnrollment -Device "192.168.0.100" } | Should -Throw "Command not supported on this device"
        Should @m -Invoke "Invoke-AxisWebApi" -Times 0
    }

    It "Throws on a device error status" {
        Mock @m Invoke-AxisWebApi { return [pscustomobject]@{ status = "error"; error = [pscustomobject]@{ code = 1000; message = "Not allowed" } } }

        { Get-AxisCertificateEnrollment -Device "192.168.0.100" } | Should -Throw "*Unable to list EST profiles on 192.168.0.100: Not allowed"
    }

    It "Wraps transport errors" {
        Mock @m Invoke-AxisWebApi { Throw "401 Unauthorized" }

        { Get-AxisCertificateEnrollment -Device "192.168.0.100" } | Should -Throw "*Unable to list EST profiles on 192.168.0.100*401*"
    }

    AfterAll {
        Remove-Variable EstBasePath -Scope Global -ErrorAction SilentlyContinue
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

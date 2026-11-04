Describe "Submit-AxisCertificateRequest / Revoke-AxisIssuedCertificate" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        $Global:Issued = [pscustomobject]@{ Certificate = "-----BEGIN CERTIFICATE-----"; Chain = @(); Serial = "01AB"; RequestId = "7"; Status = "Issued" }
    }

    BeforeEach {
        Mock @m Submit-AxisCsrToWindowsCA { return $Issued }
        Mock @m Submit-AxisCsrToDogtag { return $Issued }
        Mock @m Submit-AxisCsrToEST { return $Issued }
        Mock @m Submit-AxisCsrToCommand { return $Issued }
        Mock @m Revoke-AxisCertificateOnWindowsCA { return $true }
        Mock @m Revoke-AxisCertificateOnDogtag { return $true }
        Mock @m Revoke-AxisCertificateOnEST { return $true }
        Mock @m Revoke-AxisCertificateOnCommand { return $true }
    }

    Context "Submit-AxisCertificateRequest" {
        It "Dispatches to the backend of each authority type" {
            ForEach($Type in "WindowsCA","Dogtag","EST","Command") {
                $Result = InModuleScope AxisPowerShell -Parameters @{ Type = $Type } { Submit-AxisCertificateRequest -Authority @{ Name = "A"; Type = $Type } -Csr "CSR" -Device "192.168.0.100" }
                $Result.Serial | Should -Be "01AB"
            }
            Should @m -Invoke "Submit-AxisCsrToWindowsCA" -ParameterFilter { $Authority.Type -eq "WindowsCA" -and $Csr -eq "CSR" -and $Device -eq "192.168.0.100" } -Times 1 -Exactly
            Should @m -Invoke "Submit-AxisCsrToDogtag" -Times 1 -Exactly
            Should @m -Invoke "Submit-AxisCsrToEST" -Times 1 -Exactly
            Should @m -Invoke "Submit-AxisCsrToCommand" -Times 1 -Exactly
        }

        It "Passes TimeoutSec only when given" {
            $null = InModuleScope AxisPowerShell { Submit-AxisCertificateRequest -Authority @{ Type = "EST" } -Csr "CSR" }
            Should @m -Invoke "Submit-AxisCsrToEST" -ParameterFilter { $null -eq $TimeoutSec -or $TimeoutSec -eq 0 } -Times 1 -Exactly

            $null = InModuleScope AxisPowerShell { Submit-AxisCertificateRequest -Authority @{ Type = "EST" } -Csr "CSR" -TimeoutSec 42 }
            Should @m -Invoke "Submit-AxisCsrToEST" -ParameterFilter { $TimeoutSec -eq 42 } -Times 1 -Exactly
        }

        It "Throws for an unknown authority type" {
            { InModuleScope AxisPowerShell { Submit-AxisCertificateRequest -Authority @{ Type = "Nope" } -Csr "CSR" } } | Should -Throw "Unsupported certificate authority type 'Nope'"
        }

        It "Propagates backend errors" {
            Mock @m Submit-AxisCsrToWindowsCA { Throw "Certificate request 7 is pending approval on CorpCA" }

            { InModuleScope AxisPowerShell { Submit-AxisCertificateRequest -Authority @{ Type = "WindowsCA" } -Csr "CSR" } } | Should -Throw "*pending approval*"
        }
    }

    Context "Revoke-AxisIssuedCertificate" {
        It "Dispatches to the backend with the default reason Superseded" {
            ForEach($Type in "WindowsCA","Dogtag","EST","Command") {
                InModuleScope AxisPowerShell -Parameters @{ Type = $Type } { Revoke-AxisIssuedCertificate -Authority @{ Type = $Type } -Serial "01AB" } | Should -BeTrue
            }
            Should @m -Invoke "Revoke-AxisCertificateOnWindowsCA" -ParameterFilter { $Serial -eq "01AB" -and $Reason -eq "Superseded" } -Times 1 -Exactly
            Should @m -Invoke "Revoke-AxisCertificateOnDogtag" -Times 1 -Exactly
            Should @m -Invoke "Revoke-AxisCertificateOnEST" -Times 1 -Exactly
            Should @m -Invoke "Revoke-AxisCertificateOnCommand" -Times 1 -Exactly
        }

        It "Passes an explicit reason and validates it" {
            $null = InModuleScope AxisPowerShell { Revoke-AxisIssuedCertificate -Authority @{ Type = "Dogtag" } -Serial "01AB" -Reason KeyCompromise }
            Should @m -Invoke "Revoke-AxisCertificateOnDogtag" -ParameterFilter { $Reason -eq "KeyCompromise" } -Times 1 -Exactly

            { InModuleScope AxisPowerShell { Revoke-AxisIssuedCertificate -Authority @{ Type = "Dogtag" } -Serial "01AB" -Reason Because } } | Should -Throw
        }

        It "Throws for an unknown authority type" {
            { InModuleScope AxisPowerShell { Revoke-AxisIssuedCertificate -Authority @{ Type = "Nope" } -Serial "01AB" } } | Should -Throw "Unsupported certificate authority type 'Nope'"
        }

        It "Propagates backend errors so callers decide" {
            Mock @m Revoke-AxisCertificateOnEST { Throw "EST has no revocation" }

            { InModuleScope AxisPowerShell { Revoke-AxisIssuedCertificate -Authority @{ Type = "EST" } -Serial "01AB" } } | Should -Throw "EST has no revocation"
        }
    }

    AfterAll {
        Remove-Variable Issued -Scope Global -ErrorAction SilentlyContinue
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

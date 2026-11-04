Describe "Get-AxisPSCertificateTemplate" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        InModuleScope AxisPowerShell {
            $Script:Config.Certificate = @{
                DefaultAuthority = "CorpCA"; SubjectTemplate = "CN={FQDN},O=Example"; SanTemplate = @("DNS:{FQDN}","DNS:{Hostname}")
                IncludeIP = $true; KeyType = "RSA-2048"; Keystore = "TPM0"; Alias = "Cam"; HttpsOnly = $false; RenewWithinDays = 14
            }
        }
    }

    It "Mirrors the Certificate section of the configuration" {
        $Result = Get-AxisPSCertificateTemplate

        $Result.DefaultAuthority | Should -Be "CorpCA"
        $Result.SubjectTemplate | Should -Be "CN={FQDN},O=Example"
        @($Result.SanTemplate).Count | Should -Be 2
        @($Result.SanTemplate)[1] | Should -Be "DNS:{Hostname}"
        $Result.IncludeIP | Should -BeTrue
        $Result.KeyType | Should -Be "RSA-2048"
        $Result.Keystore | Should -Be "TPM0"
        $Result.Alias | Should -Be "Cam"
        $Result.HttpsOnly | Should -BeFalse
        $Result.RenewWithinDays | Should -Be 14
        @($Result.PSObject.Properties).Count | Should -Be 9
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

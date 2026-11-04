Describe "Set-AxisPSCertificateTemplate" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
    }

    BeforeEach {
        InModuleScope AxisPowerShell {
            $Script:Config.CertificateAuthorities = @{ CorpCA = @{ Type = "WindowsCA" } }
            $Script:Config.Certificate = @{
                DefaultAuthority = $false; SubjectTemplate = "CN={FQDN}"; SanTemplate = @("DNS:{FQDN}")
                IncludeIP = $false; KeyType = "Auto"; Keystore = "Auto"; Alias = "AxisPowershell"; HttpsOnly = $true; RenewWithinDays = 30
            }
        }
        Mock @m Write-ModuleConfiguration { }
    }

    Context "Values" {
        It "Changes only the supplied settings and returns the template" {
            $Result = Set-AxisPSCertificateTemplate -SubjectTemplate "CN={FQDN},O=Example Inc" -KeyType RSA-2048 -Keystore TPM0 -Alias Cam -RenewWithinDays 14

            $Result.SubjectTemplate | Should -Be "CN={FQDN},O=Example Inc"
            $Result.KeyType | Should -Be "RSA-2048"
            $Result.Keystore | Should -Be "TPM0"
            $Result.Alias | Should -Be "Cam"
            $Result.RenewWithinDays | Should -Be 14
            $Result.HttpsOnly | Should -BeTrue
            $Result.IncludeIP | Should -BeFalse
            @($Result.SanTemplate)[0] | Should -Be "DNS:{FQDN}"
            Should @m -Invoke "Write-ModuleConfiguration" -Times 1 -Exactly
        }

        It "Sets the default authority only when it is configured" {
            (Set-AxisPSCertificateTemplate -DefaultAuthority CorpCA).DefaultAuthority | Should -Be "CorpCA"

            { Set-AxisPSCertificateTemplate -DefaultAuthority Nope } | Should -Throw "*'Nope' is not configured*"
            InModuleScope AxisPowerShell { $Config.Certificate.DefaultAuthority } | Should -Be "CorpCA"
        }

        It "Rejects unknown key types and keystores" {
            { Set-AxisPSCertificateTemplate -KeyType "DSA-1024" } | Should -Throw
            { Set-AxisPSCertificateTemplate -Keystore "USB0" } | Should -Throw
        }
    }

    Context "Subject validation" {
        It "Requires a CN component" {
            { Set-AxisPSCertificateTemplate -SubjectTemplate "O=Example" } | Should -Throw "*must contain a CN=*"
            Should @m -Invoke "Write-ModuleConfiguration" -Times 0
        }

        It "Accepts CN anywhere in the DN" {
            (Set-AxisPSCertificateTemplate -SubjectTemplate "O=Example, CN={Hostname}").SubjectTemplate | Should -Be "O=Example, CN={Hostname}"
        }

        It "Does not accept CN inside another attribute value" {
            { Set-AxisPSCertificateTemplate -SubjectTemplate "O=ACN=x" } | Should -Throw "*must contain a CN=*"
        }
    }

    Context "SAN template" {
        It "Replaces the whole SAN list" {
            $Result = Set-AxisPSCertificateTemplate -SanTemplate "DNS:{Hostname}","DNS:{Serial}.example.com"

            @($Result.SanTemplate).Count | Should -Be 2
            @($Result.SanTemplate)[0] | Should -Be "DNS:{Hostname}"
            @($Result.SanTemplate) | Should -Not -Contain "DNS:{FQDN}"
        }

        It "Stores a single entry as an array" {
            $null = Set-AxisPSCertificateTemplate -SanTemplate "DNS:{Hostname}"

            $Stored = InModuleScope AxisPowerShell { ,$Config.Certificate.SanTemplate }
            $Stored -is [Array] | Should -BeTrue
            @($Stored).Count | Should -Be 1
        }

        It "Clears the SAN list when an empty array is given" {
            $Result = Set-AxisPSCertificateTemplate -SanTemplate @()

            @($Result.SanTemplate).Count | Should -Be 0
        }
    }

    Context "Switches" {
        It "Toggles IncludeIP" {
            (Set-AxisPSCertificateTemplate -IncludeIP).IncludeIP | Should -BeTrue
            (Set-AxisPSCertificateTemplate -ExcludeIP).IncludeIP | Should -BeFalse
        }

        It "Toggles HttpsOnly and rejects both switches together" {
            (Set-AxisPSCertificateTemplate -DisableHttpsOnly).HttpsOnly | Should -BeFalse
            (Set-AxisPSCertificateTemplate -EnableHttpsOnly).HttpsOnly | Should -BeTrue
            { Set-AxisPSCertificateTemplate -EnableHttpsOnly -DisableHttpsOnly } | Should -Throw
        }
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

Describe "Resolve-AxisCertificateAuthority" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
    }

    BeforeEach {
        InModuleScope AxisPowerShell {
            $Script:Config.CertificateAuthorities = @{
                CorpCA = @{ Type = "WindowsCA"; Template = "AxisCamera"; CAConfig = "pki01.example.com\Example CA" }
                Dogtag = @{ Type = "Dogtag"; Server = "https://pki.example.com:8443" }
            }
            $Script:Config.Certificate = @{ DefaultAuthority = "Dogtag" }
        }
    }

    It "Returns a copy of the named authority with Name filled in" {
        $Result = InModuleScope AxisPowerShell { Resolve-AxisCertificateAuthority -Name CorpCA }

        $Result | Should -BeOfType [hashtable]
        $Result.Name | Should -Be "CorpCA"
        $Result.Type | Should -Be "WindowsCA"
        $Result.CAConfig | Should -Be "pki01.example.com\Example CA"
        $Result.Template | Should -Be "AxisCamera"
    }

    It "Does not modify the stored configuration" {
        InModuleScope AxisPowerShell { $A = Resolve-AxisCertificateAuthority -Name CorpCA; $A.Template = "Changed"; $A.Extra = 1 }

        InModuleScope AxisPowerShell { $Config.CertificateAuthorities.CorpCA.Template } | Should -Be "AxisCamera"
        InModuleScope AxisPowerShell { $Config.CertificateAuthorities.CorpCA.ContainsKey("Name") } | Should -BeFalse
        InModuleScope AxisPowerShell { $Config.CertificateAuthorities.CorpCA.ContainsKey("Extra") } | Should -BeFalse
    }

    It "Falls back to the default authority" {
        $Result = InModuleScope AxisPowerShell { Resolve-AxisCertificateAuthority }

        $Result.Name | Should -Be "Dogtag"
        $Result.Type | Should -Be "Dogtag"
    }

    It "Throws when no name is given and no default is set" {
        InModuleScope AxisPowerShell { $Script:Config.Certificate.DefaultAuthority = $false }

        { InModuleScope AxisPowerShell { Resolve-AxisCertificateAuthority } } | Should -Throw "*no default is set*"
    }

    It "Throws for an unknown authority" {
        { InModuleScope AxisPowerShell { Resolve-AxisCertificateAuthority -Name Nope } } | Should -Throw "*'Nope' is not configured*"
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

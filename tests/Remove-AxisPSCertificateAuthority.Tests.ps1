Describe "Remove-AxisPSCertificateAuthority" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        InModuleScope AxisPowerShell {
            if(!(Get-Command Remove-StoredCredential -ErrorAction SilentlyContinue)) { function script:Remove-StoredCredential { Param($Target) } }
        }
    }

    BeforeEach {
        InModuleScope AxisPowerShell {
            $Script:Config.CertificateAuthorities = @{
                Dogtag = @{ Type = "Dogtag"; Server = "https://pki.example.com:8443"; CredentialTarget = "AxisPowershell-CA-Dogtag"; RevokeCredentialTarget = "AxisPowershell-CA-Dogtag-Revoke" }
                WinCA = @{ Type = "WindowsCA"; CAConfig = "pki01.example.com\Example CA" }
            }
            $Script:Config.Certificate = @{ DefaultAuthority = "Dogtag" }
        }
        Mock @m Write-ModuleConfiguration { }
        Mock @m Remove-StoredCredential { }
    }

    It "Removes the authority, both stored credentials and clears the default" {
        Remove-AxisPSCertificateAuthority -Name Dogtag

        InModuleScope AxisPowerShell { $Config.CertificateAuthorities.ContainsKey("Dogtag") } | Should -BeFalse
        InModuleScope AxisPowerShell { $Config.CertificateAuthorities.ContainsKey("WinCA") } | Should -BeTrue
        InModuleScope AxisPowerShell { $Config.Certificate.DefaultAuthority } | Should -BeFalse
        Should @m -Invoke "Remove-StoredCredential" -ParameterFilter { $Target -eq "AxisPowershell-CA-Dogtag" } -Times 1 -Exactly
        Should @m -Invoke "Remove-StoredCredential" -ParameterFilter { $Target -eq "AxisPowershell-CA-Dogtag-Revoke" } -Times 1 -Exactly
        Should @m -Invoke "Write-ModuleConfiguration" -Times 1 -Exactly
    }

    It "Keeps the default when another authority is removed and skips the vault without targets" {
        Remove-AxisPSCertificateAuthority -Name WinCA

        InModuleScope AxisPowerShell { $Config.Certificate.DefaultAuthority } | Should -Be "Dogtag"
        Should @m -Invoke "Remove-StoredCredential" -Times 0
        Should @m -Invoke "Write-ModuleConfiguration" -Times 1 -Exactly
    }

    It "Tolerates a missing stored credential" {
        Mock @m Remove-StoredCredential { Throw "not found" }

        { Remove-AxisPSCertificateAuthority -Name Dogtag } | Should -Not -Throw
        InModuleScope AxisPowerShell { $Config.CertificateAuthorities.ContainsKey("Dogtag") } | Should -BeFalse
    }

    It "Throws for an unknown name without writing" {
        { Remove-AxisPSCertificateAuthority -Name Nope } | Should -Throw "*'Nope' is not configured*"
        Should @m -Invoke "Write-ModuleConfiguration" -Times 0
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

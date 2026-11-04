Describe "Get-AxisPSCertificateAuthority" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        InModuleScope AxisPowerShell {
            $Script:Config.CertificateAuthorities = @{
                WinCA = @{ Type = "WindowsCA"; Template = "AxisCamera"; CAConfig = "pki01.example.com\Example CA" }
                Dogtag = @{ Type = "Dogtag"; Template = "cameras"; Server = "https://pki.example.com:8443"; CredentialTarget = "AxisPowershell-CA-Dogtag" }
                Remote = @{ Type = "Command"; Template = "t"; SignCommand = "sign"; SshHost = "ca.example.com"; SshUser = "ca" }
                Local = @{ Type = "Command"; Template = "t"; SignCommand = "sign" }
            }
            $Script:Config.Certificate = @{ DefaultAuthority = "Dogtag" }
        }
    }

    It "Lists all authorities sorted by name with the default flagged" {
        $Result = @(Get-AxisPSCertificateAuthority)

        $Result.Count | Should -Be 4
        $Result[0].Name | Should -Be "Dogtag"
        $Result[3].Name | Should -Be "WinCA"
        ($Result | Where-Object { $_.Default }).Name | Should -Be "Dogtag"
    }

    It "Builds the endpoint per type" {
        (Get-AxisPSCertificateAuthority -Name WinCA).Endpoint | Should -Be "pki01.example.com\Example CA"
        (Get-AxisPSCertificateAuthority -Name Dogtag).Endpoint | Should -Be "https://pki.example.com:8443"
        (Get-AxisPSCertificateAuthority -Name Remote).Endpoint | Should -Be "ssh://ca@ca.example.com"
        (Get-AxisPSCertificateAuthority -Name Local).Endpoint | Should -Be "local"
    }

    It "Returns template and the raw settings" {
        $Result = Get-AxisPSCertificateAuthority -Name Dogtag

        $Result.Type | Should -Be "Dogtag"
        $Result.Template | Should -Be "cameras"
        $Result.Settings.CredentialTarget | Should -Be "AxisPowershell-CA-Dogtag"
    }

    It "Throws for an unknown name" {
        { Get-AxisPSCertificateAuthority -Name Nope } | Should -Throw "*'Nope' is not configured*"
    }

    It "Returns nothing when no authorities exist" {
        InModuleScope AxisPowerShell { $Script:Config.CertificateAuthorities = @{} }

        @(Get-AxisPSCertificateAuthority).Count | Should -Be 0
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

Describe "New-AxisCertificateAuthority" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        InModuleScope AxisPowerShell {
            if(!(Get-Command New-StoredCredential -ErrorAction SilentlyContinue)) { function script:New-StoredCredential { Param($Target,$Persist,$Credentials) } }
        }
        $Global:CaCredential = New-Object System.Management.Automation.PSCredential ("est-user",(ConvertTo-SecureString -Force -AsPlainText "Secret.123"))
        $Global:AgentCredential = New-Object System.Management.Automation.PSCredential ("agent",(ConvertTo-SecureString -Force -AsPlainText "Agent.456"))
    }

    BeforeEach {
        InModuleScope AxisPowerShell {
            $Script:Config.CertificateAuthorities = @{}
            $Script:Config.Certificate = @{ DefaultAuthority = $false }
        }
        Mock @m Write-ModuleConfiguration { }
        Mock @m New-StoredCredential { }
        Mock @m Test-AxisCertificateAuthorityWindowsCA { return [pscustomobject]@{ Reachable = $true; Message = "ok" } }
        Mock @m Test-AxisCertificateAuthorityDogtag { return [pscustomobject]@{ Reachable = $true; Message = "ok" } }
        Mock @m Test-AxisCertificateAuthorityEST { return [pscustomobject]@{ Reachable = $true; Message = "ok" } }
        Mock @m Test-AxisCertificateAuthorityCommand { return [pscustomobject]@{ Reachable = $true; Message = "ok" } }
    }

    Context "WindowsCA" {
        It "Stores CAConfig, template, poll interval and becomes the default when none is set" {
            $Result = New-AxisCertificateAuthority -Name CorpCA -Type WindowsCA -CAConfig "pki01.example.com\Example CA" -Template AxisCamera

            $Result.Name | Should -Be "CorpCA"
            $Result.Type | Should -Be "WindowsCA"
            $Result.Endpoint | Should -Be "pki01.example.com\Example CA"
            $Result.Default | Should -BeTrue
            InModuleScope AxisPowerShell { $Config.CertificateAuthorities.CorpCA.CAConfig } | Should -Be "pki01.example.com\Example CA"
            InModuleScope AxisPowerShell { $Config.CertificateAuthorities.CorpCA.PollSeconds } | Should -Be 5
            InModuleScope AxisPowerShell { $Config.CertificateAuthorities.CorpCA.TimeoutSec } | Should -Be 300
            InModuleScope AxisPowerShell { $Config.Certificate.DefaultAuthority } | Should -Be "CorpCA"
            Should @m -Invoke "Test-AxisCertificateAuthorityWindowsCA" -ParameterFilter { $Authority.Name -eq "CorpCA" -and $Authority.CAConfig } -Times 1 -Exactly
            Should @m -Invoke "Write-ModuleConfiguration" -Times 1 -Exactly
            Should @m -Invoke "New-StoredCredential" -Times 0
        }

        It "Requires -CAConfig" {
            { New-AxisCertificateAuthority -Name CorpCA -Type WindowsCA -Template AxisCamera } | Should -Throw "*-CAConfig*"
            Should @m -Invoke "Write-ModuleConfiguration" -Times 0
        }

        It "Stores the KeyTypes whitelist as an array" {
            $null = New-AxisCertificateAuthority -Name RsaCA -Type WindowsCA -CAConfig "pki01.example.com\Example CA" -Template Rsa -KeyTypes RSA-2048

            $Stored = InModuleScope AxisPowerShell { $Config.CertificateAuthorities.RsaCA.KeyTypes }
            @($Stored).Count | Should -Be 1
            @($Stored)[0] | Should -Be "RSA-2048"
        }
    }

    Context "Dogtag" {
        It "Stores server, label and credential targets; secrets go to the vault only" {
            $Result = New-AxisCertificateAuthority -Name Dogtag -Type Dogtag -Server "https://pki.example.com:8443/" -Template cameras -Credential $CaCredential -RevokeCredential $AgentCredential -CAThumbprint "AABB" -SkipCertificateCheck

            $Result.Endpoint | Should -Be "https://pki.example.com:8443"
            $Authority = InModuleScope AxisPowerShell { $Config.CertificateAuthorities.Dogtag }
            $Authority.Server | Should -Be "https://pki.example.com:8443"
            $Authority.Label | Should -Be "cameras"
            $Authority.CAThumbprint | Should -Be "AABB"
            $Authority.SkipCertificateCheck | Should -BeTrue
            $Authority.CredentialTarget | Should -Be "AxisPowershell-CA-Dogtag"
            $Authority.RevokeCredentialTarget | Should -Be "AxisPowershell-CA-Dogtag-Revoke"
            $Authority.Keys | Should -Not -Contain "Credential"
            $Authority.Keys | Should -Not -Contain "RevokeCredential"
            ($Authority | ConvertTo-Json -Depth 5) | Should -Not -Match "Secret.123"
            ($Authority | ConvertTo-Json -Depth 5) | Should -Not -Match "Agent.456"
            Should @m -Invoke "New-StoredCredential" -ParameterFilter { $Target -eq "AxisPowershell-CA-Dogtag" -and $Persist -eq "Enterprise" -and $Credentials.UserName -eq "est-user" } -Times 1 -Exactly
            Should @m -Invoke "New-StoredCredential" -ParameterFilter { $Target -eq "AxisPowershell-CA-Dogtag-Revoke" -and $Credentials.UserName -eq "agent" } -Times 1 -Exactly
            Should @m -Invoke "Test-AxisCertificateAuthorityDogtag" -Times 1 -Exactly
            Should @m -Invoke "Write-ModuleConfiguration" -Times 1 -Exactly
        }

        It "Requires -Server" {
            { New-AxisCertificateAuthority -Name Dogtag -Type Dogtag -Template cameras -Credential $CaCredential } | Should -Throw "*-Server*"
        }

        It "Requires -Credential or -ClientCertThumbprint" {
            { New-AxisCertificateAuthority -Name Dogtag -Type Dogtag -Server "https://pki.example.com:8443" -Template cameras } | Should -Throw "*-Credential or -ClientCertThumbprint*"
            Should @m -Invoke "New-StoredCredential" -Times 0
        }

        It "Accepts a client certificate thumbprint instead of a credential" {
            $null = New-AxisCertificateAuthority -Name Dogtag -Type Dogtag -Server "https://pki.example.com:8443" -Template cameras -ClientCertThumbprint "CCDD"

            InModuleScope AxisPowerShell { $Config.CertificateAuthorities.Dogtag.ClientCertThumbprint } | Should -Be "CCDD"
            InModuleScope AxisPowerShell { $Config.CertificateAuthorities.Dogtag.ContainsKey("CredentialTarget") } | Should -BeFalse
            Should @m -Invoke "New-StoredCredential" -Times 0
        }
    }

    Context "EST" {
        It "Accepts an empty label and keeps RevokeCommand" {
            $null = New-AxisCertificateAuthority -Name Est -Type EST -Server "https://est.example.com" -Template "" -Credential $CaCredential -RevokeCommand "revoke {Serial} {Reason}"

            $Authority = InModuleScope AxisPowerShell { $Config.CertificateAuthorities.Est }
            $Authority.Type | Should -Be "EST"
            $Authority.Label | Should -Be ""
            $Authority.RevokeCommand | Should -Be "revoke {Serial} {Reason}"
            $Authority.CredentialTarget | Should -Be "AxisPowershell-CA-Est"
            Should @m -Invoke "Test-AxisCertificateAuthorityEST" -Times 1 -Exactly
        }

        It "Does not keep RevokeCommand for Dogtag" {
            $null = New-AxisCertificateAuthority -Name Dogtag -Type Dogtag -Server "https://pki.example.com:8443" -Template cameras -Credential $CaCredential -RevokeCommand "x"

            InModuleScope AxisPowerShell { $Config.CertificateAuthorities.Dogtag.ContainsKey("RevokeCommand") } | Should -BeFalse
        }
    }

    Context "Command" {
        It "Stores the commands and SSH settings" {
            $null = New-AxisCertificateAuthority -Name LabCA -Type Command -Template server_cert -SignCommand "openssl ca -in {CsrFile} -out {CertFile}" -RevokeCommand "openssl ca -revoke {Serial}" -TestCommand "openssl version" -SshHost "ca.example.com" -SshUser ca -SshKeyFile "C:\keys\ca.key"

            $Authority = InModuleScope AxisPowerShell { $Config.CertificateAuthorities.LabCA }
            $Authority.SignCommand | Should -Be "openssl ca -in {CsrFile} -out {CertFile}"
            $Authority.RevokeCommand | Should -Be "openssl ca -revoke {Serial}"
            $Authority.TestCommand | Should -Be "openssl version"
            $Authority.SshHost | Should -Be "ca.example.com"
            $Authority.SshUser | Should -Be "ca"
            $Authority.SshKeyFile | Should -Be "C:\keys\ca.key"
            (Get-AxisPSCertificateAuthority -Name LabCA).Endpoint | Should -Be "ssh://ca@ca.example.com"
            Should @m -Invoke "Test-AxisCertificateAuthorityCommand" -Times 1 -Exactly
        }

        It "Ignores SSH user and key without -SshHost" {
            $null = New-AxisCertificateAuthority -Name LabCA -Type Command -Template t -SignCommand "sign" -SshUser ca -SshKeyFile "C:\keys\ca.key"

            $Authority = InModuleScope AxisPowerShell { $Config.CertificateAuthorities.LabCA }
            $Authority.ContainsKey("SshUser") | Should -BeFalse
            $Authority.ContainsKey("SshKeyFile") | Should -BeFalse
            (Get-AxisPSCertificateAuthority -Name LabCA).Endpoint | Should -Be "local"
        }

        It "Requires -SignCommand" {
            { New-AxisCertificateAuthority -Name LabCA -Type Command -Template t } | Should -Throw "*-SignCommand*"
        }
    }

    Context "Test and default handling" {
        It "Throws and does not save when the authority test fails" {
            Mock @m Test-AxisCertificateAuthorityWindowsCA { return [pscustomobject]@{ Reachable = $false; Message = "RPC server unavailable" } }

            { New-AxisCertificateAuthority -Name CorpCA -Type WindowsCA -CAConfig "pki01.example.com\Example CA" -Template AxisCamera } | Should -Throw "*RPC server unavailable*"

            InModuleScope AxisPowerShell { $Config.CertificateAuthorities.Count } | Should -Be 0
            Should @m -Invoke "Write-ModuleConfiguration" -Times 0
        }

        It "Skips the test with -SkipTest" {
            Mock @m Test-AxisCertificateAuthorityWindowsCA { return [pscustomobject]@{ Reachable = $false; Message = "nope" } }

            $null = New-AxisCertificateAuthority -Name CorpCA -Type WindowsCA -CAConfig "pki01.example.com\Example CA" -Template AxisCamera -SkipTest

            Should @m -Invoke "Test-AxisCertificateAuthorityWindowsCA" -Times 0
            Should @m -Invoke "Write-ModuleConfiguration" -Times 1 -Exactly
        }

        It "Does not pass the Name key into the stored authority" {
            $null = New-AxisCertificateAuthority -Name CorpCA -Type WindowsCA -CAConfig "pki01.example.com\Example CA" -Template AxisCamera

            InModuleScope AxisPowerShell { $Config.CertificateAuthorities.CorpCA.ContainsKey("Name") } | Should -BeFalse
        }

        It "Keeps the existing default unless -Default is given" {
            InModuleScope AxisPowerShell { $Script:Config.Certificate.DefaultAuthority = "Other" }

            $Result = New-AxisCertificateAuthority -Name CorpCA -Type WindowsCA -CAConfig "pki01.example.com\Example CA" -Template AxisCamera
            $Result.Default | Should -BeFalse
            InModuleScope AxisPowerShell { $Config.Certificate.DefaultAuthority } | Should -Be "Other"

            $Result = New-AxisCertificateAuthority -Name CorpCA -Type WindowsCA -CAConfig "pki01.example.com\Example CA" -Template AxisCamera -Default
            $Result.Default | Should -BeTrue
            InModuleScope AxisPowerShell { $Config.Certificate.DefaultAuthority } | Should -Be "CorpCA"
        }

        It "Replaces an existing authority of the same name" {
            InModuleScope AxisPowerShell { $Script:Config.CertificateAuthorities.CorpCA = @{ Type = "Command"; SignCommand = "old" } }

            $null = New-AxisCertificateAuthority -Name CorpCA -Type WindowsCA -CAConfig "pki01.example.com\Example CA" -Template AxisCamera

            InModuleScope AxisPowerShell { $Config.CertificateAuthorities.CorpCA.Type } | Should -Be "WindowsCA"
            InModuleScope AxisPowerShell { $Config.CertificateAuthorities.CorpCA.ContainsKey("SignCommand") } | Should -BeFalse
        }

        It "Rejects names with characters outside [A-Za-z0-9_-]" {
            { New-AxisCertificateAuthority -Name "Corp CA" -Type WindowsCA -CAConfig "x\y" -Template t } | Should -Throw
        }
    }

    AfterAll {
        Remove-Variable CaCredential, AgentCredential -Scope Global -ErrorAction SilentlyContinue
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

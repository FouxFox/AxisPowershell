Describe "Get-AxisCertificateSubject" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
    }

    BeforeEach {
        InModuleScope AxisPowerShell {
            $Script:Config.DNSSuffix = "example.com"
            $Script:Config.Certificate = @{ SubjectTemplate = "CN={FQDN}"; SanTemplate = @("DNS:{FQDN}"); IncludeIP = $false }
        }
        Mock @m Get-AxisDeviceInfo { return [pscustomobject]@{ ProdNbr = "P3719-PLE"; SerialNumber = "B8A44FB197BB"; Version = "11.7.61" } }
        Mock @m Get-AxisNetworkInfo { return [pscustomobject]@{ HostName = "axis-b8a44fb197bb"; IPAddress = "192.168.0.100"; DNSHostName = "axis-b8a44fb197bb.lab.example.net" } }
    }

    Context "Defaults" {
        It "Builds CN={FQDN} from hostname and configured DNS suffix; SAN mirrors the CN" {
            $Result = Get-AxisCertificateSubject -Device "192.168.0.100"

            $Result.Subject | Should -Be "CN=axis-b8a44fb197bb.example.com"
            @($Result.SubjectAltNames).Count | Should -Be 1
            @($Result.SubjectAltNames)[0] | Should -Be "DNS:axis-b8a44fb197bb.example.com"
        }

        It "Falls back to built-in templates when the configuration is empty" {
            InModuleScope AxisPowerShell { $Script:Config.Certificate = @{} }

            $Result = Get-AxisCertificateSubject -Device "192.168.0.100"

            $Result.Subject | Should -Be "CN=axis-b8a44fb197bb.example.com"
            @($Result.SubjectAltNames)[0] | Should -Be "DNS:axis-b8a44fb197bb.example.com"
        }

        It "Wraps device read failures" {
            Mock @m Get-AxisNetworkInfo { Throw "timeout" }

            { Get-AxisCertificateSubject -Device "192.168.0.100" } | Should -Throw "*Unable to read device information from 192.168.0.100*timeout*"
        }
    }

    Context "Tokens" {
        It "Resolves every token, lower-cases {Serial} and formats {MAC} with colons" {
            $Result = Get-AxisCertificateSubject -Device "192.168.0.100" -SubjectTemplate "CN={Hostname},OU={Serial},O={MAC},L={Model},ST={IP},C={DNSSuffix}"

            $Result.Subject | Should -Be "CN=axis-b8a44fb197bb,OU=b8a44fb197bb,O=B8:A4:4F:B1:97:BB,L=P3719-PLE,ST=192.168.0.100,C=example.com"
        }

        It "Matches tokens case-insensitively" {
            $Result = Get-AxisCertificateSubject -Device "192.168.0.100" -SubjectTemplate "CN=axis-{serial}.{dnssuffix}"

            $Result.Subject | Should -Be "CN=axis-b8a44fb197bb.example.com"
            @($Result.SubjectAltNames)[0] | Should -Be "DNS:axis-b8a44fb197bb.example.com"
        }

        It "Leaves a non-MAC serial number untouched in {MAC}" {
            Mock @m Get-AxisDeviceInfo { return [pscustomobject]@{ ProdNbr = "Q1234"; SerialNumber = "ACCC8E123456X"; Version = "11.7.61" } }

            $Result = Get-AxisCertificateSubject -Device "192.168.0.100" -SubjectTemplate "CN={MAC}"

            $Result.Subject | Should -Be "CN=accc8e123456x"
        }
    }

    Context "DNS suffix" {
        It "Strips a leading dot from the configured suffix" {
            InModuleScope AxisPowerShell { $Script:Config.DNSSuffix = ".example.com" }

            (Get-AxisCertificateSubject -Device "192.168.0.100").Subject | Should -Be "CN=axis-b8a44fb197bb.example.com"
        }

        It "Falls back to the device DNS name when no suffix is configured" {
            InModuleScope AxisPowerShell { $Script:Config.DNSSuffix = $false }

            (Get-AxisCertificateSubject -Device "192.168.0.100").Subject | Should -Be "CN=axis-b8a44fb197bb.lab.example.net"
        }

        It "Uses the bare hostname when neither suffix nor DNS name is known" {
            InModuleScope AxisPowerShell { $Script:Config.DNSSuffix = $false }
            Mock @m Get-AxisNetworkInfo { return [pscustomobject]@{ HostName = "cam01"; IPAddress = "192.168.0.100"; DNSHostName = "" } }

            (Get-AxisCertificateSubject -Device "192.168.0.100").Subject | Should -Be "CN=cam01"
        }

        It "Uses the device address when the device has no hostname" {
            Mock @m Get-AxisNetworkInfo { return [pscustomobject]@{ HostName = ""; IPAddress = "192.168.0.100"; DNSHostName = "" } }

            $Result = Get-AxisCertificateSubject -Device "192.168.0.100"

            $Result.Subject | Should -Be "CN=192.168.0.100"
            #An IP in the CN is not a DNS SAN and IP SANs are opt-in
            @($Result.SubjectAltNames).Count | Should -Be 0

            $Result = Get-AxisCertificateSubject -Device "192.168.0.100" -IncludeIP
            @($Result.SubjectAltNames).Count | Should -Be 1
            @($Result.SubjectAltNames)[0] | Should -Be "IP:192.168.0.100"
        }
    }

    Context "Subject alternative names" {
        It "Adds extra SAN templates and de-duplicates the CN entry" {
            $Result = Get-AxisCertificateSubject -Device "192.168.0.100" -SanTemplate "DNS:{FQDN}","DNS:{Hostname}","DNS:{Hostname}"

            @($Result.SubjectAltNames).Count | Should -Be 2
            @($Result.SubjectAltNames)[0] | Should -Be "DNS:axis-b8a44fb197bb.example.com"
            @($Result.SubjectAltNames)[1] | Should -Be "DNS:axis-b8a44fb197bb"
        }

        It "Skips SAN templates that resolve to something other than DNS: or IP:" {
            Mock @m Write-Verbose { }

            $Result = Get-AxisCertificateSubject -Device "192.168.0.100" -SanTemplate "DNS:{FQDN}","{Hostname}","email:x@example.com","DNS:"

            @($Result.SubjectAltNames).Count | Should -Be 1
        }

        It "Omits IP entries unless -IncludeIP is given" {
            $Result = Get-AxisCertificateSubject -Device "192.168.0.100" -SanTemplate "DNS:{FQDN}","IP:{IP}"
            @($Result.SubjectAltNames) | Should -Not -Contain "IP:192.168.0.100"

            $Result = Get-AxisCertificateSubject -Device "192.168.0.100" -SanTemplate "DNS:{FQDN}","IP:{IP}" -IncludeIP
            @($Result.SubjectAltNames).Count | Should -Be 2
            @($Result.SubjectAltNames)[1] | Should -Be "IP:192.168.0.100"
        }

        It "Appends the device IP once with -IncludeIP even without an IP template" {
            $Result = Get-AxisCertificateSubject -Device "192.168.0.100" -IncludeIP

            @($Result.SubjectAltNames).Count | Should -Be 2
            @($Result.SubjectAltNames)[1] | Should -Be "IP:192.168.0.100"
        }

        It "Takes IncludeIP from the configuration when not bound" {
            InModuleScope AxisPowerShell { $Script:Config.Certificate.IncludeIP = $true }

            $Result = Get-AxisCertificateSubject -Device "192.168.0.100"

            @($Result.SubjectAltNames) | Should -Contain "IP:192.168.0.100"
        }

        It "Puts an IP CN into the SAN as IP: when -IncludeIP is set" {
            $Result = Get-AxisCertificateSubject -Device "192.168.0.100" -SubjectTemplate "CN={IP}" -SanTemplate "IP:{IP}" -IncludeIP

            @($Result.SubjectAltNames).Count | Should -Be 1
            @($Result.SubjectAltNames)[0] | Should -Be "IP:192.168.0.100"
        }
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

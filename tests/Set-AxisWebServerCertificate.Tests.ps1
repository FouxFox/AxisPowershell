Describe "Set-AxisWebServerCertificate" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
    }

    BeforeEach {
        InModuleScope AxisPowerShell { $Script:Cache = @{ "192.168.0.100" = @{ Type = "http" } } }
        Mock @m Initialize-AxisCache { }
        Mock @m Get-AxisParameter { return @{ "HTTPS.Ciphers" = "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:"; "HTTPS.Enabled" = "yes" } }
        Mock @m Get-AxisDeviceInfo { return [pscustomobject]@{ Version = "11.7.61" } }
        #GetWebServerTlsConfiguration reports the current admin policy; everything else returns nothing
        Mock @m Invoke-AxisSoapRequest {
            if($Body -like "*GetWebServerTlsConfiguration*") {
                $Xml = [xml]'<Body><aweb:GetWebServerTlsConfigurationResponse xmlns:aweb="http://www.axis.com/vapix/ws/webserver"><aweb:Configuration><aweb:ConnectionPolicies><aweb:Admin>HttpAndHttps</aweb:Admin></aweb:ConnectionPolicies></aweb:Configuration></aweb:GetWebServerTlsConfigurationResponse></Body>'
                return $Xml.DocumentElement
            }
            return $null
        }
    }

    It "Reads the HTTPS group and mirrors its cipher list in the request" {
        InModuleScope AxisPowerShell { Set-AxisWebServerCertificate -Device "192.168.0.100" -Alias "AxisPowershell" }

        Should @m -Invoke "Get-AxisParameter" -ParameterFilter { $Device -eq "192.168.0.100" -and $Group -eq "HTTPS" } -Times 1 -Exactly
        Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter {
            $Device -eq "192.168.0.100" -and
            $Body -like "<aweb:SetWebServerTlsConfiguration*" -and
            $Body -like "*<Tls>true</Tls>*" -and
            $Body -like "*<acert:Cipher>ECDHE-ECDSA-AES128-GCM-SHA256</acert:Cipher>*" -and
            $Body -like "*<acert:Cipher>ECDHE-RSA-AES128-GCM-SHA256</acert:Cipher>*" -and
            ([regex]::Matches($Body, "<acert:Cipher>").Count -eq 2) -and
            $Body -like "*<acert:Id>AxisPowershell</acert:Id>*"
        } -Times 1 -Exactly
    }

    It "Sends only the Admin policy on AXIS OS 7.10 and later" {
        InModuleScope AxisPowerShell { Set-AxisWebServerCertificate -Device "192.168.0.100" -Alias "AxisPowershell" }

        Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter {
            $Body -like "*<aweb:Admin>HttpAndHttps</aweb:Admin>*" -and $Body -notlike "*<aweb:Operator>*" -and $Body -notlike "*<aweb:Viewer>*"
        } -Times 1 -Exactly
    }

    It "Sends Admin, Operator and Viewer policies on 6.50 firmware" {
        Mock @m Get-AxisDeviceInfo { return [pscustomobject]@{ Version = "6.50.5.2" } }

        InModuleScope AxisPowerShell { Set-AxisWebServerCertificate -Device "192.168.0.100" -Alias "AxisPowershell" -ConnectionPolicy "Https" }

        Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter {
            $Body -like "*<aweb:Admin>Https</aweb:Admin>*" -and $Body -like "*<aweb:Operator>Https</aweb:Operator>*" -and $Body -like "*<aweb:Viewer>Https</aweb:Viewer>*"
        } -Times 1 -Exactly
    }

    It "Treats exactly 7.10 as the new scheme" {
        Mock @m Get-AxisDeviceInfo { return [pscustomobject]@{ Version = "7.10.1" } }

        InModuleScope AxisPowerShell { Set-AxisWebServerCertificate -Device "192.168.0.100" -Alias "X" }

        Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter { $Body -like "*SetWebServerTlsConfiguration*" -and $Body -notlike "*<aweb:Operator>*" } -Times 1 -Exactly
    }

    It "Escapes the alias and produces a well-formed fragment" {
        InModuleScope AxisPowerShell { Set-AxisWebServerCertificate -Device "192.168.0.100" -Alias "A&B" }

        Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter {
            $Xml = [xml]"<r xmlns:aweb='urn:a' xmlns:acert='urn:b'>$Body</r>"
            $Body -like "*<acert:Id>A&amp;B</acert:Id>*" -and $null -ne $Xml
        } -Times 1 -Exactly
    }

    It "Switches the device cache to https afterwards" {
        InModuleScope AxisPowerShell { Set-AxisWebServerCertificate -Device "192.168.0.100" -Alias "X" }

        Should @m -Invoke "Initialize-AxisCache" -ParameterFilter { $Device -eq "192.168.0.100" } -Times 1 -Exactly
        InModuleScope AxisPowerShell { $Cache["192.168.0.100"].Type } | Should -Be "https"
    }

    It "Throws when HTTPS.Ciphers is missing" {
        Mock @m Get-AxisParameter { return @{ "HTTPS.Enabled" = "yes" } }

        { InModuleScope AxisPowerShell { Set-AxisWebServerCertificate -Device "192.168.0.100" -Alias "X" } } | Should -Throw "*did not return HTTPS.Ciphers*"
        Should @m -Invoke "Invoke-AxisSoapRequest" -Times 0
    }

    It "Wraps parameter read errors" {
        Mock @m Get-AxisParameter { Throw "401" }

        { InModuleScope AxisPowerShell { Set-AxisWebServerCertificate -Device "192.168.0.100" -Alias "X" } } | Should -Throw "*Unable to read HTTPS parameters from 192.168.0.100*401*"
    }

    It "Wraps SOAP faults and leaves the cache untouched" {
        Mock @m Invoke-AxisSoapRequest { Throw "SOAP Fault: InvalidCertificateConfigurationFault - (ter:InvalidArgVal)" }

        { InModuleScope AxisPowerShell { Set-AxisWebServerCertificate -Device "192.168.0.100" -Alias "X" } } | Should -Throw "*Unable to assign certificate 'X' to HTTPS on 192.168.0.100*InvalidCertificateConfigurationFault*"
        InModuleScope AxisPowerShell { $Cache["192.168.0.100"].Type } | Should -Be "http"
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

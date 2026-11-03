Describe "Get-AxisCertificate" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        #In-memory self-signed certificates (no key material leaves the process)
        $ECKey = [System.Security.Cryptography.ECDsa]::Create([System.Security.Cryptography.ECCurve]::CreateFromFriendlyName("nistP256"))
        $Req = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest("CN=cam01.example.com", $ECKey, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
        $Global:TestCert = $Req.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddYears(1))
        $Global:TestCertPem = "-----BEGIN CERTIFICATE-----`n$([Convert]::ToBase64String($TestCert.RawData))`n-----END CERTIFICATE-----"
        $Global:TestCertB64 = [Convert]::ToBase64String($TestCert.RawData)
    }

    Context "JSON API" {
        It "Lists certificates with parsed fields" {
            Mock @m Invoke-AxisCertApi { return @(
                [pscustomobject]@{ alias = "AxisPowershell"; certificate = $TestCertPem; keystore = "TPM0" }
                [pscustomobject]@{ alias = "Other"; certificate = $TestCertPem; keystore = "SOFTWARE0" }
            ) }
            Mock @m Invoke-AxisSoapRequest { Throw "should not be called" }

            $Result = @(Get-AxisCertificate -Device "192.168.0.100")

            $Result.Count | Should -Be 2
            $Result[0].Alias | Should -Be "AxisPowershell"
            $Result[0].Subject | Should -Be "CN=cam01.example.com"
            $Result[0].Thumbprint | Should -Be $TestCert.Thumbprint
            $Result[0].Serial | Should -Be $TestCert.SerialNumber.ToUpper()
            $Result[0].NotAfter | Should -Be $TestCert.NotAfter
            $Result[0].Keystore | Should -Be "TPM0"
            $Result[0].KeyType | Should -Be "NIST-P256"
            $Result[0].Source | Should -Be "REST"
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter { $Path -eq "/certificates" }
            Should @m -Invoke "Invoke-AxisSoapRequest" -Times 0
        }

        It "Filters by alias" {
            Mock @m Invoke-AxisCertApi { return @(
                [pscustomobject]@{ alias = "AxisPowershell"; certificate = $TestCertPem; keystore = "TPM0" }
                [pscustomobject]@{ alias = "Other"; certificate = $TestCertPem; keystore = "SOFTWARE0" }
            ) }

            $Result = @(Get-AxisCertificate -Device "192.168.0.100" -Alias "Other")

            $Result.Count | Should -Be 1
            $Result[0].Alias | Should -Be "Other"
        }

        It "Uses the ca_certificates collection with -CA" {
            Mock @m Invoke-AxisCertApi { return @([pscustomobject]@{ alias = "My-CA"; certificate = $TestCertPem }) }

            $Result = @(Get-AxisCertificate -Device "192.168.0.100" -CA)

            $Result[0].Alias | Should -Be "My-CA"
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter { $Path -eq "/ca_certificates" }
        }

        It "Throws on other API errors" {
            Mock @m Invoke-AxisCertApi { Throw "Certificate API error: boom" }

            { Get-AxisCertificate -Device "192.168.0.100" } | Should -Throw "*boom*"
        }
    }

    Context "SOAP fallback" {
        It "Falls back to tds:GetCertificates when the REST API is missing" {
            Mock @m Invoke-AxisCertApi { Throw "Command not supported on this device" }
            Mock @m Invoke-AxisSoapRequest {
                $Xml = [xml]@"
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://www.w3.org/2003/05/soap-envelope" xmlns:tds="http://www.onvif.org/ver10/device/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema">
<SOAP-ENV:Body><tds:GetCertificatesResponse>
<tds:NvtCertificate><tt:CertificateID>Legacy</tt:CertificateID><tt:Certificate><tt:Data>$TestCertB64</tt:Data></tt:Certificate></tds:NvtCertificate>
</tds:GetCertificatesResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
"@
                return $Xml.Envelope.Body
            }

            $Result = @(Get-AxisCertificate -Device "192.168.0.100")

            $Result.Count | Should -Be 1
            $Result[0].Alias | Should -Be "Legacy"
            $Result[0].Thumbprint | Should -Be $TestCert.Thumbprint
            $Result[0].Source | Should -Be "SOAP"
            $Result[0].Keystore | Should -BeNullOrEmpty
            Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter { $Body -like "*tds:GetCertificates*" }
        }

        It "Uses tds:GetCACertificates with -CA" {
            Mock @m Invoke-AxisCertApi { Throw "Command not supported on this device" }
            Mock @m Invoke-AxisSoapRequest {
                $Xml = [xml]@"
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://www.w3.org/2003/05/soap-envelope" xmlns:tds="http://www.onvif.org/ver10/device/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema">
<SOAP-ENV:Body><tds:GetCACertificatesResponse>
<tds:CACertificate><tt:CertificateID>Root</tt:CertificateID><tt:Certificate><tt:Data>$TestCertB64</tt:Data></tt:Certificate></tds:CACertificate>
</tds:GetCACertificatesResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
"@
                return $Xml.Envelope.Body
            }

            $Result = @(Get-AxisCertificate -Device "192.168.0.100" -CA)

            $Result[0].Alias | Should -Be "Root"
            Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter { $Body -like "*tds:GetCACertificates*" }
        }
    }

    AfterAll {
        Remove-Variable TestCert, TestCertPem, TestCertB64 -Scope Global -ErrorAction SilentlyContinue
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

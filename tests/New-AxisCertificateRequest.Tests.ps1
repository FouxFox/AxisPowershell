Describe "New-AxisCertificateRequest" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        InModuleScope AxisPowerShell {
            $Script:Config.Certificate = @{ Alias = "AxisPowershell"; KeyType = "Auto"; Keystore = "Auto"; SubjectTemplate = "CN={FQDN}"; SanTemplate = @("DNS:{FQDN}"); IncludeIP = $false }
        }
        $Global:TestCsrPem = "-----BEGIN CERTIFICATE REQUEST-----`nMIIBfake`n-----END CERTIFICATE REQUEST-----"
        $Global:TestCsrB64 = [Convert]::ToBase64String([byte[]](1,2,3,4,5,6,7,8))
    }

    BeforeEach {
        Mock @m Get-AxisCertificateSubject { return @{ Subject = "CN=cam01.example.com"; SubjectAltNames = @("DNS:cam01.example.com") } }
        Mock @m Get-AxisCertificateKeyType { return [pscustomobject]@{ KeyType = "NIST-P256"; Keystore = "TPM0"; SecurityLevel = "STRONG"; Source = "REST" } }
    }

    Context "JSON API" {
        It "Creates a key and returns the CSR for a new alias" {
            Mock @m Invoke-AxisCertApi {
                if($Path -eq "/certificates") { return @() }
                if($Path -eq "/create_certificate") { return $null }
                if($Path -like "*/get_csr") { return $TestCsrPem }
                Throw "unexpected path $Path"
            }

            $Result = New-AxisCertificateRequest -Device "192.168.0.100"

            $Result.Alias | Should -Be "AxisPowershell"
            $Result.Csr | Should -Be $TestCsrPem
            $Result.Subject | Should -Be "CN=cam01.example.com"
            $Result.SubjectAltNames | Should -Be @("DNS:cam01.example.com")
            $Result.KeyType | Should -Be "NIST-P256"
            $Result.Keystore | Should -Be "TPM0"
            $Result.Source | Should -Be "REST"
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter {
                $Path -eq "/create_certificate" -and $Method -eq "POST" -and
                $Data.alias -eq "AxisPowershell" -and $Data.key_type -eq "NIST-P256" -and $Data.keystore -eq "TPM0" -and
                $Data.subject -eq "CN=cam01.example.com" -and $Data.subject_alt_names -contains "DNS:cam01.example.com" -and
                ($Data.valid_to - $Data.valid_from) -gt 31000000
            }
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter {
                $Path -eq "/certificates/AxisPowershell/get_csr" -and $Method -eq "POST" -and $Data.subject -eq "CN=cam01.example.com"
            }
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter { $Method -eq "DELETE" } -Times 0
        }

        It "Reuses the existing key when the alias exists" {
            Mock @m Invoke-AxisCertApi {
                if($Path -eq "/certificates") { return @([pscustomobject]@{ alias = "AxisPowershell"; certificate = "x"; keystore = "SE0" }) }
                if($Path -like "*/get_csr") { return [pscustomobject]@{ alias = $TestCsrPem } }
                Throw "unexpected path $Path"
            }
            Mock @m Get-AxisCertificate { return [pscustomobject]@{ Alias = "AxisPowershell"; KeyType = "RSA-2048" } }

            $Result = New-AxisCertificateRequest -Device "192.168.0.100" -Subject "CN=given.example.com" -SubjectAltNames @("DNS:given.example.com","DNS:given")

            $Result.Csr | Should -Be $TestCsrPem
            $Result.Keystore | Should -Be "SE0"
            $Result.KeyType | Should -Be "RSA-2048"
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter { $Path -eq "/create_certificate" } -Times 0
            Should @m -Invoke "Get-AxisCertificateKeyType" -Times 0
            Should @m -Invoke "Get-AxisCertificateSubject" -Times 0
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter {
                $Path -like "*/get_csr" -and $Data.subject -eq "CN=given.example.com" -and $Data.subject_alt_names.Count -eq 2
            }
        }

        It "Deletes and recreates with -Force" {
            Mock @m Invoke-AxisCertApi {
                if($Path -eq "/certificates") { return @([pscustomobject]@{ alias = "Web"; certificate = "x"; keystore = "SE0" }) }
                if($Path -like "*/get_csr") { return $TestCsrPem }
                return $null
            }

            $Result = New-AxisCertificateRequest -Device "192.168.0.100" -Alias "Web" -KeyType "RSA-2048" -Force

            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter { $Path -eq "/certificates/Web" -and $Method -eq "DELETE" } -Times 1
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter { $Path -eq "/create_certificate" } -Times 1
            Should @m -Invoke "Get-AxisCertificateKeyType" -ParameterFilter { $KeyType -eq "RSA-2048" }
        }

        It "Throws when the device returns no CSR" {
            Mock @m Invoke-AxisCertApi {
                if($Path -eq "/certificates") { return @() }
                if($Path -like "*/get_csr") { return "nothing" }
                return $null
            }

            { New-AxisCertificateRequest -Device "192.168.0.100" } | Should -Throw "*did not return a PEM certificate request*"
        }
    }

    Context "SOAP fallback" {
        It "Uses CreateCertificate2 and GetPkcs10Request on old firmware" {
            Mock @m Invoke-AxisCertApi { Throw "Command not supported on this device" }
            Mock @m Get-AxisCertificate { return @() }
            Mock @m Get-AxisCertificateKeyType { return [pscustomobject]@{ KeyType = "RSA-2048"; Keystore = $null; SecurityLevel = $null; Source = "SOAP" } }
            Mock @m Invoke-AxisSoapRequest {
                if($Body -like "*GetPkcs10Request*") {
                    $Xml = [xml]@"
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://www.w3.org/2003/05/soap-envelope" xmlns:tds="http://www.onvif.org/ver10/device/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema">
<SOAP-ENV:Body><tds:GetPkcs10RequestResponse><tds:Pkcs10Request><tt:Data>$TestCsrB64</tt:Data></tds:Pkcs10Request></tds:GetPkcs10RequestResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
"@
                    return $Xml.Envelope.Body
                }
                return $null
            }

            $Result = New-AxisCertificateRequest -Device "192.168.0.100" -Subject "CN=cam01.example.com,O=Example,C=US" -WarningVariable Warnings 3>$null

            $Result.Source | Should -Be "SOAP"
            $Result.Csr | Should -Match "-----BEGIN CERTIFICATE REQUEST-----"
            $Result.Csr | Should -Match ([regex]::Escape($TestCsrB64))
            $Result.SubjectAltNames.Count | Should -Be 0
            Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter {
                $Body -like "*acertificates:CreateCertificate2*" -and $Body -like "*<acert:CN>cam01.example.com</acert:CN>*" -and
                $Body -like "*<acert:O>Example</acert:O>*" -and $Body -like "*<acert:C>US</acert:C>*" -and $Body -like "*<acertificates:Id>AxisPowershell-csr</acertificates:Id>*"
            } -Times 1
            Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter {
                $Body -like "*tds:GetPkcs10Request*" -and $Body -like "*<tds:CertificateID>AxisPowershell-csr</tds:CertificateID>*" -and $Body -like "*<tds:Subject>cam01.example.com</tds:Subject>*"
            } -Times 1
        }

        It "Does not recreate an existing alias without -Force" {
            Mock @m Invoke-AxisCertApi { Throw "Command not supported on this device" }
            Mock @m Get-AxisCertificate { return @([pscustomobject]@{ Alias = "AxisPowershell-csr"; Thumbprint = "AA" }) }
            Mock @m Get-AxisCertificateKeyType { return [pscustomobject]@{ KeyType = "RSA-2048"; Keystore = $null; Source = "SOAP" } }
            Mock @m Invoke-AxisSoapRequest {
                $Xml = [xml]@"
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://www.w3.org/2003/05/soap-envelope" xmlns:tds="http://www.onvif.org/ver10/device/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema">
<SOAP-ENV:Body><tds:GetPkcs10RequestResponse><tds:Pkcs10Request><tt:Data>$TestCsrB64</tt:Data></tds:Pkcs10Request></tds:GetPkcs10RequestResponse></SOAP-ENV:Body></SOAP-ENV:Envelope>
"@
                return $Xml.Envelope.Body
            }

            $null = New-AxisCertificateRequest -Device "192.168.0.100" 3>$null

            Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter { $Body -like "*CreateCertificate2*" } -Times 0
            Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter { $Body -like "*GetPkcs10Request*" } -Times 1
        }
    }

    AfterAll {
        Remove-Variable TestCsrPem, TestCsrB64 -Scope Global -ErrorAction SilentlyContinue
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

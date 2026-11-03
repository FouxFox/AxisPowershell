Describe "Install-AxisCertificate" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        #In-memory CA and leaf certificates; keys stay in process memory
        $CaKey = [System.Security.Cryptography.ECDsa]::Create([System.Security.Cryptography.ECCurve]::CreateFromFriendlyName("nistP256"))
        $CaReq = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest("CN=Test Root CA, O=Example", $CaKey, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
        $CaReq.CertificateExtensions.Add((New-Object System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension($true, $false, 0, $true)))
        $Global:TestCa = $CaReq.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-2), [DateTimeOffset]::UtcNow.AddYears(5))

        $LeafKey = [System.Security.Cryptography.ECDsa]::Create([System.Security.Cryptography.ECCurve]::CreateFromFriendlyName("nistP256"))
        $LeafReq = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest("CN=cam01.example.com", $LeafKey, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
        $Serial = [byte[]](1,2,3,4,5,6,7,8)
        $Global:TestLeaf = $LeafReq.Create($TestCa, [DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddYears(1), $Serial)

        $Global:TestLeafPem = "-----BEGIN CERTIFICATE-----`n$([Convert]::ToBase64String($TestLeaf.RawData))`n-----END CERTIFICATE-----"
        $Global:TestCaPem = "-----BEGIN CERTIFICATE-----`n$([Convert]::ToBase64String($TestCa.RawData))`n-----END CERTIFICATE-----"
    }

    BeforeEach {
        Mock @m Set-AxisWebServerCertificate { }
        Mock @m Update-AxisParameter { }
        Mock @m Write-Log { }
        Mock @m Start-Sleep { }
    }

    Context "JSON API" {
        It "Patches the certificate, installs the CA and verifies HTTPS" {
            Mock @m Invoke-AxisCertApi { return $null }
            Mock @m Get-AxisCertificate { return @() }
            Mock @m Get-AxisTlsCertificate { return $TestLeaf }

            $Result = Install-AxisCertificate -Device "192.168.0.100" -Alias "AxisPowershell" -Certificate $TestLeafPem -CACertificates @($TestCaPem) -AssignToHttps

            $Result.Thumbprint | Should -Be $TestLeaf.Thumbprint
            $Result.NotAfter | Should -Be $TestLeaf.NotAfter
            $Result.HttpsVerified | Should -BeTrue
            $Result.Source | Should -Be "REST"
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter {
                $Path -eq "/certificates/AxisPowershell" -and $Method -eq "PATCH" -and $Data.certificate -eq $TestLeafPem
            } -Times 1
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter {
                $Path -eq "/ca_certificates" -and $Method -eq "POST" -and $Data.alias -eq "Test-Root-CA" -and $Data.certificate -eq $TestCaPem
            } -Times 1
            Should @m -Invoke "Set-AxisWebServerCertificate" -ParameterFilter { $Alias -eq "AxisPowershell" } -Times 1
            Should @m -Invoke "Update-AxisParameter" -Times 0
        }

        It "Skips CA certificates that are already installed and splits bundles" {
            Mock @m Invoke-AxisCertApi { return $null }
            Mock @m Get-AxisCertificate { return @([pscustomobject]@{ Alias = "Existing"; Thumbprint = $TestCa.Thumbprint }) }
            Mock @m Get-AxisTlsCertificate { return $null }

            $Bundle = "$TestLeafPem`n$TestCaPem"
            $Result = Install-AxisCertificate -Device "192.168.0.100" -Alias "AxisPowershell" -Certificate $Bundle

            $Result.HttpsVerified | Should -BeFalse
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter { $Path -eq "/certificates/AxisPowershell" -and $Method -eq "PATCH" -and $Data.certificate -eq $TestLeafPem } -Times 1
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter { $Path -eq "/ca_certificates" } -Times 0
            Should @m -Invoke "Set-AxisWebServerCertificate" -Times 0
        }

        It "Enables HTTPS-only and switches the cache to https" {
            Mock @m Invoke-AxisCertApi { return $null }
            Mock @m Get-AxisTlsCertificate { return $TestLeaf }
            InModuleScope AxisPowerShell { $Script:Cache["192.168.0.100"] = @{ Type = "http" } }

            $Result = Install-AxisCertificate -Device "192.168.0.100" -Alias "AxisPowershell" -Certificate $TestLeafPem -HttpsOnly

            $Result.HttpsVerified | Should -BeTrue
            Should @m -Invoke "Set-AxisWebServerCertificate" -Times 1
            Should @m -Invoke "Update-AxisParameter" -ParameterFilter {
                $ParameterSet."System.BoaGroupPolicy.admin" -eq "https" -and
                $ParameterSet."System.BoaGroupPolicy.operator" -eq "https" -and
                $ParameterSet."System.BoaGroupPolicy.viewer" -eq "https"
            } -Times 1
            InModuleScope AxisPowerShell { $Cache["192.168.0.100"].Type } | Should -Be "https"
        }

        It "Reads the certificate from a file" {
            Mock @m Invoke-AxisCertApi { return $null }
            Mock @m Get-AxisTlsCertificate { return $null }
            $File = Join-Path ([System.IO.Path]::GetTempPath()) "axisps-test-leaf.pem"
            Set-Content -Path $File -Value $TestLeafPem

            Try {
                $Result = Install-AxisCertificate -Device "192.168.0.100" -Alias "AxisPowershell" -Certificate $File
                $Result.Thumbprint | Should -Be $TestLeaf.Thumbprint
            }
            Finally {
                Remove-Item $File -ErrorAction SilentlyContinue
            }
        }

        It "Throws on API errors" {
            Mock @m Invoke-AxisCertApi { Throw "Certificate API error: Validation error" }

            { Install-AxisCertificate -Device "192.168.0.100" -Alias "AxisPowershell" -Certificate $TestLeafPem } | Should -Throw "*Validation error*"
        }
    }

    Context "SOAP fallback" {
        It "Uses LoadCertificates / LoadCACertificates with base64 DER on old firmware" {
            Mock @m Invoke-AxisCertApi { Throw "Command not supported on this device" }
            Mock @m Get-AxisCertificate { return @() }
            Mock @m Get-AxisTlsCertificate { return $TestLeaf }
            Mock @m Invoke-AxisSoapRequest { return $null }

            $Result = Install-AxisCertificate -Device "192.168.0.100" -Alias "AxisPowershell" -Certificate $TestLeafPem -CACertificates @($TestCaPem) -AssignToHttps

            $Result.Source | Should -Be "SOAP"
            $Result.HttpsVerified | Should -BeTrue
            $LeafB64 = [Convert]::ToBase64String($TestLeaf.RawData)
            $CaB64 = [Convert]::ToBase64String($TestCa.RawData)
            Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter {
                $Body -like "*tds:LoadCertificates*" -and $Body -like "*<tt:CertificateID>AxisPowershell</tt:CertificateID>*" -and $Body -like "*$LeafB64*"
            } -Times 1
            Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter {
                $Body -like "*tds:LoadCACertificates*" -and $Body -like "*<tt:CertificateID>Test-Root-CA</tt:CertificateID>*" -and $Body -like "*$CaB64*"
            } -Times 1
            Should @m -Invoke "Set-AxisWebServerCertificate" -Times 1
        }
    }

    AfterAll {
        Remove-Variable TestCa, TestLeaf, TestLeafPem, TestCaPem -Scope Global -ErrorAction SilentlyContinue
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

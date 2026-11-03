Describe "Set-AxisCertificateEnrollment" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        InModuleScope AxisPowerShell {
            $Script:Config.CertificateAuthorities = @{
                Dogtag = @{ Type = "Dogtag"; Server = "https://pki.example.com:8443"; Template = "cameras" }
                Est = @{ Type = "EST"; Server = "https://est.example.com"; Label = "cams"; CAThumbprint = "" }
                WinCA = @{ Type = "WindowsCA"; CAConfig = "ca.example.com\Example CA" }
            }
            $Script:Config.Certificate = @{ DefaultAuthority = "Dogtag"; HttpsOnly = $false }
        }
        #In-memory root CA; key stays in process memory
        $CaKey = [System.Security.Cryptography.ECDsa]::Create([System.Security.Cryptography.ECCurve]::CreateFromFriendlyName("nistP256"))
        $CaReq = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest("CN=EST Root CA, O=Example", $CaKey, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
        $CaReq.CertificateExtensions.Add((New-Object System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension($true, $false, 0, $true)))
        $Global:EstTestCa = $CaReq.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-2), [DateTimeOffset]::UtcNow.AddYears(5))
        $Global:EstTestCaPem = "-----BEGIN CERTIFICATE-----`n$([Convert]::ToBase64String($EstTestCa.RawData))`n-----END CERTIFICATE-----"
        $Global:EstBasePath = "/config/rest/cert-est/v1"
    }

    BeforeEach {
        Mock @m Write-Log { }
        Mock @m Update-AxisParameter { }
        Mock @m Initialize-AxisCache { }
        Mock @m Get-AxisConfigApiPath { return $EstBasePath }
        Mock @m Get-AxisCertificateSubject { return @{ Subject = "CN=cam01.example.com,O=Example"; SubjectAltNames = @("DNS:cam01.example.com","DNS:cam01") } }
        Mock @m Get-AxisCertificate -ParameterFilter { $CA } { return @() }
        Mock @m Get-AxisCertificate -ParameterFilter { !$CA } {
            return @(
                [pscustomobject]@{ Alias = "Axis device ID RSA-2048"; Subject = "CN=B8A44FB197BB"; Issuer = "CN=Axis Device ID Intermediate CA RSA 1"; KeyType = "RSA-2048" },
                [pscustomobject]@{ Alias = "Axis device ID ECC-P256"; Subject = "CN=B8A44FB197BB"; Issuer = "CN=Axis Device ID Intermediate CA ECC 1"; KeyType = "NIST-P256" },
                [pscustomobject]@{ Alias = "AxisPowershell"; Subject = "CN=cam01.example.com"; Issuer = "CN=Example CA"; KeyType = "NIST-P256" }
            )
        }
        Mock @m Invoke-AxisCertApi { return $null }
        #Default device: no profiles yet, status UNCONNECTED after creation
        Mock @m Invoke-AxisWebApi -ParameterFilter { $Path -eq "$EstBasePath/profiles" -and !$Method } { return [pscustomobject]@{ status = "success"; data = @() } }
        Mock @m Invoke-AxisWebApi -ParameterFilter { $Path -like "$EstBasePath/profiles/*/status" } { return [pscustomobject]@{ status = "success"; data = "UNCONNECTED" } }
        Mock @m Invoke-AxisWebApi { return [pscustomobject]@{ status = "success"; data = $Body.data } }
    }

    Context "Profile creation" {
        It "Pre-loads the CA, creates the profile with the device ID certificate and Dogtag EST URL" {
            $Result = Set-AxisCertificateEnrollment -Device "192.168.0.100" -CACertificate $EstTestCaPem

            $Result.Device | Should -Be "192.168.0.100"
            $Result.ProfileId | Should -Be "AxisPowershell"
            $Result.Server | Should -Be "pki.example.com:8443/.well-known/est/cameras"
            $Result.Status | Should -Be "UNCONNECTED"
            Should @m -Invoke "Get-AxisConfigApiPath" -ParameterFilter { $API -eq "cert-est" } -Times 1
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter {
                $Path -eq "/ca_certificates" -and $Method -eq "POST" -and $Data.alias -eq "EST-Root-CA" -and $Data.certificate -eq $EstTestCaPem
            } -Times 1
            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter {
                $Path -eq "$EstBasePath/profiles" -and $Method -eq "POST" -and
                $Body.data.id -eq "AxisPowershell" -and
                $Body.data.server -eq "pki.example.com:8443/.well-known/est/cameras" -and
                $Body.data.certificate -eq "Axis device ID ECC-P256" -and
                $Body.data.caCertificates.Count -eq 1 -and $Body.data.caCertificates[0] -eq "EST-Root-CA" -and
                $Body.data.subject.cn -eq "cam01.example.com" -and
                $Body.data.subjectAlternativeNames.Count -eq 2 -and $Body.data.subjectAlternativeNames[1] -eq "DNS:cam01" -and
                $Body.data.services.Count -eq 1 -and $Body.data.services[0] -eq "WEBSERVER"
            } -Times 1
            Should @m -Invoke "Update-AxisParameter" -Times 0
        }

        It "Skips the CA upload when the same thumbprint is installed and uses its alias" {
            Mock @m Get-AxisCertificate -ParameterFilter { $CA } { return @([pscustomobject]@{ Alias = "Existing-Root"; Thumbprint = $EstTestCa.Thumbprint }) }

            $null = Set-AxisCertificateEnrollment -Device "192.168.0.100" -CACertificate $EstTestCaPem

            Should @m -Invoke "Invoke-AxisCertApi" -Times 0
            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter { $Method -eq "POST" -and $Body.data.caCertificates[0] -eq "Existing-Root" } -Times 1
        }

        It "Accepts an installed CA alias, explicit client alias, services and an EST authority with Label" {
            Mock @m Get-AxisCertificate -ParameterFilter { $CA } { return @([pscustomobject]@{ Alias = "EST-Root"; Thumbprint = "AA" }) }

            $Result = Set-AxisCertificateEnrollment -Device "192.168.0.100" -CertificateAuthority Est -ProfileId "Cams" -ClientCertificateAlias "AxisPowershell" -CACertificate "EST-Root" -Services WEBSERVER,RTSPS

            $Result.Server | Should -Be "est.example.com/.well-known/est/cams"
            Should @m -Invoke "Invoke-AxisCertApi" -Times 0
            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter {
                $Method -eq "POST" -and $Body.data.id -eq "Cams" -and $Body.data.certificate -eq "AxisPowershell" -and
                $Body.data.caCertificates[0] -eq "EST-Root" -and $Body.data.services.Count -eq 2 -and $Body.data.services[1] -eq "RTSPS"
            } -Times 1
        }

        It "Enables HTTPS-only from configuration and switches the cache to https" {
            InModuleScope AxisPowerShell { $Script:Config.Certificate.HttpsOnly = $true; $Script:Cache["192.168.0.100"] = @{ Type = "http" } }
            Try {
                $null = Set-AxisCertificateEnrollment -Device "192.168.0.100" -CACertificate $EstTestCaPem
            }
            Finally {
                InModuleScope AxisPowerShell { $Script:Config.Certificate.HttpsOnly = $false }
            }

            Should @m -Invoke "Update-AxisParameter" -ParameterFilter {
                $ParameterSet."System.BoaGroupPolicy.admin" -eq "https" -and
                $ParameterSet."System.BoaGroupPolicy.operator" -eq "https" -and
                $ParameterSet."System.BoaGroupPolicy.viewer" -eq "https"
            } -Times 1
            InModuleScope AxisPowerShell { $Cache["192.168.0.100"].Type } | Should -Be "https"
        }
    }

    Context "Profile update" {
        It "Patches an existing profile instead of creating it" {
            Mock @m Invoke-AxisWebApi -ParameterFilter { $Path -eq "$EstBasePath/profiles" -and !$Method } {
                return [pscustomobject]@{ status = "success"; data = @([pscustomobject]@{ id = "AxisPowershell"; status = "ENROLLED" }) }
            }
            Mock @m Invoke-AxisWebApi -ParameterFilter { $Path -like "$EstBasePath/profiles/*/status" } { return [pscustomobject]@{ status = "success"; data = "ENROLLED" } }

            $Result = Set-AxisCertificateEnrollment -Device "192.168.0.100" -CACertificate $EstTestCaPem

            $Result.Status | Should -Be "ENROLLED"
            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter {
                $Path -eq "$EstBasePath/profiles/AxisPowershell" -and $Method -eq "PATCH" -and $null -eq $Body.data.id -and $Body.data.server -eq "pki.example.com:8443/.well-known/est/cameras"
            } -Times 1
            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter { $Method -eq "POST" } -Times 0
        }

        It "Refuses a third profile" {
            Mock @m Invoke-AxisWebApi -ParameterFilter { $Path -eq "$EstBasePath/profiles" -and !$Method } {
                return [pscustomobject]@{ status = "success"; data = @([pscustomobject]@{ id = "One" },[pscustomobject]@{ id = "Two" }) }
            }

            { Set-AxisCertificateEnrollment -Device "192.168.0.100" -CACertificate $EstTestCaPem } | Should -Throw "*already holds 2 EST profiles*"
        }
    }

    Context "Validation" {
        It "Rejects authorities that are not EST capable" {
            { Set-AxisCertificateEnrollment -Device "192.168.0.100" -CertificateAuthority WinCA -CACertificate $EstTestCaPem } | Should -Throw "*Type Dogtag or EST*"
        }

        It "Propagates 'Command not supported' from Get-AxisConfigApiPath" {
            Mock @m Get-AxisConfigApiPath { Throw "Command not supported on this device" }

            { Set-AxisCertificateEnrollment -Device "192.168.0.100" -CACertificate $EstTestCaPem } | Should -Throw "Command not supported on this device"
        }

        It "Requires -ClientCertificateAlias when no Axis device ID certificate exists" {
            Mock @m Get-AxisCertificate -ParameterFilter { !$CA } { return @([pscustomobject]@{ Alias = "Other"; Subject = "CN=x"; Issuer = "CN=y"; KeyType = "RSA-2048" }) }

            { Set-AxisCertificateEnrollment -Device "192.168.0.100" -CACertificate $EstTestCaPem } | Should -Throw "*-ClientCertificateAlias*"
        }

        It "Refuses a profile without an EST server CA certificate" {
            { Set-AxisCertificateEnrollment -Device "192.168.0.100" } | Should -Throw "*-CACertificate*"
            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter { $Method -eq "POST" } -Times 0
        }

        It "Throws on device errors" {
            Mock @m Invoke-AxisWebApi -ParameterFilter { $Method -eq "POST" } { return [pscustomobject]@{ status = "error"; error = [pscustomobject]@{ code = 1000; message = "Validation error" } } }

            { Set-AxisCertificateEnrollment -Device "192.168.0.100" -CACertificate $EstTestCaPem } | Should -Throw "*Validation error*"
        }
    }

    Context "Get / Remove" {
        It "Get-AxisCertificateEnrollment lists profiles with status" {
            Mock @m Invoke-AxisWebApi -ParameterFilter { $Path -eq "$EstBasePath/profiles" } {
                return [pscustomobject]@{ status = "success"; data = @([pscustomobject]@{
                    id = "AxisPowershell"; server = "pki.example.com:8443/.well-known/est/cameras"; caCertificates = @("EST-Root-CA")
                    certificate = "Axis device ID ECC-P256"; subject = [pscustomobject]@{ cn = "cam01.example.com" }
                    subjectAlternativeNames = @("DNS:cam01.example.com"); services = @("WEBSERVER"); status = "ENROLLED"
                }) }
            }

            $Result = Get-AxisCertificateEnrollment -Device "192.168.0.100"

            @($Result).Count | Should -Be 1
            $Result.ProfileId | Should -Be "AxisPowershell"
            $Result.ClientCertificate | Should -Be "Axis device ID ECC-P256"
            $Result.CommonName | Should -Be "cam01.example.com"
            $Result.Status | Should -Be "ENROLLED"
            (Get-AxisCertificateEnrollment -Device "192.168.0.100" -ProfileId "Nope") | Should -BeNullOrEmpty
        }

        It "Remove-AxisCertificateEnrollment sends DELETE for the escaped profile id" {
            Remove-AxisCertificateEnrollment -Device "192.168.0.100" -ProfileId "EST Profile"

            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter { $Path -eq "$EstBasePath/profiles/EST%20Profile" -and $Method -eq "DELETE" } -Times 1
        }
    }

    AfterAll {
        Remove-Variable EstTestCa, EstTestCaPem, EstBasePath -Scope Global -ErrorAction SilentlyContinue
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

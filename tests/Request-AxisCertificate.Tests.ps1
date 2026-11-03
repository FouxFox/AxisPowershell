Describe "Request-AxisCertificate" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        InModuleScope AxisPowerShell {
            $Script:Config.CertificateAuthorities = @{
                TestCA = @{ Type = "Command"; Template = "server"; SignCommand = "fake"; TimeoutSec = 10 }
            }
            $Script:Config.Certificate = @{
                DefaultAuthority = "TestCA"
                SubjectTemplate = "CN={FQDN}"
                SanTemplate = @("DNS:{FQDN}")
                IncludeIP = $false
                KeyType = "Auto"
                Keystore = "Auto"
                Alias = "AxisPowershell"
                HttpsOnly = $true
                RenewWithinDays = 30
            }
        }

        #In-memory CA and two leaf certificates (old and new); keys never leave memory
        $CaKey = [System.Security.Cryptography.RSA]::Create(2048)
        $CaReq = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest("CN=Test Root CA", $CaKey, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $CaReq.CertificateExtensions.Add((New-Object System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension($true, $false, 0, $true)))
        $Global:TestCa = $CaReq.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-2), [DateTimeOffset]::UtcNow.AddYears(5))
        $LeafKey = [System.Security.Cryptography.RSA]::Create(2048)
        $LeafReq = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest("CN=cam01.example.com", $LeafKey, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $Global:NewLeaf = $LeafReq.Create($TestCa, [DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddYears(1), [byte[]](1,2,3,4))
        $Global:NewLeafPem = "-----BEGIN CERTIFICATE-----`n$([Convert]::ToBase64String($NewLeaf.RawData))`n-----END CERTIFICATE-----"
        $Global:CaPem = "-----BEGIN CERTIFICATE-----`n$([Convert]::ToBase64String($TestCa.RawData))`n-----END CERTIFICATE-----"

        $Global:OldCert = [pscustomobject]@{
            Alias = "AxisPowershell"; Subject = "CN=cam01.example.com"; Issuer = "CN=Test Root CA"
            NotAfter = (Get-Date).AddDays(10); Serial = "0A0B"; Thumbprint = "OLDTHUMB"
        }
        $Global:ValidCert = [pscustomobject]@{
            Alias = "AxisPowershell"; Subject = "CN=cam01.example.com"; Issuer = "CN=Test Root CA"
            NotAfter = (Get-Date).AddDays(200); Serial = "0A0C"; Thumbprint = "VALIDTHUMB"
        }
        $Global:SelfSigned = [pscustomobject]@{
            Alias = "AxisPowershell"; Subject = "CN=cam01.example.com"; Issuer = "CN=cam01.example.com"
            NotAfter = (Get-Date).AddDays(300); Serial = "01"; Thumbprint = "SELF"
        }
    }

    BeforeEach {
        Mock @m Check-Credential { }
        Mock @m Get-AxisCertificateSubject { return @{ Subject = "CN=cam01.example.com"; SubjectAltNames = @("DNS:cam01.example.com") } }
        Mock @m New-AxisCertificateRequest { return [pscustomobject]@{ Alias = $Alias; Csr = "-----BEGIN CERTIFICATE REQUEST-----`nAAAA`n-----END CERTIFICATE REQUEST-----"; KeyType = "NIST-P256" } }
        Mock @m Submit-AxisCertificateRequest { return [pscustomobject]@{ Certificate = $NewLeafPem; Chain = @($CaPem); Serial = "01020304"; RequestId = "7"; Status = "Issued" } }
        Mock @m Install-AxisCertificate { return [pscustomobject]@{ Device = $Device; Alias = $Alias; Thumbprint = $NewLeaf.Thumbprint; NotAfter = $NewLeaf.NotAfter; HttpsVerified = $true } }
        Mock @m Remove-AxisCertificate { }
        Mock @m Revoke-AxisIssuedCertificate { return $true }
        Mock @m Write-Log { }
    }

    Context "First issuance" {
        It "Issues when the device has no managed certificate" {
            Mock @m Get-AxisCertificate { return @() }
            $Result = Request-AxisCertificate -Device "192.168.0.100"
            $Result.Action | Should -Be "Issued"
            $Result.Alias | Should -Be "AxisPowershell"
            $Result.Serial | Should -Be "01020304"
            $Result.HttpsVerified | Should -BeTrue
            Should @m -Invoke "New-AxisCertificateRequest" -ParameterFilter { $Alias -eq "AxisPowershell" -and $Subject -eq "CN=cam01.example.com" } -Times 1
            Should @m -Invoke "Install-AxisCertificate" -ParameterFilter { $AssignToHttps -eq $true -and $HttpsOnly -eq $true -and $CACertificates.Count -eq 1 } -Times 1
            Should @m -Invoke "Revoke-AxisIssuedCertificate" -Times 0
        }

        It "Treats a self-signed placeholder as no certificate" {
            Mock @m Get-AxisCertificate { return @($SelfSigned) }
            (Request-AxisCertificate -Device "192.168.0.100").Action | Should -Be "Issued"
        }

        It "Honours -NoHttpsOnly" {
            Mock @m Get-AxisCertificate { return @() }
            $null = Request-AxisCertificate -Device "192.168.0.100" -NoHttpsOnly
            Should @m -Invoke "Install-AxisCertificate" -ParameterFilter { $HttpsOnly -eq $false } -Times 1
        }

        It "Cleans up the placeholder and throws when the CA rejects the request" {
            Mock @m Get-AxisCertificate { return @() }
            Mock @m Submit-AxisCertificateRequest { Throw "denied by policy" }
            { Request-AxisCertificate -Device "192.168.0.100" } | Should -Throw "*denied by policy*"
            Should @m -Invoke "Remove-AxisCertificate" -ParameterFilter { $Alias -eq "AxisPowershell" -and $Force -eq $true } -Times 1
            Should @m -Invoke "Install-AxisCertificate" -Times 0
        }
    }

    Context "Lifecycle" {
        It "Leaves a valid certificate alone" {
            Mock @m Get-AxisCertificate { return @($ValidCert) }
            $Result = Request-AxisCertificate -Device "192.168.0.100"
            $Result.Action | Should -Be "Current"
            $Result.Serial | Should -Be "0A0C"
            Should @m -Invoke "New-AxisCertificateRequest" -Times 0
        }

        It "Renews within the window, removes and revokes the old certificate as Superseded" {
            Mock @m Get-AxisCertificate { return @($OldCert) }
            $Result = Request-AxisCertificate -Device "192.168.0.100"
            $Result.Action | Should -Be "Renewed"
            $Result.Alias | Should -BeLike "AxisPowershell-*"
            $Result.RevokedSerial | Should -Be "0A0B"
            Should @m -Invoke "Remove-AxisCertificate" -ParameterFilter { $Alias -eq "AxisPowershell" -and $Force -eq $true } -Times 1
            Should @m -Invoke "Revoke-AxisIssuedCertificate" -ParameterFilter { $Serial -eq "0A0B" -and $Reason -eq "Superseded" } -Times 1
        }

        It "Renews a valid certificate with -Force" {
            Mock @m Get-AxisCertificate { return @($ValidCert) }
            (Request-AxisCertificate -Device "192.168.0.100" -Force).Action | Should -Be "Renewed"
        }

        It "Keeps the old certificate when HTTPS binding is not verified" {
            Mock @m Get-AxisCertificate { return @($OldCert) }
            Mock @m Install-AxisCertificate { return [pscustomobject]@{ Device = $Device; Alias = $Alias; Thumbprint = "X"; NotAfter = (Get-Date); HttpsVerified = $false } }
            $Result = Request-AxisCertificate -Device "192.168.0.100" -WarningAction SilentlyContinue
            $Result.Action | Should -Be "Renewed"
            $Result.HttpsVerified | Should -BeFalse
            Should @m -Invoke "Remove-AxisCertificate" -Times 0
            Should @m -Invoke "Revoke-AxisIssuedCertificate" -Times 0
        }

        It "Does not revoke with -NoRevoke" {
            Mock @m Get-AxisCertificate { return @($OldCert) }
            $null = Request-AxisCertificate -Device "192.168.0.100" -NoRevoke
            Should @m -Invoke "Revoke-AxisIssuedCertificate" -Times 0
        }

        It "Reports a failed revocation as a warning, not an error" {
            Mock @m Get-AxisCertificate { return @($OldCert) }
            Mock @m Revoke-AxisIssuedCertificate { Throw "CA unreachable" }
            $Result = Request-AxisCertificate -Device "192.168.0.100" -WarningAction SilentlyContinue
            $Result.Action | Should -Be "Renewed"
            $Result.RevokedSerial | Should -BeNullOrEmpty
            $Result.Message | Should -BeLike "*revocation of 0A0B failed*"
        }
    }

    Context "Authority resolution" {
        It "Throws for an unknown authority" {
            Mock @m Get-AxisCertificate { return @() }
            { Request-AxisCertificate -Device "192.168.0.100" -CertificateAuthority Nope } | Should -Throw "*not configured*"
        }
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

Describe "Submit-AxisCsrToEST" {
    BeforeAll {
        #In-memory test PKI: root CA + leaf, no keys ever touch disk (CertificateRequest / CreateSelfSigned)
        $Script:RootKey = [System.Security.Cryptography.RSA]::Create(2048)
        $RootReq = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
            "CN=Test EST Root", $RootKey,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $RootReq.CertificateExtensions.Add([System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($true,$false,0,$true))
        $Script:RootCert = $RootReq.CreateSelfSigned((Get-Date).AddDays(-2), (Get-Date).AddYears(5))

        $Script:LeafKey = [System.Security.Cryptography.RSA]::Create(2048)
        $LeafReq = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
            "CN=camera.example.com", $LeafKey,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $Serial = [byte[]](1,2,3,4,5,6,7,8)
        $Script:LeafCert = $LeafReq.Create($RootCert, (Get-Date).AddDays(-1), (Get-Date).AddYears(1), $Serial)

        #PKCS#7 certs-only blobs as an EST server returns them (base64, line wrapped)
        $Col = [System.Security.Cryptography.X509Certificates.X509Certificate2Collection]::new()
        $Col.Add($RootCert) | Out-Null
        $Script:CaCertsB64 = [Convert]::ToBase64String($Col.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs7), 'InsertLineBreaks')
        $Col = [System.Security.Cryptography.X509Certificates.X509Certificate2Collection]::new()
        $Col.Add($LeafCert) | Out-Null
        $Script:LeafP7B64 = [Convert]::ToBase64String($Col.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs7), 'InsertLineBreaks')

        $Script:CsrDer = $LeafReq.CreateSigningRequest()
        $Script:CsrPem = "-----BEGIN CERTIFICATE REQUEST-----`n$([Convert]::ToBase64String($CsrDer,'InsertLineBreaks'))`n-----END CERTIFICATE REQUEST-----"

        $Script:Authority = @{
            Name = 'TestEST'
            Type = 'EST'
            Server = 'https://est.example.com:8443'
            Label = 'cameras'
            CredentialTarget = 'AxisPowershell-CA-TestEST'
            SkipCertificateCheck = $true
        }
        $Script:EstCredential = New-Object System.Management.Automation.PSCredential ("est-user",(ConvertTo-SecureString -Force -AsPlainText "Secret.123"))

        #Make the mocked collaborators resolvable inside the module even when their files are not present yet
        InModuleScope AxisPowerShell {
            if(!(Get-Command Get-StoredCredential -ErrorAction SilentlyContinue)) { function script:Get-StoredCredential { Param($Target) } }
            if(!(Get-Command Revoke-AxisCertificateOnCommand -ErrorAction SilentlyContinue)) { function script:Revoke-AxisCertificateOnCommand { Param($Authority,$Serial,$Reason) } }
        }

        #Builds the object Invoke-WebRequest would return
        $Script:MakeResponse = {
            Param([Int]$Code, $Content, [Hashtable]$Headers = @{})
            [pscustomobject]@{ StatusCode = $Code; Content = $Content; Headers = $Headers }
        }
    }

    Context "Happy path" {
        BeforeAll {
            Mock @m Get-StoredCredential { $EstCredential }
            Mock @m Write-Log {}
            Mock @m Start-Sleep {}
            Mock @m Invoke-WebRequest {
                if($Method -eq 'GET') { return (& $MakeResponse 200 $CaCertsB64) }
                #PS 7 delivers application/pkcs7-mime as byte[]
                return (& $MakeResponse 200 ([System.Text.Encoding]::ASCII.GetBytes($LeafP7B64)))
            }
            $Script:Result = InModuleScope AxisPowerShell -Parameters @{ Authority = $Authority; Csr = $CsrPem } {
                Submit-AxisCsrToEST -Authority $Authority -Csr $Csr -Device "192.168.0.100"
            }
        }

        It "GETs /.well-known/est/{label}/cacerts without authentication" {
            Should @m -Scope Context -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter {
                $Method -eq 'GET' -and $Uri -eq 'https://est.example.com:8443/.well-known/est/cameras/cacerts' -and !$Headers.ContainsKey('Authorization')
            }
        }

        It "POSTs base64 DER to /simpleenroll as application/pkcs10 with Basic auth" {
            $Expected = [Convert]::ToBase64String($CsrDer)
            $BasicHeader = "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('est-user:Secret.123')))"
            Should @m -Scope Context -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -eq 'https://est.example.com:8443/.well-known/est/cameras/simpleenroll' -and
                $ContentType -eq 'application/pkcs10' -and
                $Headers['Content-Transfer-Encoding'] -eq 'base64' -and
                $Headers['Authorization'] -eq $BasicHeader -and
                $Body -eq $Expected
            }
        }

        It "Honours SkipCertificateCheck on PowerShell 7" -Skip:($PSVersionTable.PSVersion.Major -lt 6) {
            Should @m -Scope Context -Invoke Invoke-WebRequest -Times 2 -ParameterFilter { $SkipCertificateCheck -eq $true }
        }

        It "Returns the leaf certificate as PEM" {
            $Result.Status | Should -Be 'Issued'
            $Result.Certificate | Should -Match '^-----BEGIN CERTIFICATE-----'
            $Leaf = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,[byte[]][Convert]::FromBase64String(($Result.Certificate -replace '-----[A-Z ]+-----','' -replace '\s','')))
            $Leaf.Thumbprint | Should -Be $LeafCert.Thumbprint
        }

        It "Returns the serial as uppercase hex from the X509Certificate2" {
            $Result.Serial | Should -Be $LeafCert.SerialNumber.ToUpper()
            $Result.Serial | Should -Match '^[0-9A-F]+$'
        }

        It "Returns the CA chain from /cacerts" {
            $Result.Chain.Count | Should -Be 1
            $Root = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,[byte[]][Convert]::FromBase64String(($Result.Chain[0] -replace '-----[A-Z ]+-----','' -replace '\s','')))
            $Root.Thumbprint | Should -Be $RootCert.Thumbprint
        }

        It "Returns a RequestId derived from the CSR" {
            $Result.RequestId | Should -Match '^[0-9A-F]{16}$'
        }
    }

    Context "Without a label" {
        BeforeAll {
            Mock @m Get-StoredCredential { $EstCredential }
            Mock @m Invoke-WebRequest {
                if($Method -eq 'GET') { return (& $MakeResponse 200 $CaCertsB64) }
                return (& $MakeResponse 200 $LeafP7B64)
            }
            $NoLabel = $Authority.Clone(); $NoLabel.Remove('Label')
            InModuleScope AxisPowerShell -Parameters @{ Authority = $NoLabel; Csr = $CsrPem } {
                $null = Submit-AxisCsrToEST -Authority $Authority -Csr $Csr
            }
        }

        It "Uses /.well-known/est/cacerts and /simpleenroll" {
            Should @m -Scope Context -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter { $Uri -eq 'https://est.example.com:8443/.well-known/est/cacerts' }
            Should @m -Scope Context -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter { $Uri -eq 'https://est.example.com:8443/.well-known/est/simpleenroll' }
        }
    }

    Context "Pending (202)" {
        BeforeAll {
            Mock @m Get-StoredCredential { $EstCredential }
            Mock @m Write-Log {}
            Mock @m Start-Sleep {}
            $Script:PostCount = 0
            Mock @m Invoke-WebRequest {
                if($Method -eq 'GET') { return (& $MakeResponse 200 $CaCertsB64) }
                $Script:PostCount++
                if($Script:PostCount -lt 3) { return (& $MakeResponse 202 "" @{ 'Retry-After' = @('5') }) }
                return (& $MakeResponse 200 $LeafP7B64)
            }
        }

        It "Throws a pending error when -Wait is not supplied" {
            { InModuleScope AxisPowerShell -Parameters @{ Authority = $Authority; Csr = $CsrPem } {
                Submit-AxisCsrToEST -Authority $Authority -Csr $Csr
            } } | Should -Throw "*is pending approval on TestEST*"
        }

        It "Polls with Retry-After when -Wait is supplied and returns the certificate" {
            $Script:PostCount = 0
            $Result = InModuleScope AxisPowerShell -Parameters @{ Authority = $Authority; Csr = $CsrPem } {
                Submit-AxisCsrToEST -Authority $Authority -Csr $Csr -Wait -TimeoutSec 120
            }
            $Result.Status | Should -Be 'Issued'
            $Result.Serial | Should -Be $LeafCert.SerialNumber.ToUpper()
            Should @m -Invoke Start-Sleep -Times 2 -ParameterFilter { $Seconds -eq 5 }
        }

        It "Gives up when the Retry-After exceeds TimeoutSec" {
            $Script:PostCount = -100
            { InModuleScope AxisPowerShell -Parameters @{ Authority = $Authority; Csr = $CsrPem } {
                Submit-AxisCsrToEST -Authority $Authority -Csr $Csr -TimeoutSec 3
            } } | Should -Throw "*still pending approval*"
        }
    }

    Context "Errors" {
        BeforeAll {
            Mock @m Get-StoredCredential { $EstCredential }
        }

        It "Throws when /cacerts fails" {
            Mock @m Invoke-WebRequest { Throw "503 Service Unavailable" }
            { InModuleScope AxisPowerShell -Parameters @{ Authority = $Authority; Csr = $CsrPem } {
                Submit-AxisCsrToEST -Authority $Authority -Csr $Csr
            } } | Should -Throw "EST /cacerts failed on TestEST*"
        }

        It "Throws when the CAThumbprint pin does not match" {
            Mock @m Invoke-WebRequest { return (& $MakeResponse 200 $CaCertsB64) }
            $Pinned = $Authority.Clone(); $Pinned.CAThumbprint = ('AB' * 20)
            { InModuleScope AxisPowerShell -Parameters @{ Authority = $Pinned; Csr = $CsrPem } {
                Submit-AxisCsrToEST -Authority $Authority -Csr $Csr
            } } | Should -Throw "*did not contain the pinned CA certificate*"
            Should @m -Invoke Invoke-WebRequest -Exactly -Times 0 -ParameterFilter { $Method -eq 'POST' }
        }

        It "Accepts a matching CAThumbprint pin" {
            Mock @m Invoke-WebRequest {
                if($Method -eq 'GET') { return (& $MakeResponse 200 $CaCertsB64) }
                return (& $MakeResponse 200 $LeafP7B64)
            }
            $Pinned = $Authority.Clone(); $Pinned.CAThumbprint = $RootCert.Thumbprint.ToLower()
            $Result = InModuleScope AxisPowerShell -Parameters @{ Authority = $Pinned; Csr = $CsrPem } {
                Submit-AxisCsrToEST -Authority $Authority -Csr $Csr
            }
            $Result.Status | Should -Be 'Issued'
        }

        It "Throws when /simpleenroll is rejected" {
            Mock @m Invoke-WebRequest {
                if($Method -eq 'GET') { return (& $MakeResponse 200 $CaCertsB64) }
                Throw "Response status code does not indicate success: 401 (Unauthorized)."
            }
            { InModuleScope AxisPowerShell -Parameters @{ Authority = $Authority; Csr = $CsrPem } {
                Submit-AxisCsrToEST -Authority $Authority -Csr $Csr
            } } | Should -Throw "EST /simpleenroll failed on TestEST*401*"
        }

        It "Throws when no credential and no client certificate are configured" {
            Mock @m Get-StoredCredential { $null }
            Mock @m Invoke-WebRequest { return (& $MakeResponse 200 $CaCertsB64) }
            { InModuleScope AxisPowerShell -Parameters @{ Authority = $Authority; Csr = $CsrPem } {
                Submit-AxisCsrToEST -Authority $Authority -Csr $Csr
            } } | Should -Throw "No credential found for target 'AxisPowershell-CA-TestEST'*"
        }

        It "Rejects a non-CSR PEM" {
            { InModuleScope AxisPowerShell -Parameters @{ Authority = $Authority; Csr = "-----BEGIN CERTIFICATE-----`nAAAA`n-----END CERTIFICATE-----" } {
                Submit-AxisCsrToEST -Authority $Authority -Csr $Csr
            } } | Should -Throw "Csr is not a PEM encoded certificate signing request"
        }
    }

    Context "Dogtag flavour" {
        BeforeAll {
            Mock @m Get-StoredCredential { $EstCredential }
            Mock @m Write-Log {}
            Mock @m Submit-AxisCsrToEST { [pscustomobject]@{ Certificate = 'PEM'; Chain = @(); Serial = '0102030405060708'; RequestId = 'X'; Status = 'Issued' } }
            Mock @m Invoke-WebRequest { (& $MakeResponse 200 '{"requestID":"7","requestStatus":"complete","operationResult":"success"}') }
            $Script:Dogtag = @{
                Name = 'Lab'
                Type = 'Dogtag'
                Server = 'https://pki.example.com:8443'
                Template = 'cameras'
                CredentialTarget = 'AxisPowershell-CA-Lab'
            }
        }

        It "Submit-AxisCsrToDogtag delegates to the EST backend with Type=EST and the same server" {
            InModuleScope AxisPowerShell -Parameters @{ Authority = $Dogtag; Csr = $CsrPem } {
                $null = Submit-AxisCsrToDogtag -Authority $Authority -Csr $Csr -Wait
            }
            Should @m -Invoke Submit-AxisCsrToEST -Exactly -Times 1 -ParameterFilter {
                $Authority.Type -eq 'EST' -and $Authority.Server -eq 'https://pki.example.com:8443' -and $Authority.Template -eq 'cameras' -and $Wait -eq $true
            }
        }

        It "Submit-AxisCsrToDogtag prefers EstServer when set" {
            $Separate = $Dogtag.Clone(); $Separate.EstServer = 'https://est.example.com:8443'
            InModuleScope AxisPowerShell -Parameters @{ Authority = $Separate; Csr = $CsrPem } {
                $null = Submit-AxisCsrToDogtag -Authority $Authority -Csr $Csr
            }
            Should @m -Invoke Submit-AxisCsrToEST -Times 1 -ParameterFilter { $Authority.Server -eq 'https://est.example.com:8443' }
        }

        It "Revoke-AxisCertificateOnDogtag POSTs {Reason} to /ca/rest/agent/certs/0x{serial}/revoke" {
            $Result = InModuleScope AxisPowerShell -Parameters @{ Authority = $Dogtag } {
                Revoke-AxisCertificateOnDogtag -Authority $Authority -Serial '0102030405060708' -Reason KeyCompromise
            }
            $Result | Should -BeTrue
            Should @m -Invoke Invoke-WebRequest -Exactly -Times 1 -ParameterFilter {
                $Method -eq 'POST' -and
                $Uri -eq 'https://pki.example.com:8443/ca/rest/agent/certs/0x0102030405060708/revoke' -and
                $ContentType -eq 'application/json' -and
                ($Body | ConvertFrom-Json).Reason -eq 'Key_Compromise' -and
                $Headers['Authorization'] -like 'Basic *'
            }
        }

        It "Revoke-AxisCertificateOnDogtag throws when the CA reports a failure" {
            Mock @m Invoke-WebRequest { (& $MakeResponse 200 '{"operationResult":"failure","errorMessage":"Certificate not found"}') }
            { InModuleScope AxisPowerShell -Parameters @{ Authority = $Dogtag } {
                Revoke-AxisCertificateOnDogtag -Authority $Authority -Serial 'FF'
            } } | Should -Throw "*operationResult 'failure'*Certificate not found*"
        }
    }

    Context "Revoke-AxisCertificateOnEST" {
        It "Throws because EST has no revocation" {
            { InModuleScope AxisPowerShell -Parameters @{ Authority = $Authority } {
                Revoke-AxisCertificateOnEST -Authority $Authority -Serial 'FF'
            } } | Should -Throw "EST does not define revocation; configure a Dogtag or Command authority for revocation"
        }

        It "Delegates to the Command backend when RevokeCommand is set" {
            Mock @m Revoke-AxisCertificateOnCommand { $true }
            $WithCmd = $Authority.Clone(); $WithCmd.RevokeCommand = 'openssl ca -revoke {Serial}'
            $Result = InModuleScope AxisPowerShell -Parameters @{ Authority = $WithCmd } {
                Revoke-AxisCertificateOnEST -Authority $Authority -Serial 'FF' -Reason Superseded
            }
            $Result | Should -BeTrue
            Should @m -Invoke Revoke-AxisCertificateOnCommand -Exactly -Times 1 -ParameterFilter { $Serial -eq 'FF' -and $Reason -eq 'Superseded' }
        }
    }

    Context "Test-AxisCertificateAuthorityEST" {
        BeforeAll {
            Mock @m Get-StoredCredential { $EstCredential }
        }

        It "Reports Reachable when /cacerts answers" {
            Mock @m Invoke-WebRequest { (& $MakeResponse 200 $CaCertsB64) }
            $Result = InModuleScope AxisPowerShell -Parameters @{ Authority = $Authority } {
                Test-AxisCertificateAuthorityEST -Authority $Authority
            }
            $Result.Reachable | Should -BeTrue
            $Result.Message | Should -Match '1 CA certificate'
            $Result.Message | Should -Match "credential 'AxisPowershell-CA-TestEST' present"
        }

        It "Reports not Reachable when /cacerts fails" {
            Mock @m Invoke-WebRequest { Throw "No such host is known" }
            $Result = InModuleScope AxisPowerShell -Parameters @{ Authority = $Authority } {
                Test-AxisCertificateAuthorityEST -Authority $Authority
            }
            $Result.Reachable | Should -BeFalse
            $Result.Message | Should -Match 'No such host'
        }

        It "Test-AxisCertificateAuthorityDogtag combines CA info and the EST check" {
            Mock @m Invoke-WebRequest {
                if($Uri -like '*/pki/rest/info') { return (& $MakeResponse 200 '{"Name":"CA","Version":"11.6.0"}') }
                return (& $MakeResponse 200 $CaCertsB64)
            }
            $Dogtag = @{ Name = 'Lab'; Type = 'Dogtag'; Server = 'https://pki.example.com:8443'; CredentialTarget = 'AxisPowershell-CA-Lab' }
            $Result = InModuleScope AxisPowerShell -Parameters @{ Authority = $Dogtag } {
                Test-AxisCertificateAuthorityDogtag -Authority $Authority
            }
            $Result.Reachable | Should -BeTrue
            $Result.Message | Should -Match 'version 11.6.0'
            $Result.Message | Should -Match 'EST: 1 CA certificate'
        }
    }
}

BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

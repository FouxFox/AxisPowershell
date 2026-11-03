BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

Describe "Submit-AxisCsrToWindowsCA" {
    BeforeAll {
        #Pester helpers: real certificates created in memory (never written to disk, no openssl).
        function Global:New-TestCert {
            param([string]$Subject, [System.Security.Cryptography.X509Certificates.X509Certificate2]$Issuer)
            $Rsa = [System.Security.Cryptography.RSA]::Create(2048)
            $Req = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest(
                $Subject, $Rsa, [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
            if($Issuer) {
                $Serial = New-Object byte[] 8
                (New-Object System.Random).NextBytes($Serial)
                $Serial[0] = $Serial[0] -band 0x7F
                $Cert = $Req.Create($Issuer, (Get-Date).AddDays(-1), (Get-Date).AddDays(30), $Serial)
            }
            else {
                $Req.CertificateExtensions.Add((New-Object System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension($true,$false,0,$true)))
                $Cert = $Req.CreateSelfSigned((Get-Date).AddDays(-1), (Get-Date).AddDays(365))
            }
            #Keys stay in memory only (needed on the root to sign the leaf); never exported or written
            return $Cert
        }
        function Global:ConvertTo-TestPem {
            param([byte[]]$Bytes, [string]$Label)
            $B64 = [Convert]::ToBase64String($Bytes) -replace '(.{64})',"`$1`n"
            return "-----BEGIN $Label-----`n$($B64.TrimEnd("`n"))`n-----END $Label-----"
        }

        $SigningRoot = New-TestCert -Subject "CN=Test Root CA"
        #Public-only copies are what the module sees
        $Script:TestRoot = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,$SigningRoot.Export('Cert'))
        $Script:TestLeaf = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,(New-TestCert -Subject "CN=camera01.example.com" -Issuer $SigningRoot).Export('Cert'))
        $Script:LeafPem = ConvertTo-TestPem -Bytes $Script:TestLeaf.RawData -Label "CERTIFICATE"
        $Collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        [void]$Collection.Add($Script:TestLeaf)
        [void]$Collection.Add($Script:TestRoot)
        $Script:P7Pem = ConvertTo-TestPem -Bytes $Collection.Export('Pkcs7') -Label "PKCS7"
        $Script:TestCsr = "-----BEGIN CERTIFICATE REQUEST-----`nMIIBADCB`n-----END CERTIFICATE REQUEST-----"
        $Script:Authority = @{ Type='WindowsCA'; CAConfig='ca01.example.com\Example Issuing CA'; Template='AxisCamera'; PollSeconds=1; TimeoutSec=3 }

        #The PEM helpers are written by another part of the feature; provide minimal stand-ins in module
        #scope if they are not loaded yet so this file is self-contained.
        & (Get-Module AxisPowerShell) {
            if(!(Get-Command ConvertFrom-PemString -ErrorAction SilentlyContinue)) {
                Set-Item function:script:ConvertFrom-PemString {
                    param([string]$Pem, [switch]$AsCertificate)
                    $Out = @()
                    foreach($m in [regex]::Matches($Pem, '-----BEGIN ([^-]+)-----(.*?)-----END \1-----', 'Singleline')) {
                        $Bytes = [Convert]::FromBase64String(($m.Groups[2].Value -replace '\s',''))
                        if($AsCertificate) { $Out += New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,$Bytes) }
                        else { $Out += [pscustomobject]@{ Label=$m.Groups[1].Value; Bytes=$Bytes; Pem=$m.Value } }
                    }
                    return $Out
                }
            }
            if(!(Get-Command ConvertTo-PemString -ErrorAction SilentlyContinue)) {
                Set-Item function:script:ConvertTo-PemString {
                    param([byte[]]$Bytes, $Certificate, [string]$Label="CERTIFICATE")
                    if($Certificate) { $Bytes = $Certificate.RawData }
                    $B64 = [Convert]::ToBase64String($Bytes) -replace '(.{64})',"`$1`n"
                    return "-----BEGIN $Label-----`n$($B64.TrimEnd("`n"))`n-----END $Label-----"
                }
            }
        }

        #Fake ICertRequest2 COM object. $Script:FakeCA drives dispositions; calls are recorded.
        function Global:New-FakeCertRequest {
            param([int[]]$Dispositions, [string]$Leaf, [string]$P7, [string]$Message="ok")
            $Obj = [pscustomobject]@{ Dispositions = [System.Collections.ArrayList]@($Dispositions); Calls = [System.Collections.ArrayList]@(); Leaf=$Leaf; P7=$P7; Message=$Message }
            $Obj | Add-Member ScriptMethod Submit { param($Flags,$Request,$Attributes,$Config)
                [void]$this.Calls.Add(@{ Method='Submit'; Flags=$Flags; Request=$Request; Attributes=$Attributes; Config=$Config })
                $d = $this.Dispositions[0]; $this.Dispositions.RemoveAt(0); return $d }
            $Obj | Add-Member ScriptMethod RetrievePending { param($Id,$Config)
                [void]$this.Calls.Add(@{ Method='RetrievePending'; Id=$Id; Config=$Config })
                $d = $this.Dispositions[0]; $this.Dispositions.RemoveAt(0); return $d }
            $Obj | Add-Member ScriptMethod GetRequestId { return 4711 }
            $Obj | Add-Member ScriptMethod GetDispositionMessage { return $this.Message }
            $Obj | Add-Member ScriptMethod GetCertificate { param($Flags)
                [void]$this.Calls.Add(@{ Method='GetCertificate'; Flags=$Flags })
                if($Flags -band 0x100) { if(!$this.P7) { Throw "no chain" } ; return $this.P7 }
                return $this.Leaf }
            $Obj | Add-Member ScriptMethod GetCACertificate { param($Exchange,$Config,$Flags)
                [void]$this.Calls.Add(@{ Method='GetCACertificate'; Config=$Config })
                return $Script:RootPem }
            $Obj | Add-Member ScriptMethod GetCAProperty { param($Config,$PropId,$Index,$PropType,$Flags)
                [void]$this.Calls.Add(@{ Method='GetCAProperty'; PropId=$PropId; Config=$Config })
                if($PropId -eq 6) { return "Example Issuing CA" }
                if($PropId -eq 29) { return "AxisCamera`n1.3.6.1.4.1.311.21.8.1.2`nWebServer`n1.3.6.1.4.1.311.21.8.1.3`n" }
                return "" }
            return $Obj
        }
        $Script:RootPem = ConvertTo-TestPem -Bytes $Script:TestRoot.RawData -Label "CERTIFICATE"
    }

    AfterAll {
        Remove-Item Function:\New-TestCert, Function:\ConvertTo-TestPem, Function:\New-FakeCertRequest -ErrorAction SilentlyContinue
    }

    Context "Issued immediately" {
        BeforeAll {
            Mock @m Write-Log {}
            Mock @m Start-Sleep {}
            $Script:Fake = New-FakeCertRequest -Dispositions @(3) -Leaf $Script:LeafPem -P7 $Script:P7Pem
            Mock @m New-AxisComObject { $Script:Fake }
            $Script:Result = InModuleScope AxisPowerShell -Parameters @{ A=$Script:Authority; C=$Script:TestCsr } {
                Submit-AxisCsrToWindowsCA -Authority $A -Csr $C -Device "camera01"
            }
            $Script:SubmitCall = $Script:Fake.Calls | Where-Object { $_.Method -eq 'Submit' }
        }

        It "Creates the CertificateAuthority.Request COM object" {
            Should @m -Scope Context -Invoke New-AxisComObject -Exactly -Times 1 -ParameterFilter { $ProgId -eq "CertificateAuthority.Request" }
        }
        It "Submits with CR_IN_BASE64HEADER|CR_IN_PKCS10 (0x100)" {
            $Script:SubmitCall.Flags | Should -Be 0x100
        }
        It "Passes the CSR, template attribute and CA config" {
            $Script:SubmitCall.Request | Should -Be $Script:TestCsr
            $Script:SubmitCall.Attributes | Should -Be "CertificateTemplate:AxisCamera"
            $Script:SubmitCall.Config | Should -Be 'ca01.example.com\Example Issuing CA'
        }
        It "Returns Status Issued with the request id" {
            $Script:Result.Status | Should -Be "Issued"
            $Script:Result.RequestId | Should -Be "4711"
        }
        It "Returns the leaf certificate as PEM" {
            $Script:Result.Certificate | Should -Match '^-----BEGIN CERTIFICATE-----'
            $Parsed = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,[Convert]::FromBase64String(($Script:Result.Certificate -replace '-----[^-]+-----','' -replace '\s','')))
            $Parsed.Thumbprint | Should -Be $Script:TestLeaf.Thumbprint
        }
        It "Returns the serial as uppercase hex without separators" {
            $Script:Result.Serial | Should -Be $Script:TestLeaf.SerialNumber.ToUpper()
            $Script:Result.Serial | Should -Match '^[0-9A-F]+$'
        }
        It "Returns the CA chain from the PKCS#7 without the leaf" {
            @($Script:Result.Chain).Count | Should -Be 1
            $Parsed = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,[Convert]::FromBase64String(($Script:Result.Chain[0] -replace '-----[^-]+-----','' -replace '\s','')))
            $Parsed.Thumbprint | Should -Be $Script:TestRoot.Thumbprint
        }
        It "Does not poll" {
            Should @m -Scope Context -Invoke Start-Sleep -Exactly -Times 0
        }
    }

    Context "Chain fallback to GetCACertificate" {
        BeforeAll {
            Mock @m Write-Log {}
            $Script:Fake = New-FakeCertRequest -Dispositions @(3) -Leaf $Script:LeafPem -P7 ""
            Mock @m New-AxisComObject { $Script:Fake }
            $Script:Result = InModuleScope AxisPowerShell -Parameters @{ A=$Script:Authority; C=$Script:TestCsr } {
                Submit-AxisCsrToWindowsCA -Authority $A -Csr $C
            }
        }
        It "Uses GetCACertificate when the PKCS#7 is unavailable" {
            @($Script:Fake.Calls | Where-Object { $_.Method -eq 'GetCACertificate' }).Count | Should -Be 1
            @($Script:Result.Chain).Count | Should -Be 1
            $Script:Result.Chain[0] | Should -Be $Script:RootPem
        }
    }

    Context "Pending then issued" {
        BeforeAll {
            Mock @m Write-Log {}
            Mock @m Start-Sleep {}
            $Script:Fake = New-FakeCertRequest -Dispositions @(5,5,3) -Leaf $Script:LeafPem -P7 $Script:P7Pem
            Mock @m New-AxisComObject { $Script:Fake }
            $Script:Result = InModuleScope AxisPowerShell -Parameters @{ A=$Script:Authority; C=$Script:TestCsr } {
                Submit-AxisCsrToWindowsCA -Authority $A -Csr $C
            }
        }
        It "Polls RetrievePending with the request id until issued" {
            $Polls = @($Script:Fake.Calls | Where-Object { $_.Method -eq 'RetrievePending' })
            $Polls.Count | Should -Be 2
            $Polls[0].Id | Should -Be 4711
            $Polls[0].Config | Should -Be 'ca01.example.com\Example Issuing CA'
            Should @m -Scope Context -Invoke Start-Sleep -Exactly -Times 2 -ParameterFilter { $Seconds -eq 1 }
            $Script:Result.Status | Should -Be "Issued"
        }
    }

    Context "Pending with -NoWait" {
        BeforeAll {
            Mock @m Write-Log {}
            Mock @m Start-Sleep {}
            $Script:Fake = New-FakeCertRequest -Dispositions @(5) -Leaf $Script:LeafPem -P7 $Script:P7Pem
            Mock @m New-AxisComObject { $Script:Fake }
            $Script:Result = InModuleScope AxisPowerShell -Parameters @{ A=$Script:Authority; C=$Script:TestCsr } {
                Submit-AxisCsrToWindowsCA -Authority $A -Csr $C -NoWait
            }
        }
        It "Returns Status Pending with RequestId and no certificate" {
            $Script:Result.Status | Should -Be "Pending"
            $Script:Result.RequestId | Should -Be "4711"
            $Script:Result.Certificate | Should -BeNullOrEmpty
            Should @m -Scope Context -Invoke Start-Sleep -Exactly -Times 0
        }
    }

    Context "Pending timeout" {
        BeforeAll {
            Mock @m Write-Log {}
            Mock @m Start-Sleep {}
            $Script:Fake = New-FakeCertRequest -Dispositions @(5,5,5,5,5,5,5,5,5,5,5,5) -Leaf $Script:LeafPem -P7 $Script:P7Pem
            Mock @m New-AxisComObject { $Script:Fake }
        }
        It "Throws the pending-approval message after TimeoutSec" {
            { InModuleScope AxisPowerShell -Parameters @{ A=$Script:Authority; C=$Script:TestCsr } {
                Submit-AxisCsrToWindowsCA -Authority $A -Csr $C -TimeoutSec 0
            } } | Should -Throw "*request 4711 is pending approval on ca01.example.com\Example Issuing CA*"
        }
    }

    Context "Denied and error dispositions" {
        BeforeAll {
            Mock @m Write-Log {}
        }
        It "Throws with the disposition message when denied (2)" {
            $Script:Fake = New-FakeCertRequest -Dispositions @(2) -Message "Denied by Policy Module" -Leaf $Script:LeafPem
            Mock @m New-AxisComObject { $Script:Fake }
            { InModuleScope AxisPowerShell -Parameters @{ A=$Script:Authority; C=$Script:TestCsr } {
                Submit-AxisCsrToWindowsCA -Authority $A -Csr $C
            } } | Should -Throw "*denied*Denied by Policy Module*"
        }
        It "Throws with the disposition message on error (1)" {
            $Script:Fake = New-FakeCertRequest -Dispositions @(1) -Message "The request subject name is invalid" -Leaf $Script:LeafPem
            Mock @m New-AxisComObject { $Script:Fake }
            { InModuleScope AxisPowerShell -Parameters @{ A=$Script:Authority; C=$Script:TestCsr } {
                Submit-AxisCsrToWindowsCA -Authority $A -Csr $C
            } } | Should -Throw "*failed*subject name is invalid*"
        }
        It "Throws when the authority has no Template" {
            { InModuleScope AxisPowerShell -Parameters @{ C=$Script:TestCsr } {
                Submit-AxisCsrToWindowsCA -Authority @{ Type='WindowsCA'; CAConfig='x\y' } -Csr $C
            } } | Should -Throw "*Template*"
        }
    }

    Context "Revoke-AxisCertificateOnWindowsCA" {
        BeforeAll {
            Mock @m Write-Log {}
            $Script:Admin = [pscustomobject]@{ Calls = [System.Collections.ArrayList]@() }
            $Script:Admin | Add-Member ScriptMethod RevokeCertificate { param($Config,$Serial,$Reason,$Date)
                [void]$this.Calls.Add(@{ Config=$Config; Serial=$Serial; Reason=$Reason; Date=$Date }) }
            Mock @m New-AxisComObject { $Script:Admin }
            $Script:Result = InModuleScope AxisPowerShell -Parameters @{ A=$Script:Authority } {
                Revoke-AxisCertificateOnWindowsCA -Authority $A -Serial "1a:2b:3c" -Reason KeyCompromise
            }
        }
        It "Creates the CertificateAuthority.Admin COM object" {
            Should @m -Scope Context -Invoke New-AxisComObject -Exactly -Times 1 -ParameterFilter { $ProgId -eq "CertificateAuthority.Admin" }
        }
        It "Calls RevokeCertificate with normalised serial, reason code and Date 0" {
            $Script:Admin.Calls.Count | Should -Be 1
            $Script:Admin.Calls[0].Config | Should -Be 'ca01.example.com\Example Issuing CA'
            $Script:Admin.Calls[0].Serial | Should -Be "1A2B3C"
            $Script:Admin.Calls[0].Reason | Should -Be 1
            $Script:Admin.Calls[0].Date | Should -Be 0
            $Script:Result | Should -BeTrue
        }
        It "Maps the remaining reason codes and pads odd-length serials" {
            $Script:Admin.Calls.Clear()
            InModuleScope AxisPowerShell -Parameters @{ A=$Script:Authority } {
                Revoke-AxisCertificateOnWindowsCA -Authority $A -Serial "ABC" | Out-Null
                Revoke-AxisCertificateOnWindowsCA -Authority $A -Serial "ABCD" -Reason CessationOfOperation | Out-Null
                Revoke-AxisCertificateOnWindowsCA -Authority $A -Serial "ABCD" -Reason Unspecified | Out-Null
            }
            $Script:Admin.Calls[0].Serial | Should -Be "0ABC"
            $Script:Admin.Calls[0].Reason | Should -Be 4
            $Script:Admin.Calls[1].Reason | Should -Be 5
            $Script:Admin.Calls[2].Reason | Should -Be 0
        }
        It "Throws when the CA rejects the revocation" {
            $Bad = [pscustomobject]@{}
            $Bad | Add-Member ScriptMethod RevokeCertificate { Throw "CERTSRV_E_PROPERTY_EMPTY" }
            Mock @m New-AxisComObject { $Bad }
            { InModuleScope AxisPowerShell -Parameters @{ A=$Script:Authority } {
                Revoke-AxisCertificateOnWindowsCA -Authority $A -Serial "ABCD"
            } } | Should -Throw "*Failed to revoke certificate ABCD*"
        }
    }

    Context "Test-AxisCertificateAuthorityWindowsCA" {
        BeforeAll {
            $Script:Fake = New-FakeCertRequest -Dispositions @() -Leaf ""
            Mock @m New-AxisComObject { $Script:Fake }
        }
        It "Reports Reachable with CA name and published template" {
            $R = InModuleScope AxisPowerShell -Parameters @{ A=$Script:Authority } { Test-AxisCertificateAuthorityWindowsCA -Authority $A }
            $R.Reachable | Should -BeTrue
            $R.Message | Should -Match "Example Issuing CA"
            $R.Message | Should -Match "template 'AxisCamera' is published"
        }
        It "Warns when the template is not published" {
            $A2 = @{ Type='WindowsCA'; CAConfig='ca01.example.com\Example Issuing CA'; Template='Nope' }
            $R = InModuleScope AxisPowerShell -Parameters @{ A=$A2 } { Test-AxisCertificateAuthorityWindowsCA -Authority $A }
            $R.Reachable | Should -BeTrue
            $R.Message | Should -Match "WARNING template 'Nope'"
        }
        It "Reports unreachable when COM is unavailable" {
            Mock @m New-AxisComObject { Throw "COM object CertificateAuthority.Request requires Windows" }
            $R = InModuleScope AxisPowerShell -Parameters @{ A=$Script:Authority } { Test-AxisCertificateAuthorityWindowsCA -Authority $A }
            $R.Reachable | Should -BeFalse
            $R.Message | Should -Match "requires Windows"
        }
    }

    Context "New-AxisComObject platform guard" {
        It "Throws a clear message on non-Windows hosts" -Skip:($PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows) {
            { InModuleScope AxisPowerShell { New-AxisComObject -ProgId "CertificateAuthority.Request" } } | Should -Throw "*requires Windows*"
        }
    }
}

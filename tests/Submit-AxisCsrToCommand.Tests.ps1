Describe "Submit-AxisCsrToCommand" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll

        #Fallback PEM helpers so this file runs even before the shared helpers land in the module
        InModuleScope AxisPowerShell {
            if(!(Get-Command ConvertFrom-PemString -ErrorAction SilentlyContinue)) {
                function Script:ConvertFrom-PemString {
                    Param([Parameter(Mandatory)][String]$Pem,[Switch]$AsCertificate)
                    $Blocks = [regex]::Matches($Pem,"-----BEGIN ([A-Z ]+)-----(.*?)-----END \1-----","Singleline") | ForEach-Object {
                        $Bytes = [Convert]::FromBase64String(($_.Groups[2].Value -replace "\s",""))
                        [pscustomobject]@{ Label = $_.Groups[1].Value; Bytes = $Bytes; Pem = $_.Value }
                    }
                    if($AsCertificate) {
                        return @($Blocks | Where-Object Label -eq "CERTIFICATE" | ForEach-Object { New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 (,$_.Bytes) })
                    }
                    return $Blocks
                }
            }
            if(!(Get-Command ConvertTo-PemString -ErrorAction SilentlyContinue)) {
                function Script:ConvertTo-PemString {
                    Param([Byte[]]$Bytes,[System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,[String]$Label="CERTIFICATE")
                    if($Certificate) { $Bytes = $Certificate.Export("Cert") }
                    $B64 = [Convert]::ToBase64String($Bytes)
                    $Lines = for($i=0;$i -lt $B64.Length;$i+=64) { $B64.Substring($i,[Math]::Min(64,$B64.Length-$i)) }
                    return "-----BEGIN $Label-----`n$($Lines -join "`n")`n-----END $Label-----`n"
                }
            }
        }

        #In-memory self-signed certificates (CertificateRequest, .NET 4.7.2+/.NET 8). Keys never leave memory.
        function Global:New-TestCertPem {
            Param([String]$Subject)
            $Key = [System.Security.Cryptography.RSA]::Create(2048)
            Try {
                $Request = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest (
                    $Subject, $Key,
                    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                    [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
                $Cert = $Request.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1),[DateTimeOffset]::UtcNow.AddDays(30))
                $B64 = [Convert]::ToBase64String($Cert.Export("Cert"))
                $Lines = for($i=0;$i -lt $B64.Length;$i+=64) { $B64.Substring($i,[Math]::Min(64,$B64.Length-$i)) }
                [pscustomobject]@{
                    Pem = "-----BEGIN CERTIFICATE-----`n$($Lines -join "`n")`n-----END CERTIFICATE-----`n"
                    Serial = $Cert.SerialNumber.ToUpper()
                    Subject = $Cert.Subject
                }
            }
            Finally { $Key.Dispose() }
        }

        $Global:TestLeaf = New-TestCertPem -Subject "CN=camera01.example.com"
        $Global:TestIssuer = New-TestCertPem -Subject "CN=Test Issuing CA"
        #A syntactically valid PEM CSR body; the content is never parsed by the function under test
        $Global:TestCsr = "-----BEGIN CERTIFICATE REQUEST-----`nMIIBWjCB" + ("A" * 60) + "`n-----END CERTIFICATE REQUEST-----`n"

        #Fake CA: a .ps1 that behaves like "openssl ca": writes a text dump + leaf + issuer to {CertFile}
        $Global:FakeCaDir = Join-Path ([System.IO.Path]::GetTempPath()) "AxisPsFakeCa-$([guid]::NewGuid().ToString('N'))"
        $null = New-Item -ItemType Directory -Path $FakeCaDir -Force
        $Global:FakeCertPath = Join-Path $FakeCaDir "issued.pem"
        Set-Content -Path $FakeCertPath -Value ("Certificate:`n    Data:`n        Version: 3`n" + $TestLeaf.Pem + $TestIssuer.Pem) -NoNewline
        $Global:FakeCaScript = Join-Path $FakeCaDir "fakeca.ps1"
        $FakeCa = @'
Param([String]$In,[String]$Out,[String]$Fail)
if(!(Test-Path $In)) { [Console]::Error.WriteLine("CSR file missing: $In"); exit 2 }
if((Get-Content $In -Raw) -notmatch "BEGIN CERTIFICATE REQUEST") { [Console]::Error.WriteLine("not a CSR"); exit 3 }
if($Fail) { [Console]::Error.WriteLine("fake CA refused: $Fail"); exit 1 }
Copy-Item -Path "__CERT__" -Destination $Out
Write-Output "Signed"
exit 0
'@
        Set-Content -Path $FakeCaScript -Value $FakeCa.Replace("__CERT__",$FakeCertPath)
        $Global:PwshExe = (Get-Process -Id $PID).Path
        $Global:FakeSignCommand = "`"$PwshExe`" -NoProfile -NonInteractive -File `"$FakeCaScript`" -In {CsrFile} -Out {CertFile}"
    }

    AfterAll {
        Remove-Item $Global:FakeCaDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item Function:\New-TestCertPem -ErrorAction SilentlyContinue
        'TestLeaf','TestIssuer','TestCsr','FakeCaDir','FakeCertPath','FakeCaScript','PwshExe','FakeSignCommand' | ForEach-Object {
            Remove-Variable $_ -Scope Global -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Round trip with a fake CA process (no mocks)" {
        It "Signs a CSR and returns leaf, chain and serial" {
            $Authority = @{ Type = 'Command'; SignCommand = $FakeSignCommand; TimeoutSec = 60 }
            $Result = InModuleScope AxisPowerShell -Parameters @{ A = $Authority; C = $TestCsr } {
                Submit-AxisCsrToCommand -Authority $A -Csr $C -Device "192.168.0.100"
            }
            $Result.Status | Should -Be 'Issued'
            $Result.RequestId | Should -BeNullOrEmpty
            $Result.Serial | Should -Be $TestLeaf.Serial
            $Result.Certificate | Should -Match "-----BEGIN CERTIFICATE-----"
            ($Result.Certificate -replace "\s","") | Should -Be ($TestLeaf.Pem -replace "\s","")
            @($Result.Chain).Count | Should -Be 1
            (@($Result.Chain)[0] -replace "\s","") | Should -Be ($TestIssuer.Pem -replace "\s","")
        }

        It "Removes its temporary directory afterwards" {
            $Before = @(Get-ChildItem ([System.IO.Path]::GetTempPath()) -Directory -Filter "AxisPowershell-*").Count
            $Authority = @{ Type = 'Command'; SignCommand = $FakeSignCommand }
            $null = InModuleScope AxisPowerShell -Parameters @{ A = $Authority; C = $TestCsr } {
                Submit-AxisCsrToCommand -Authority $A -Csr $C
            }
            @(Get-ChildItem ([System.IO.Path]::GetTempPath()) -Directory -Filter "AxisPowershell-*").Count | Should -Be $Before
        }

        It "Throws with stderr when the command exits non-zero" {
            $Authority = @{ Type = 'Command'; SignCommand = "$FakeSignCommand -Fail policy" }
            {
                InModuleScope AxisPowerShell -Parameters @{ A = $Authority; C = $TestCsr } {
                    Submit-AxisCsrToCommand -Authority $A -Csr $C
                }
            } | Should -Throw "*exit code 1*fake CA refused: policy*"
        }

        It "Throws when the command does not produce a certificate" {
            $Authority = @{ Type = 'Command'; SignCommand = "`"$PwshExe`" -NoProfile -c exit 0" }
            {
                InModuleScope AxisPowerShell -Parameters @{ A = $Authority; C = $TestCsr } {
                    Submit-AxisCsrToCommand -Authority $A -Csr $C
                }
            } | Should -Throw "*did not write a certificate*"
        }

        It "Honours TimeoutSec" {
            $Authority = @{ Type = 'Command'; SignCommand = "`"$PwshExe`" -NoProfile -c Start-Sleep 20"; TimeoutSec = 2 }
            {
                InModuleScope AxisPowerShell -Parameters @{ A = $Authority; C = $TestCsr } {
                    Submit-AxisCsrToCommand -Authority $A -Csr $C
                }
            } | Should -Throw "*timed out after 2 seconds*"
        }
    }

    Context "Input validation" {
        It "Throws when SignCommand is missing" {
            {
                InModuleScope AxisPowerShell -Parameters @{ C = $TestCsr } {
                    Submit-AxisCsrToCommand -Authority @{ Type = 'Command' } -Csr $C
                }
            } | Should -Throw "*no SignCommand*"
        }

        It "Throws when Csr is not a PEM request" {
            {
                InModuleScope AxisPowerShell {
                    Submit-AxisCsrToCommand -Authority @{ Type = 'Command'; SignCommand = "x {CertFile}" } -Csr "garbage"
                }
            } | Should -Throw "*not a PEM encoded certificate signing request*"
        }
    }

    Context "SSH mode (Start-Process mocked)" {
        BeforeAll {
            $Global:SshCalls = [System.Collections.ArrayList]::new()
        }
        AfterAll { Remove-Variable SshCalls -Scope Global -Force -ErrorAction SilentlyContinue }

        It "Uploads the CSR, runs the command through ssh, downloads the cert and cleans up" {
            $Global:SshCalls.Clear()
            Mock @m Start-Process {
                $null = $Global:SshCalls.Add([pscustomobject]@{ FilePath = $FilePath; Args = @($ArgumentList); StdIn = $RedirectStandardInput })
                #scp download: fake the cert arriving
                if($FilePath -eq 'scp' -and $ArgumentList[-1] -notmatch '@') {
                    Set-Content -Path $ArgumentList[-1] -Value $Global:TestLeaf.Pem -NoNewline
                }
                if($RedirectStandardInput) {
                    $Global:SshScript = Get-Content $RedirectStandardInput -Raw
                }
                Set-Content -Path $RedirectStandardOutput -Value ""
                Set-Content -Path $RedirectStandardError -Value ""
                $P = [pscustomobject]@{ ExitCode = 0; Handle = 1 }
                $P | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { Param($ms) return $true }
                $P | Add-Member -MemberType ScriptMethod -Name Kill -Value { }
                return $P
            }

            $Authority = @{
                Type = 'Command'
                SignCommand = "openssl ca -batch -notext -config /etc/pki/ca/openssl.cnf -in {CsrFile} -out {CertFile}"
                SshHost = "ca.example.com"
                SshUser = "pki"
                SshKeyFile = "/home/user/.ssh/id_ed25519"
                WorkingDirectory = "/etc/pki/ca"
            }
            $Result = InModuleScope AxisPowerShell -Parameters @{ A = $Authority; C = $TestCsr } {
                Submit-AxisCsrToCommand -Authority $A -Csr $C -Device "cam01"
            }

            $Result.Serial | Should -Be $TestLeaf.Serial
            @($Result.Chain).Count | Should -Be 0

            $Calls = @($Global:SshCalls)
            $Calls.Count | Should -Be 4
            $Calls[0].FilePath | Should -Be 'scp'
            $Calls[0].Args[-1] | Should -Match '^pki@ca\.example\.com:/tmp/axisps-[0-9a-f]{32}\.csr$'
            $Calls[0].Args | Should -Contain '/home/user/.ssh/id_ed25519'
            $Calls[0].Args | Should -Contain 'BatchMode=yes'
            $Calls[1].FilePath | Should -Be 'ssh'
            $Calls[1].Args[-3..-1] | Should -Be @('pki@ca.example.com','sh','-s')
            $Calls[1].StdIn | Should -Not -BeNullOrEmpty
            $Global:SshScript | Should -Match "cd '/etc/pki/ca'"
            $Global:SshScript | Should -Match "openssl ca -batch -notext -config /etc/pki/ca/openssl.cnf -in /tmp/axisps-[0-9a-f]{32}\.csr -out /tmp/axisps-[0-9a-f]{32}\.crt"
            $Calls[2].FilePath | Should -Be 'scp'
            $Calls[2].Args[-2] | Should -Match '^pki@ca\.example\.com:/tmp/axisps-[0-9a-f]{32}\.crt$'
            $Calls[3].FilePath | Should -Be 'ssh'
            $Calls[3].Args[-4..-1] | Should -Match '^(rm|-f|/tmp/axisps-[0-9a-f]{32}\.(csr|crt))$'
        }

        It "Still cleans up remotely when the sign command fails" {
            $Global:SshCalls.Clear()
            Mock @m Start-Process {
                $null = $Global:SshCalls.Add([pscustomobject]@{ FilePath = $FilePath; Args = @($ArgumentList) })
                Set-Content -Path $RedirectStandardOutput -Value ""
                $Code = 0
                if($FilePath -eq 'ssh' -and $ArgumentList[-1] -eq '-s') {
                    Set-Content -Path $RedirectStandardError -Value "unable to load CA private key"
                    $Code = 1
                }
                else { Set-Content -Path $RedirectStandardError -Value "" }
                $P = [pscustomobject]@{ ExitCode = $Code; Handle = 1 }
                $P | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { Param($ms) return $true }
                $P | Add-Member -MemberType ScriptMethod -Name Kill -Value { }
                return $P
            }
            $Authority = @{ Type = 'Command'; SignCommand = "openssl ca -in {CsrFile} -out {CertFile}"; SshHost = "ca.example.com" }
            {
                InModuleScope AxisPowerShell -Parameters @{ A = $Authority; C = $TestCsr } {
                    Submit-AxisCsrToCommand -Authority $A -Csr $C
                }
            } | Should -Throw "*exit code 1*unable to load CA private key*"
            $Calls = @($Global:SshCalls)
            $Calls.Count | Should -Be 3
            $Calls[2].Args | Should -Contain 'rm'
        }
    }

    Context "Revoke-AxisCertificateOnCommand" {
        It "Expands {Serial} and {Reason} and runs the command" {
            $Marker = Join-Path $FakeCaDir "revoked.txt"
            $Authority = @{
                Type = 'Command'
                RevokeCommand = "`"$PwshExe`" -NoProfile -c `"Set-Content -Path '$Marker' -Value '{Serial} {Reason} {Device}'`""
            }
            $Result = InModuleScope AxisPowerShell -Parameters @{ A = $Authority } {
                Revoke-AxisCertificateOnCommand -Authority $A -Serial "0a1b2c" -Reason KeyCompromise -Device "cam01"
            }
            $Result | Should -BeTrue
            (Get-Content $Marker -Raw).Trim() | Should -Be "0A1B2C keyCompromise cam01"
        }

        It "Throws when no RevokeCommand is configured" {
            {
                InModuleScope AxisPowerShell {
                    Revoke-AxisCertificateOnCommand -Authority @{ Type = 'Command' } -Serial "01"
                }
            } | Should -Throw "*no RevokeCommand*"
        }

        It "Throws with stderr on failure" {
            $Authority = @{ Type = 'Command'; RevokeCommand = "`"$PwshExe`" -NoProfile -c `"[Console]::Error.WriteLine('already revoked'); exit 4`"" }
            {
                InModuleScope AxisPowerShell -Parameters @{ A = $Authority } {
                    Revoke-AxisCertificateOnCommand -Authority $A -Serial "01"
                }
            } | Should -Throw "*exit code 4*already revoked*"
        }
    }

    Context "Test-AxisCertificateAuthorityCommand" {
        It "Rejects a definition without SignCommand" {
            $R = InModuleScope AxisPowerShell { Test-AxisCertificateAuthorityCommand -Authority @{ Type = 'Command' } }
            $R.Reachable | Should -BeFalse
            $R.Message | Should -Match "SignCommand"
        }

        It "Rejects unknown tokens" {
            $R = InModuleScope AxisPowerShell { Test-AxisCertificateAuthorityCommand -Authority @{ Type = 'Command'; SignCommand = "x {CertFile} {Bogus}" } }
            $R.Reachable | Should -BeFalse
            $R.Message | Should -Match "Bogus"
        }

        It "Rejects a missing SshKeyFile" {
            $R = InModuleScope AxisPowerShell { Test-AxisCertificateAuthorityCommand -Authority @{ Type = 'Command'; SignCommand = "x {CsrFile} {CertFile}"; SshHost = "h"; SshKeyFile = "/nonexistent/key" } }
            $R.Reachable | Should -BeFalse
            $R.Message | Should -Match "SshKeyFile"
        }

        It "Passes a local definition without TestCommand statically" {
            $R = InModuleScope AxisPowerShell { Test-AxisCertificateAuthorityCommand -Authority @{ Type = 'Command'; SignCommand = "x {CsrFile} {CertFile}" } }
            $R.Reachable | Should -BeTrue
            $R.Message | Should -Match "not executed"
        }

        It "Runs TestCommand and reports success" {
            $Authority = @{ Type = 'Command'; SignCommand = "x {CsrFile} {CertFile}"; TestCommand = "`"$PwshExe`" -NoProfile -c `"Write-Output ready`"" }
            $R = InModuleScope AxisPowerShell -Parameters @{ A = $Authority } { Test-AxisCertificateAuthorityCommand -Authority $A }
            $R.Reachable | Should -BeTrue
            $R.Message | Should -Match "ready"
        }

        It "Runs TestCommand and reports failure without throwing" {
            $Authority = @{ Type = 'Command'; SignCommand = "x {CsrFile} {CertFile}"; TestCommand = "`"$PwshExe`" -NoProfile -c `"[Console]::Error.WriteLine('no index.txt'); exit 2`"" }
            $R = InModuleScope AxisPowerShell -Parameters @{ A = $Authority } { Test-AxisCertificateAuthorityCommand -Authority $A }
            $R.Reachable | Should -BeFalse
            $R.Message | Should -Match "exit code 2.*no index.txt"
        }
    }
}

#Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

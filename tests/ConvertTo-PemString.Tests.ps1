Describe "ConvertTo-PemString / ConvertFrom-PemString" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        #In-memory self-signed certificates (no key material leaves the process)
        $Key = [System.Security.Cryptography.ECDsa]::Create([System.Security.Cryptography.ECCurve]::CreateFromFriendlyName("nistP256"))
        $Req = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest("CN=cam01.example.com", $Key, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
        $Global:PemCertA = $Req.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddYears(1))
        $Req = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest("CN=Example Root CA", $Key, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
        $Global:PemCertB = $Req.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddYears(5))
    }

    Context "ConvertTo-PemString" {
        It "Wraps bytes in 64-character lines with the default CERTIFICATE label" {
            $Bytes = [byte[]](1..100)
            $Pem = InModuleScope AxisPowerShell -Parameters @{ Bytes = $Bytes } { ConvertTo-PemString -Bytes $Bytes }

            $Lines = $Pem -split "`n"
            $Lines[0] | Should -Be "-----BEGIN CERTIFICATE-----"
            $Lines[-1] | Should -Be "-----END CERTIFICATE-----"
            $Lines[1].Length | Should -Be 64
            $Lines[2].Length | Should -Be 64
            $Lines[3].Length | Should -Be 8
            ($Lines[1..3] -join "") | Should -Be ([Convert]::ToBase64String($Bytes))
            $Pem | Should -Not -Match "`r"
        }

        It "Uses a custom label" {
            $Pem = InModuleScope AxisPowerShell { ConvertTo-PemString -Bytes ([byte[]](1,2,3)) -Label "CERTIFICATE REQUEST" }

            $Pem | Should -Match "^-----BEGIN CERTIFICATE REQUEST-----`nAQID`n-----END CERTIFICATE REQUEST-----$"
        }

        It "Encodes an X509Certificate2 (parameter and pipeline)" {
            $Expected = [Convert]::ToBase64String($PemCertA.RawData)

            $Pem = InModuleScope AxisPowerShell -Parameters @{ Cert = $PemCertA } { ConvertTo-PemString -Certificate $Cert }
            (($Pem -split "`n")[1..(($Pem -split "`n").Count - 2)] -join "") | Should -Be $Expected

            $Pem2 = InModuleScope AxisPowerShell -Parameters @{ Cert = $PemCertA } { $Cert | ConvertTo-PemString }
            $Pem2 | Should -Be $Pem
        }
    }

    Context "ConvertFrom-PemString" {
        It "Round-trips bytes through PEM" {
            $Bytes = [byte[]](0..255)
            $Blocks = @(InModuleScope AxisPowerShell -Parameters @{ Bytes = $Bytes } { ConvertFrom-PemString -Pem (ConvertTo-PemString -Bytes $Bytes -Label "PKCS7") })

            $Blocks.Count | Should -Be 1
            $Blocks[0].Label | Should -Be "PKCS7"
            [Convert]::ToBase64String($Blocks[0].Bytes) | Should -Be ([Convert]::ToBase64String($Bytes))
            $Blocks[0].Pem | Should -Match "^-----BEGIN PKCS7-----"
        }

        It "Splits a bundle into one block per certificate and keeps the order" {
            $Bundle = "Some header text`r`n-----BEGIN CERTIFICATE-----`r`n$([Convert]::ToBase64String($PemCertA.RawData,'InsertLineBreaks'))`r`n-----END CERTIFICATE-----`r`n-----BEGIN CERTIFICATE-----`n$([Convert]::ToBase64String($PemCertB.RawData))`n-----END CERTIFICATE-----`n"
            $Blocks = @(InModuleScope AxisPowerShell -Parameters @{ Bundle = $Bundle } { ConvertFrom-PemString -Pem $Bundle })

            $Blocks.Count | Should -Be 2
            [Convert]::ToBase64String($Blocks[0].Bytes) | Should -Be ([Convert]::ToBase64String($PemCertA.RawData))
            [Convert]::ToBase64String($Blocks[1].Bytes) | Should -Be ([Convert]::ToBase64String($PemCertB.RawData))
        }

        It "Returns X509Certificate2 objects with -AsCertificate and skips other blocks" {
            $Bundle = "-----BEGIN CERTIFICATE REQUEST-----`nAQID`n-----END CERTIFICATE REQUEST-----`n-----BEGIN CERTIFICATE-----`n$([Convert]::ToBase64String($PemCertA.RawData))`n-----END CERTIFICATE-----`n-----BEGIN CERTIFICATE-----`n$([Convert]::ToBase64String($PemCertB.RawData))`n-----END CERTIFICATE-----"
            $Certs = @(InModuleScope AxisPowerShell -Parameters @{ Bundle = $Bundle } { ConvertFrom-PemString -Pem $Bundle -AsCertificate })

            $Certs.Count | Should -Be 2
            $Certs[0] | Should -BeOfType [System.Security.Cryptography.X509Certificates.X509Certificate2]
            $Certs[0].Thumbprint | Should -Be $PemCertA.Thumbprint
            $Certs[1].Subject | Should -Be "CN=Example Root CA"
        }

        It "Accepts pipeline input" {
            $Pem = "-----BEGIN CERTIFICATE-----`n$([Convert]::ToBase64String($PemCertA.RawData))`n-----END CERTIFICATE-----"
            $Block = InModuleScope AxisPowerShell -Parameters @{ Pem = $Pem } { $Pem | ConvertFrom-PemString }

            $Block.Label | Should -Be "CERTIFICATE"
        }

        It "Throws when there is no PEM block" {
            { InModuleScope AxisPowerShell { ConvertFrom-PemString -Pem "just some text" } } | Should -Throw "No PEM blocks found in input."
        }

        It "Throws on mismatched BEGIN/END labels" {
            { InModuleScope AxisPowerShell { ConvertFrom-PemString -Pem "-----BEGIN CERTIFICATE-----`nAQID`n-----END PKCS7-----" } } | Should -Throw "No PEM blocks found in input."
        }

        It "Throws on invalid base64 inside a block" {
            { InModuleScope AxisPowerShell { ConvertFrom-PemString -Pem "-----BEGIN CERTIFICATE-----`nnot*base64!`n-----END CERTIFICATE-----" } } | Should -Throw
        }
    }

    AfterAll {
        Remove-Variable PemCertA, PemCertB -Scope Global -ErrorAction SilentlyContinue
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

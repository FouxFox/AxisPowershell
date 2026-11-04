Describe "Get-AxisCertificateKeyType" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
    }

    BeforeEach {
        Mock @m Invoke-AxisCertApi {
            return @(
                [pscustomobject]@{ id = "SOFTWARE0"; security_level = "SOFTWARE"; key_types = @("RSA-2048","RSA-3072","RSA-4096","NIST-P256","NIST-P384") }
                [pscustomobject]@{ id = "TPM0"; security_level = "STRONG"; key_types = @("RSA-2048","RSA-3072","EC-P256") }
                [pscustomobject]@{ id = "TEE"; security_level = "TRUSTED_ENVIRONMENT"; key_types = @("RSA-2048","NIST-P384") }
            )
        }
    }

    Context "Automatic selection" {
        It "Prefers the strongest keystore and then the strongest key it supports, in the device's spelling" {
            $Result = InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" }

            $Result.Keystore | Should -Be "TPM0"
            $Result.KeyType | Should -Be "EC-P256"
            $Result.SecurityLevel | Should -Be "STRONG"
            $Result.Source | Should -Be "REST"
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter { $Device -eq "192.168.0.100" -and $Path -eq "/keystores" } -Times 1 -Exactly
        }

        It "Follows the key preference order within a keystore" {
            Mock @m Invoke-AxisCertApi { return @([pscustomobject]@{ id = "SOFTWARE0"; security_level = "SOFTWARE"; key_types = @("RSA-2048","RSA-4096","RSA-3072") }) }

            (InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" }).KeyType | Should -Be "RSA-4096"
        }

        It "Orders keystores STRONG > TRUSTED_ENVIRONMENT > SOFTWARE regardless of list order" {
            Mock @m Invoke-AxisCertApi {
                return @(
                    [pscustomobject]@{ id = "SOFTWARE0"; security_level = "SOFTWARE"; key_types = @("NIST-P384") }
                    [pscustomobject]@{ id = "TEE"; security_level = "TRUSTED_ENVIRONMENT"; key_types = @("RSA-2048") }
                )
            }

            $Result = InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" }
            $Result.Keystore | Should -Be "TEE"
            $Result.KeyType | Should -Be "RSA-2048"
        }

        It "Honours the allowed list and falls through to a weaker keystore when needed" {
            $Result = InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" -AllowedKeyTypes "RSA-4096" }

            $Result.Keystore | Should -Be "SOFTWARE0"
            $Result.KeyType | Should -Be "RSA-4096"
        }

        It "Accepts EC-P / ECC-P spelling in the allowed list" {
            $Result = InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" -AllowedKeyTypes "ECC-P256","ec-p384" }

            $Result.Keystore | Should -Be "TPM0"
            $Result.KeyType | Should -Be "EC-P256"
        }

        It "Throws when no keystore supports an allowed key type" {
            { InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" -AllowedKeyTypes "RSA-1024" } } | Should -Throw "*No keystore on 192.168.0.100 supports any of the allowed key types (RSA-1024)"
        }
    }

    Context "Explicit values" {
        It "Validates an explicit key type and returns the device spelling" {
            $Result = InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" -KeyType "NIST-P256" }

            $Result.Keystore | Should -Be "TPM0"
            $Result.KeyType | Should -Be "EC-P256"
        }

        It "Restricts to an explicit keystore" {
            $Result = InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" -Keystore "TEE" }

            $Result.Keystore | Should -Be "TEE"
            $Result.KeyType | Should -Be "NIST-P384"
            $Result.SecurityLevel | Should -Be "TRUSTED_ENVIRONMENT"
        }

        It "Throws when the explicit key type is not supported by the chosen keystore" {
            { InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" -Keystore "TEE" -KeyType "RSA-4096" } } | Should -Throw "*Key type 'RSA-4096' is not supported*"
        }

        It "Throws for an unknown keystore in Auto key mode and lists the available ones" {
            { InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" -Keystore "SE0" } } | Should -Throw "*Keystore 'SE0' was not reported*SOFTWARE0, TPM0, TEE*"
        }

        It "Trusts both explicit values with a warning when the keystore is unknown" {
            Mock @m Write-Warning { }

            $Result = InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" -Keystore "SE0" -KeyType "RSA-2048" }

            $Result.Keystore | Should -Be "SE0"
            $Result.KeyType | Should -Be "RSA-2048"
            Should @m -Invoke "Write-Warning" -Times 1 -Exactly
        }

        It "Sends the requested key type when the keystore advertises none" {
            Mock @m Invoke-AxisCertApi { return @([pscustomobject]@{ id = "TPM0"; security_level = "STRONG"; key_types = @() }) }

            $Result = InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" -KeyType "RSA-3072" }
            $Result.KeyType | Should -Be "RSA-3072"
            $Result.Keystore | Should -Be "TPM0"
        }
    }

    Context "SOAP-only firmware" {
        It "Returns RSA-2048 without a keystore when the REST API is missing" {
            Mock @m Invoke-AxisCertApi { Throw "Command not supported on this device" }

            $Result = InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" }

            $Result.KeyType | Should -Be "RSA-2048"
            $Result.Keystore | Should -BeNullOrEmpty
            $Result.Source | Should -Be "SOAP"
        }

        It "Reports an explicit key type on SOAP-only firmware" {
            Mock @m Invoke-AxisCertApi { Throw "Command not supported on this device" }

            (InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" -KeyType "RSA-4096" }).KeyType | Should -Be "RSA-4096"
        }

        It "Wraps other API errors" {
            Mock @m Invoke-AxisCertApi { Throw "Certificate API error: boom" }

            { InModuleScope AxisPowerShell { Get-AxisCertificateKeyType -Device "192.168.0.100" } } | Should -Throw "*Unable to read keystores from 192.168.0.100*boom*"
        }
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

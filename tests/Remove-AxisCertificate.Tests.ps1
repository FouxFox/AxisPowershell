Describe "Remove-AxisCertificate" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
    }

    BeforeEach {
        Mock @m Get-AxisCertificate { return @([pscustomobject]@{ Alias = $Alias; Thumbprint = "AAAA" }) }
        Mock @m Get-AxisTlsCertificate { return [pscustomobject]@{ Thumbprint = "BBBB" } }
        Mock @m Invoke-AxisCertApi { return $null }
        Mock @m Invoke-AxisSoapRequest { return $null }
    }

    Context "JSON API" {
        It "Deletes the certificate through the REST collection with an escaped alias" {
            Remove-AxisCertificate -Device "192.168.0.100" -Alias "Old Cert"

            Should @m -Invoke "Get-AxisCertificate" -ParameterFilter { $Device -eq "192.168.0.100" -and $Alias -eq "Old Cert" } -Times 1 -Exactly
            Should @m -Invoke "Get-AxisTlsCertificate" -Times 1 -Exactly
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter { $Path -eq "/certificates/Old%20Cert" -and $Method -eq "DELETE" } -Times 1 -Exactly
            Should @m -Invoke "Invoke-AxisSoapRequest" -Times 0
        }

        It "Uses the ca_certificates collection with -CA and skips the HTTPS check" {
            Remove-AxisCertificate -Device "192.168.0.100" -Alias "Old-Root" -CA

            Should @m -Invoke "Get-AxisCertificate" -Times 0
            Should @m -Invoke "Get-AxisTlsCertificate" -Times 0
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter { $Path -eq "/ca_certificates/Old-Root" -and $Method -eq "DELETE" } -Times 1 -Exactly
        }

        It "Wraps other REST errors" {
            Mock @m Invoke-AxisCertApi { Throw "Certificate API error: not found" }

            { Remove-AxisCertificate -Device "192.168.0.100" -Alias "Old" } | Should -Throw "*Unable to delete certificate 'Old' on 192.168.0.100*not found*"
            Should @m -Invoke "Invoke-AxisSoapRequest" -Times 0
        }
    }

    Context "HTTPS protection" {
        It "Refuses to delete the certificate currently served on HTTPS" {
            Mock @m Get-AxisTlsCertificate { return [pscustomobject]@{ Thumbprint = "AAAA" } }

            { Remove-AxisCertificate -Device "192.168.0.100" -Alias "Live" } | Should -Throw "*currently bound to HTTPS*"
            Should @m -Invoke "Invoke-AxisCertApi" -Times 0
            Should @m -Invoke "Invoke-AxisSoapRequest" -Times 0
        }

        It "Deletes the served certificate with -Force" {
            Mock @m Get-AxisTlsCertificate { return [pscustomobject]@{ Thumbprint = "AAAA" } }

            Remove-AxisCertificate -Device "192.168.0.100" -Alias "Live" -Force

            Should @m -Invoke "Get-AxisTlsCertificate" -Times 0
            Should @m -Invoke "Invoke-AxisCertApi" -ParameterFilter { $Path -eq "/certificates/Live" } -Times 1 -Exactly
        }

        It "Proceeds when the alias is not installed or the TLS probe returns nothing" {
            Mock @m Get-AxisCertificate { return @() }
            Remove-AxisCertificate -Device "192.168.0.100" -Alias "Gone"
            Should @m -Invoke "Get-AxisTlsCertificate" -Times 0

            Mock @m Get-AxisCertificate { return @([pscustomobject]@{ Alias = "X"; Thumbprint = "AAAA" }) }
            Mock @m Get-AxisTlsCertificate { return $null }
            Remove-AxisCertificate -Device "192.168.0.100" -Alias "X"
            Should @m -Invoke "Invoke-AxisCertApi" -Times 2
        }
    }

    Context "SOAP fallback" {
        BeforeEach {
            Mock @m Invoke-AxisCertApi { Throw "Command not supported on this device" }
        }

        It "Falls back to tds:DeleteCertificates with an XML-escaped id" {
            Remove-AxisCertificate -Device "192.168.0.100" -Alias "A&B<C>"

            Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter {
                $Device -eq "192.168.0.100" -and $Body -like "<tds:DeleteCertificates*" -and $Body -like "*<CertificateID>A&amp;B&lt;C&gt;</CertificateID>*"
            } -Times 1 -Exactly
        }

        It "Uses the same SOAP operation for CA certificates" {
            Remove-AxisCertificate -Device "192.168.0.100" -Alias "Root" -CA

            Should @m -Invoke "Invoke-AxisSoapRequest" -ParameterFilter { $Body -like "*<CertificateID>Root</CertificateID>*" } -Times 1 -Exactly
        }

        It "Wraps SOAP faults" {
            Mock @m Invoke-AxisSoapRequest { Throw "SOAP Fault: Certificate not found - (ter:InvalidArgVal)" }

            { Remove-AxisCertificate -Device "192.168.0.100" -Alias "Old" } | Should -Throw "*Unable to delete certificate 'Old' on 192.168.0.100*SOAP Fault*"
        }
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

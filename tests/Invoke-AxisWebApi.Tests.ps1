Describe "Invoke-AxisWebApi" {
    Context "Required function calls" {
        BeforeAll {
            # Required Mock Functions
            Mock @m Initialize-AxisCache {}
            Mock @m Set-AxisCredential {}
            Mock @m Get-Credential {}
            Mock @m Set-UseUnsafeHeaderParsing {}
            Mock @m Set-CertificateValidation {}
            Mock @m Invoke-RestMethod {}

            InModuleScope AxisPowerShell {
                #$Script:Config.Credential = $false
                $TestDevice_IP = "192.168.0.100"
                $Param = @{
                    Path = "/axis-cgi/param.cgi?action=list"
                    Device = $TestDevice_IP
                }
                Invoke-AxisWebApi @Param
            }
        }

        It "Invokes Initialize-AxisCache" {
            Should @m -Scope Context -Invoke "Initialize-AxisCache" -Exactly -Times 1 -ParameterFilter { $Device -eq "192.168.0.100" }
        }

        # Windows PowerShell 5.1 (.NET Framework) relaxes header parsing and certificate validation
        # process-wide through the private helpers. PowerShell 7 uses Invoke-RestMethod switches instead.
        It "<Desc>" -Skip:($PSVersionTable.PSVersion.Major -gt 5) -ForEach @(
            @{
                Desc = "PS 5.1: Turns on Unsafe Header Parsing"
                cmd = "Set-UseUnsafeHeaderParsing"
                Filter = {$Enable -eq $true}
            }
            @{
                Desc = "PS 5.1: Turns off Certificate Validation"
                cmd = "Set-CertificateValidation"
                Filter = {$Disable -eq $true}
            }) {
            Should @m -Scope Context -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "PS 5.1: Enables TLS 1.2 on the ServicePointManager" -Skip:($PSVersionTable.PSVersion.Major -gt 5) {
            ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12) | Should -Not -Be 0
        }

        It "<Desc>" -Skip:($PSVersionTable.PSVersion.Major -lt 7) -ForEach @(
            @{
                Desc = "PS 7: Does not call the .NET Framework header parsing helper"
                cmd = "Set-UseUnsafeHeaderParsing"
            }
            @{
                Desc = "PS 7: Does not call the .NET Framework certificate validation helper"
                cmd = "Set-CertificateValidation"
            }) {
            Should @m -Scope Context -Invoke $cmd -Exactly -Times 0
        }

        It "<Desc>" -Skip:($PSVersionTable.PSVersion.Major -lt 7) -ForEach @(
            @{
                Desc = "PS 7: Skips the certificate check"
                Filter = {$SkipCertificateCheck -eq $true}
            }
            @{
                Desc = "PS 7: Allows unencrypted (HTTP) authentication"
                Filter = {$AllowUnencryptedAuthentication -eq $true}
            }
            @{
                Desc = "PS 7: Does not skip the HTTP error check by default"
                Filter = {-not $SkipHttpErrorCheck}
            }) {
            Should @m -Scope Context -Invoke "Invoke-RestMethod" -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Does not Invoke Set-AxisCredential when Credential is set" {
            Should @m -Scope Context -Invoke "Set-AxisCredential" -Exactly -Times 0
        }
    }

    Context "API Call Construction" {
        BeforeAll {
            # Required Mock Functions
            Mock @m Initialize-AxisCache {}
            Mock @m Set-AxisCredential {}
            Mock @m Get-Credential {}
            Mock @m Set-UseUnsafeHeaderParsing {}
            Mock @m Set-CertificateValidation {}
            Mock @m Invoke-RestMethod {
                if(([string]$URI).StartsWith("://10.1.1.1")) {
                    Throw "Invalid URI"
                }
            }
            Mock @m ConvertTo-JSON { return "JSON"}
        }

        It "<Desc>" -ForEach @(
            @{
                Desc = "Uses Credential"
                cmd = "Invoke-RestMethod"
                Param = @{Param=@{
                    Path = "/axis-cgi/param.cgi?action=list"
                    Device = "192.168.0.100"
                }}
                Filter = {$Credential}
            }
            @{
                Desc = "Uses Basic Parsing"
                cmd = "Invoke-RestMethod"
                Param = @{Param=@{
                    Path = "/axis-cgi/param.cgi?action=list"
                    Device = "192.168.0.100"
                }}
                Filter = {$UseBasicParsing -eq $true}
            }
            @{
                Desc = "Default Method is GET"
                cmd = "Invoke-RestMethod"
                Param = @{Param=@{
                    Path = "/axis-cgi/param.cgi?action=list"
                    Device = "192.168.0.100"
                }}
                Filter = {$Method -eq "GET"}
            }
            @{
                Desc = "Specifies POST when Body is provided"
                cmd = "Invoke-RestMethod"
                Param = @{Param=@{
                    Path = "/axis-cgi/param.cgi?action=list"
                    Device = "192.168.0.100"
                    Body = @{param1="value1"; param2="value2"}
                }}
                Filter = {$Method -eq "POST"}
            }
            @{
                Desc = "Converts Body to JSON"
                cmd = "Invoke-RestMethod"
                Param = @{Param=@{
                    Path = "/axis-cgi/param.cgi?action=list"
                    Device = "192.168.0.100"
                    Body = @{param1="value1"; param2="value2"}
                }}
                Filter = {$Body -eq "JSON"}
            }
            @{
                Desc = "Properly Concatinates URI"
                cmd = "Invoke-RestMethod"
                Param = @{Param=@{
                    Path = "/axis-cgi/param.cgi?action=list"
                    Device = "192.168.0.100"
                }}
                Filter = {$URI -eq "https://192.168.0.100/axis-cgi/param.cgi?action=list"}
            }
            @{
                Desc = "Sends a string Body as-is with the given ContentType"
                cmd = "Invoke-RestMethod"
                Param = @{Param=@{
                    Path = "/vapix/services"
                    Device = "192.168.0.100"
                    Body = "<soap/>"
                    ContentType = "application/soap+xml"
                }}
                Filter = {$Body -eq "<soap/>" -and $Headers["Content-Type"] -eq "application/soap+xml"}
            }
            @{
                Desc = "Keeps an explicit write Method when Body is provided"
                cmd = "Invoke-RestMethod"
                Param = @{Param=@{
                    Path = "/config/rest/v1/thing"
                    Device = "192.168.0.100"
                    Method = "PATCH"
                    Body = @{param1="value1"}
                }}
                Filter = {$Method -eq "PATCH"}
            }
            @{
                Desc = "Passes TimeoutSec through"
                cmd = "Invoke-RestMethod"
                Param = @{Param=@{
                    Path = "/axis-cgi/param.cgi?action=list"
                    Device = "192.168.0.100"
                    TimeoutSec = 15
                }}
                Filter = {$TimeoutSec -eq 15}
            }
            @{
                Desc = "Retries with HTTP when HTTPS fails"
                cmd = "Invoke-RestMethod"
                Param = @{Param=@{
                    Path = "/axis-cgi/param.cgi?action=list"
                    Device = "10.1.1.1"
                }}
                Filter = {$URI -eq "http://10.1.1.1/axis-cgi/param.cgi?action=list"}
            }) {
            InModuleScope AxisPowerShell -Parameters $Param { Invoke-AxisWebApi @Param }
            Should @m -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Uses Invoke-WebRequest when -WebRequest is specified" {
            Mock @m Invoke-WebRequest {}
            InModuleScope AxisPowerShell {
                Invoke-AxisWebApi -Path "/axis-cgi/param.cgi?action=list" -Device "192.168.0.100" -WebRequest
            }
            Should @m -Invoke "Invoke-WebRequest" -Exactly -Times 1 -ParameterFilter { $URI -eq "https://192.168.0.100/axis-cgi/param.cgi?action=list" }
            Should @m -Invoke "Invoke-RestMethod" -Exactly -Times 0
        }

        It "Does not send a Credential with -NoAuth" {
            InModuleScope AxisPowerShell {
                Invoke-AxisWebApi -Path "/axis-cgi/param.cgi?action=list" -Device "192.168.0.100" -NoAuth
            }
            Should @m -Invoke "Invoke-RestMethod" -Exactly -Times 1 -ParameterFilter { $null -eq $Credential }
        }

        It "PS 7: Passes SkipHttpErrorCheck to Invoke-RestMethod when requested" -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
            InModuleScope AxisPowerShell {
                Invoke-AxisWebApi -Path "/vapix/services" -Device "192.168.0.100" -SkipHttpErrorCheck
            }
            Should @m -Invoke "Invoke-RestMethod" -Exactly -Times 1 -ParameterFilter { $SkipHttpErrorCheck -eq $true }
        }

        It "PS 7: Passes SkipCertificateCheck to Invoke-WebRequest" -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
            Mock @m Invoke-WebRequest {}
            InModuleScope AxisPowerShell {
                Invoke-AxisWebApi -Path "/axis-cgi/param.cgi?action=list" -Device "192.168.0.100" -WebRequest
            }
            Should @m -Invoke "Invoke-WebRequest" -Exactly -Times 1 -ParameterFilter { $SkipCertificateCheck -eq $true -and $AllowUnencryptedAuthentication -eq $true }
        }
    }

    Context "Exception Tests" {
        BeforeAll {
            # Required Mock Functions
            Mock @m Initialize-AxisCache {}
            Mock @m Set-AxisCredential {}
            Mock @m Get-Credential {}
            Mock @m Set-UseUnsafeHeaderParsing {}
            Mock @m Set-CertificateValidation {}
            Mock @m Invoke-RestMethod {
                Throw "Invalid Protocol"
            }
            Mock @m ConvertTo-JSON { return "JSON"}
        }

        It "Throws and error when HTTP/S fails" {             
            InModuleScope AxisPowerShell {
                $Param = @{
                    Path = "/axis-cgi/param.cgi?action=list"
                    Device = "10.1.1.1"
                }
                { Invoke-AxisWebApi @Param } | Should -Throw
            } 
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

#Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
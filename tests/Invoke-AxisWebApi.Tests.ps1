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

        It "<Desc>" -ForEach @(
            @{
                Desc = "Invokes Initialize-AxisCache"
                cmd = "Initialize-AxisCache"
                Filter = {$Device -eq "192.168.0.100"}
            }
            @{
                Desc = "Turns off Unsafe Header Parsing"
                cmd = "Set-UseUnsafeHeaderParsing"
                Filter = {$Disable -eq $true}
            }
            @{
                Desc = "Turns on Unsafe Header Parsing"
                cmd = "Set-UseUnsafeHeaderParsing"
                Filter = {$Enable -eq $true}
            }
            @{
                Desc = "Turns off Unsafe Header Parsing"
                cmd = "Set-CertificateValidation"
                Filter = {$Disable -eq $true}
            }) {
            Should @m -Scope Context -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
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
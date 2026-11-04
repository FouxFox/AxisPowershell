Describe "Get-AxisConfigApiPath" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
    }

    BeforeEach {
        InModuleScope AxisPowerShell { $Script:Cache = @{} }
        Mock @m Invoke-AxisWebApi {
            return [pscustomobject]@{
                cert = [pscustomobject]@{ v1 = [pscustomobject]@{ rest_api = "/config/rest/cert/v1beta"; state = "beta" } }
                "cert-est" = [pscustomobject]@{ v1 = [pscustomobject]@{ rest_api = "/config/rest/cert-est/v1"; state = "released" } }
                ssh = [pscustomobject]@{ v2 = [pscustomobject]@{ rest_api = "/config/rest/ssh/v2" } }
            }
        }
    }

    It "Returns the advertised path including the state suffix" {
        InModuleScope AxisPowerShell { Get-AxisConfigApiPath -Device "192.168.0.100" -API "cert" } | Should -Be "/config/rest/cert/v1beta"
        InModuleScope AxisPowerShell { Get-AxisConfigApiPath -Device "192.168.0.100" -API "cert-est" } | Should -Be "/config/rest/cert-est/v1"
        Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter { $Device -eq "192.168.0.100" -and $Path -eq "/config/discover/apis" } -Times 1 -Exactly
    }

    It "Caches the discovery result per device" {
        $null = InModuleScope AxisPowerShell { Get-AxisConfigApiPath -Device "192.168.0.100" -API "cert" }
        $null = InModuleScope AxisPowerShell { Get-AxisConfigApiPath -Device "192.168.0.100" -API "cert" }
        $null = InModuleScope AxisPowerShell { Get-AxisConfigApiPath -Device "192.168.0.101" -API "cert" }

        Should @m -Invoke "Invoke-AxisWebApi" -Times 2 -Exactly
        InModuleScope AxisPowerShell { $Cache["192.168.0.100"].ContainsKey("ConfigAPIs") } | Should -BeTrue
        InModuleScope AxisPowerShell { $Cache["192.168.0.101"].ConfigAPIs.cert.v1.rest_api } | Should -Be "/config/rest/cert/v1beta"
    }

    It "Keeps existing cache entries for the device" {
        InModuleScope AxisPowerShell { $Script:Cache = @{ "192.168.0.100" = @{ Type = "https" } } }

        $null = InModuleScope AxisPowerShell { Get-AxisConfigApiPath -Device "192.168.0.100" -API "cert" }

        InModuleScope AxisPowerShell { $Cache["192.168.0.100"].Type } | Should -Be "https"
    }

    It "Honours -MajorVersion" {
        InModuleScope AxisPowerShell { Get-AxisConfigApiPath -Device "192.168.0.100" -API "ssh" -MajorVersion 2 } | Should -Be "/config/rest/ssh/v2"
        { InModuleScope AxisPowerShell { Get-AxisConfigApiPath -Device "192.168.0.100" -API "ssh" } } | Should -Throw "Command not supported on this device"
    }

    It "Throws 'Command not supported' for an unknown API" {
        { InModuleScope AxisPowerShell { Get-AxisConfigApiPath -Device "192.168.0.100" -API "nope" } } | Should -Throw "Command not supported on this device"
    }

    It "Throws 'Command not supported' when discovery fails and does not retry" {
        Mock @m Invoke-AxisWebApi { Throw "404 Not Found" }

        { InModuleScope AxisPowerShell { Get-AxisConfigApiPath -Device "192.168.0.100" -API "cert" } } | Should -Throw "Command not supported on this device"
        { InModuleScope AxisPowerShell { Get-AxisConfigApiPath -Device "192.168.0.100" -API "cert" } } | Should -Throw "Command not supported on this device"
        Should @m -Invoke "Invoke-AxisWebApi" -Times 1 -Exactly
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

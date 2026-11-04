Describe "Invoke-AxisCertApi" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
    }

    BeforeEach {
        Mock @m Get-AxisConfigApiPath { return "/config/rest/cert/v1" }
        Mock @m Invoke-AxisWebApi { return [pscustomobject]@{ status = "success"; data = @([pscustomobject]@{ alias = "A" }) } }
    }

    It "Resolves the cert API path and GETs without a body" {
        $Result = InModuleScope AxisPowerShell { Invoke-AxisCertApi -Device "192.168.0.100" -Path "/certificates" }

        Should @m -Invoke "Get-AxisConfigApiPath" -ParameterFilter { $Device -eq "192.168.0.100" -and $API -eq "cert" } -Times 1 -Exactly
        Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter { $Path -eq "/config/rest/cert/v1/certificates" -and $Method -eq "GET" -and $null -eq $Body } -Times 1 -Exactly
        @($Result)[0].alias | Should -Be "A"
    }

    It "Wraps the payload in a data envelope for POST" {
        $null = InModuleScope AxisPowerShell { Invoke-AxisCertApi -Device "192.168.0.100" -Path "/certificates/X/get_csr" -Method POST -Data @{ subject = @{ cn = "cam" } } }

        Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter { $Method -eq "POST" -and $Body -is [hashtable] -and $Body.data.subject.cn -eq "cam" } -Times 1 -Exactly
    }

    It "Wraps scalar and null payloads too" {
        $null = InModuleScope AxisPowerShell { Invoke-AxisCertApi -Device "192.168.0.100" -Path "/x" -Method PATCH -Data "value" }
        Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter { $Method -eq "PATCH" -and $Body.data -eq "value" } -Times 1 -Exactly

        $null = InModuleScope AxisPowerShell { Invoke-AxisCertApi -Device "192.168.0.100" -Path "/x" -Method PATCH -Data $null }
        Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter { $Method -eq "PATCH" -and $Body -is [hashtable] -and $Body.ContainsKey("data") -and $null -eq $Body.data } -Times 1 -Exactly
    }

    It "Sends an empty body for DELETE so the method sticks" {
        $null = InModuleScope AxisPowerShell { Invoke-AxisCertApi -Device "192.168.0.100" -Path "/certificates/X" -Method DELETE }

        Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter { $Method -eq "DELETE" -and $null -ne $Body -and $Body -is [string] -and $Body.Length -eq 0 } -Times 1 -Exactly
    }

    It "Returns the unwrapped data" {
        Mock @m Invoke-AxisWebApi { return [pscustomobject]@{ status = "success"; data = [pscustomobject]@{ csr = "-----BEGIN CERTIFICATE REQUEST-----" } } }

        (InModuleScope AxisPowerShell { Invoke-AxisCertApi -Device "192.168.0.100" -Path "/x" }).csr | Should -Be "-----BEGIN CERTIFICATE REQUEST-----"
    }

    It "Throws on status error with the device message" {
        Mock @m Invoke-AxisWebApi { return [pscustomobject]@{ status = "error"; error = [pscustomobject]@{ code = 1100; message = "Alias already exists" } } }

        { InModuleScope AxisPowerShell { Invoke-AxisCertApi -Device "192.168.0.100" -Path "/certificates" -Method POST -Data @{} } } | Should -Throw "Certificate API error: Alias already exists"
    }

    It "Throws 'Unknown error' when the error has no message" {
        Mock @m Invoke-AxisWebApi { return [pscustomobject]@{ status = "error" } }

        { InModuleScope AxisPowerShell { Invoke-AxisCertApi -Device "192.168.0.100" -Path "/x" } } | Should -Throw "Certificate API error: Unknown error"
    }

    It "Propagates 'Command not supported' without calling the device" {
        Mock @m Get-AxisConfigApiPath { Throw "Command not supported on this device" }

        { InModuleScope AxisPowerShell { Invoke-AxisCertApi -Device "192.168.0.100" -Path "/x" } } | Should -Throw "Command not supported on this device"
        Should @m -Invoke "Invoke-AxisWebApi" -Times 0
    }

    It "Rejects unknown HTTP methods" {
        { InModuleScope AxisPowerShell { Invoke-AxisCertApi -Device "192.168.0.100" -Path "/x" -Method PUT } } | Should -Throw
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

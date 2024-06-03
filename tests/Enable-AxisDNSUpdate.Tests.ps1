Describe "AxisPowerShell.Public.Enable-AxisDNSUpdate" {
    Context "User Output Messages" {
        BeforeAll {
            # Required Mock Functions
            Mock @m Get-AxisDeviceInfo { return @{SerialNumber='123456'} }
            Mock @m Invoke-AxisWebApi { return 'OK' }
            Mock @m Write-Host {}
        }

        It "Prints correctly when successful" {
            #Mock -ModuleName AxisPowerShell Invoke-AxisWebApi { return 'Ok!' }
            Enable-AxisDNSUpdate -Device $TestDevice_IP -Hostname "axis-camera.example.com"
            Should @m -Invoke "Write-Host" -Exactly -Times 2 -ParameterFilter { $Object -eq "OK!" }
            Should @m -Invoke "Write-Host" -Exactly -Times 1 -ParameterFilter { $Object -eq "$($TestDevice_IP): Setting Configuration..." }
            Should @m -Invoke "Write-Host" -Exactly -Times 1 -ParameterFilter { $Object -eq "$($TestDevice_IP): Forcing DNS Update..." }
        }

        It "Prints correctly when configuration is unsuccessful" {
            $Filter = { $Path -and $Path.StartsWith("/axis-cgi/param.cgi?") }
            Mock -ModuleName AxisPowerShell Invoke-AxisWebApi -ParameterFilter $Filter { Throw 'some error' }
            {Enable-AxisDNSUpdate -Device $TestDevice_IP -Hostname "axis-camera.example.com"} | Should -Throw
            Should @m -Invoke "Write-Host" -Exactly -Times 1 -ParameterFilter { $Object -eq "$($TestDevice_IP): Setting Configuration..." }
            Should @m -Invoke "Write-Host" -Exactly -Times 1 -ParameterFilter { $Object -eq "Failed!" }
        }

        It "Prints correctly when DNS Update is unsuccessful" {
            $Filter = { $Path -and $Path.StartsWith("/axis-cgi/dnsupdate.cgi?") }
            Mock -ModuleName AxisPowerShell Invoke-AxisWebApi -ParameterFilter $Filter { Throw 'some error' }
            Enable-AxisDNSUpdate -Device $TestDevice_IP -Hostname "axis-camera.example.com"
            Should @m -Invoke "Write-Host" -Exactly -Times 1 -ParameterFilter { $Object -eq "Failed Successfully!" }
            Should @m -Invoke "Write-Host" -Exactly -Times 1 -ParameterFilter { $Object -eq "$($TestDevice_IP): Setting Configuration..." }
            Should @m -Invoke "Write-Host" -Exactly -Times 1 -ParameterFilter { $Object -eq "$($TestDevice_IP): Forcing DNS Update..." }
        }
    }
    Context "When enabling DNS update with a provided hostname" {
        BeforeEach { Enable-AxisDNSUpdate -Device $TestDevice_IP -Hostname "axis-camera.example.com" }
        BeforeAll {
            # Required Mock Functions
            Mock -ModuleName AxisPowerShell Get-AxisDeviceInfo { return @{SerialNumber='123456'} }
            Mock -ModuleName AxisPowerShell Invoke-AxisWebApi { return 'OK' }
        }

        It 'Sets the configuration with the provided hostname' {
            $cmd = 'Invoke-AxisWebApi'
            $Filter = {
                $Device -eq $TestDevice_IP -and
                $Path -eq "/axis-cgi/param.cgi?action=update&Network.DNSUpdate.DNSName=axis-camera.example.com&Network.DNSUpdate.Enabled=yes"
            }
            Should @m -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
        }

        It 'Forces a DNS update' {
            $cmd = 'Invoke-AxisWebApi'
            $Filter = {
                $Device -eq $TestDevice_IP -and
                $Path -eq "/axis-cgi/dnsupdate.cgi?add=axis-camera.example.com&hdgen=yes" -and
                $Method -eq "Get"
            }
            Should @m -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
        }
    }

    Context "When enabling DNS update without a provided hostname" {
        BeforeEach { Enable-AxisDNSUpdate -Device $TestDevice_IP }
        BeforeAll {
            # Required Mock Functions
            Mock -ModuleName AxisPowerShell Get-AxisDeviceInfo { return @{SerialNumber='123456'} }
            Mock -ModuleName AxisPowerShell Invoke-AxisWebApi { return 'OK' }
        }

        # Tests
        It 'Sets the configuration with the generated hostname' {
            $cmd = 'Invoke-AxisWebApi'
            $Filter = {
                $Device -eq $TestDevice_IP -and
                $Path -eq "/axis-cgi/param.cgi?action=update&Network.DNSUpdate.DNSName=axis-123456.example.com&Network.DNSUpdate.Enabled=yes"
            }
            Should @m -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
        }

        It 'Forces a DNS update' {
            $cmd = 'Invoke-AxisWebApi'
            $Filter = {
                $Device -eq $TestDevice_IP -and
                $Path -eq "/axis-cgi/dnsupdate.cgi?add=axis-123456.example.com&hdgen=yes" -and
                $Method -eq "Get"
            }
            Should @m -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

#Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
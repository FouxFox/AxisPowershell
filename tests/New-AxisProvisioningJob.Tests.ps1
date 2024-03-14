Describe -Skip "AxisPowerShell.Public.New-AxisProvisioningJob" {
    Context "When IP addresses are provided" {
        BeforeAll {
            # Required Mock Functions
            Mock @m Set-AxisCredential {}
            Mock @m Set-AxisPSFactoryConfig {}
            Mock @m Get-NetIPAddress { return @() }
            Mock @m Find-LANHosts { return @() }
            Mock @m Provision-AxisDevice {}
        }

        It "Calls Set-AxisCredential and Set-AxisPSFactoryConfig" {
            New-AxisProvisioningJob -IP "192.168.1.10", "192.168.1.20"
            Should @m -Invoke "Set-AxisCredential" -Exactly -Times 1
            Should @m -Invoke "Set-AxisPSFactoryConfig" -Exactly -Times 1
        }

        It "Calls Provision-AxisDevice for each IP address" {
            Mock -ModuleName AxisPowerShell Provision-AxisDevice {}
            New-AxisProvisioningJob -IP "192.168.1.10", "192.168.1.20"
            Should @m -Invoke "Provision-AxisDevice" -Exactly -Times 2
        }
    }

    Context "When IP addresses are not provided" {
        BeforeAll {
            # Required Mock Functions
            Mock @m Set-AxisCredential {}
            Mock @m Set-AxisPSFactoryConfig {}
            Mock @m Get-NetIPAddress { return @() }
            Mock @m Find-LANHosts { return @() }
            Mock @m Provision-AxisDevice {}
        }

        It "Calls Set-AxisCredential and Set-AxisPSFactoryConfig" {
            New-AxisProvisioningJob
            Should @m -Invoke "Set-AxisCredential" -Exactly -Times 1
            Should @m -Invoke "Set-AxisPSFactoryConfig" -Exactly -Times 1
        }

        It "Calls Get-NetIPAddress and Find-LANHosts" {
            New-AxisProvisioningJob
            Should @m -Invoke "Get-NetIPAddress" -Exactly -Times 1
            Should @m -Invoke "Find-LANHosts" -Exactly -Times 1
        }

        It "Calls Provision-AxisDevice for each discovered device" {
            Mock -ModuleName AxisPowerShell Provision-AxisDevice {}
            New-AxisProvisioningJob
            Should @m -Invoke "Provision-AxisDevice" -Exactly -Times 0
        }
    }
}
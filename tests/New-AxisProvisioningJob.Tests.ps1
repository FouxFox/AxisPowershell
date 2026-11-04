Describe "New-AxisProvisioningJob" {
    BeforeAll {
        # Get-NetIPAddress (NetTCPIP), Out-SubnetRange and Find-LANHosts (PowerShell Gallery) are Windows-only
        # dependencies. Stub them globally so they can be mocked on every platform.
        function Global:Get-NetIPAddress { param($IPAddress, $AddressState, $AddressFamily) }
        function Global:Out-SubnetRange  { param($Subnet, $Prefix) }
        function Global:Find-LANHosts    { param($IP) }

        $Script:JobMocks = {
            Mock @m Check-Credential {}
            Mock @m Set-AxisCredential {}
            Mock @m Invoke-AxisProvisioningTask {}
            Mock @m Get-NetIPAddress { return @() }
            Mock @m Out-SubnetRange { return @() }
            Mock @m Find-LANHosts { return @() }
        }
    }

    AfterAll {
        Remove-Item -Path Function:\Get-NetIPAddress, Function:\Out-SubnetRange, Function:\Find-LANHosts -ErrorAction SilentlyContinue
    }

    Context "Preconditions" {
        BeforeAll { . $JobMocks }

        It "Checks the credential" {
            New-AxisProvisioningJob -IP "192.168.1.10" -SingleThreaded
            Should @m -Invoke "Check-Credential" -Exactly -Times 1
        }

        It "Throws when the firmware folder is not configured" {
            InModuleScope AxisPowerShell { $Script:Config.FirmwareFolder = $null }
            { New-AxisProvisioningJob -IP "192.168.1.10" -SingleThreaded } | Should -Throw "Firmware Folder not set*"
            Should @m -Invoke "Invoke-AxisProvisioningTask" -Exactly -Times 0
            InModuleScope AxisPowerShell { $Script:Config.FirmwareFolder = "C:\" }
        }
    }

    Context "When IP addresses are provided" {
        BeforeAll { . $JobMocks }

        It "Runs a provisioning task for every IP address, using the IP as the job ID" {
            New-AxisProvisioningJob -IP "192.168.1.10", "192.168.1.20" -SingleThreaded

            Should @m -Invoke "Invoke-AxisProvisioningTask" -Exactly -Times 2
            Should @m -Invoke "Invoke-AxisProvisioningTask" -Exactly -Times 1 -ParameterFilter { $Device -eq "192.168.1.10" -and $MacAddress -eq "192.168.1.10" }
            Should @m -Invoke "Invoke-AxisProvisioningTask" -Exactly -Times 1 -ParameterFilter { $Device -eq "192.168.1.20" -and $MacAddress -eq "192.168.1.20" }
        }

        It "Does not scan the network" {
            New-AxisProvisioningJob -IP "192.168.1.10" -SingleThreaded

            Should @m -Invoke "Get-NetIPAddress" -Exactly -Times 0
            Should @m -Invoke "Find-LANHosts" -Exactly -Times 0
        }

        It "Continues with the next device when a task fails" {
            Mock @m Invoke-AxisProvisioningTask { if($Device -eq "192.168.1.10") { Throw "boom" } }

            # An exception here would fail the test; the job must swallow the task error as a warning
            New-AxisProvisioningJob -IP "192.168.1.10", "192.168.1.20" -SingleThreaded -WarningVariable Warn -WarningAction SilentlyContinue

            Should @m -Invoke "Invoke-AxisProvisioningTask" -Exactly -Times 1 -ParameterFilter { $Device -eq "192.168.1.20" }
            $Warn | Should -HaveCount 1
            "$Warn" | Should -BeLike "192.168.1.10: *boom*"
        }
    }

    Context "When IP addresses are not provided (discovery)" {
        BeforeAll {
            . $JobMocks
            Mock @m Get-NetIPAddress {
                return @(
                    [pscustomobject]@{ IPAddress = '127.0.0.1';    PrefixLength = 8;  InterfaceAlias = 'Loopback Pseudo-Interface 1' }
                    [pscustomobject]@{ IPAddress = '192.168.56.1'; PrefixLength = 24; InterfaceAlias = 'VMware Network Adapter VMnet1' }
                    [pscustomobject]@{ IPAddress = '172.16.0.1';   PrefixLength = 16; InterfaceAlias = 'vEthernet (Default Switch)' }
                    [pscustomobject]@{ IPAddress = '192.168.1.50'; PrefixLength = 24; InterfaceAlias = 'Ethernet' }
                )
            }
            Mock @m Out-SubnetRange { return @('192.168.1.1','192.168.1.2') }
            Mock @m Find-LANHosts {
                return @(
                    [pscustomobject]@{ IP = '192.168.1.1'; MACAddress = 'aa-bb-cc-00-00-01' }   # not Axis
                    [pscustomobject]@{ IP = '192.168.1.2'; MACAddress = 'ac-cc-8e-00-00-02' }   # Axis OUI
                    [pscustomobject]@{ IP = '192.168.1.3'; MACAddress = 'b8-a4-4f-00-00-03' }   # Axis OUI
                    [pscustomobject]@{ IP = '192.168.1.4'; MACAddress = 'e8-27-25-00-00-04' }   # Axis OUI
                    [pscustomobject]@{ IP = '192.168.1.5'; MACAddress = '00-40-8c-00-00-05' }   # Axis OUI
                )
            }
        }

        It "Picks the first physical interface and scans its subnet" {
            New-AxisProvisioningJob -SingleThreaded

            Should @m -Invoke "Get-NetIPAddress" -Exactly -Times 1 -ParameterFilter { $AddressState -eq 'Preferred' -and $AddressFamily -eq 'IPv4' }
            Should @m -Invoke "Out-SubnetRange" -Exactly -Times 1 -ParameterFilter { $Subnet -eq '192.168.1.50' -and $Prefix -eq 24 }
            Should @m -Invoke "Find-LANHosts" -Exactly -Times 1 -ParameterFilter { @($IP).Count -eq 2 -and $IP[0] -eq '192.168.1.1' }
        }

        It "Uses the given interface when InterfaceIP is provided" {
            Mock @m Get-NetIPAddress { return [pscustomobject]@{ IPAddress = '192.168.2.50'; PrefixLength = 25; InterfaceAlias = 'Ethernet 2' } }

            New-AxisProvisioningJob -InterfaceIP '192.168.2.50' -SingleThreaded

            Should @m -Invoke "Get-NetIPAddress" -Exactly -Times 1 -ParameterFilter { $IPAddress -eq '192.168.2.50' }
            Should @m -Invoke "Out-SubnetRange" -Exactly -Times 1 -ParameterFilter { $Subnet -eq '192.168.2.50' -and $Prefix -eq 25 }
        }

        It "Provisions only hosts with an Axis OUI, keyed by MAC address" {
            New-AxisProvisioningJob -SingleThreaded

            Should @m -Invoke "Invoke-AxisProvisioningTask" -Exactly -Times 4
            Should @m -Invoke "Invoke-AxisProvisioningTask" -Exactly -Times 0 -ParameterFilter { $Device -eq '192.168.1.1' }
            Should @m -Invoke "Invoke-AxisProvisioningTask" -Exactly -Times 1 -ParameterFilter { $Device -eq '192.168.1.2' -and $MacAddress -eq 'ac-cc-8e-00-00-02' }
            Should @m -Invoke "Invoke-AxisProvisioningTask" -Exactly -Times 1 -ParameterFilter { $Device -eq '192.168.1.5' -and $MacAddress -eq '00-40-8c-00-00-05' }
        }

        It "Throws when no Axis devices are found" {
            Mock @m Find-LANHosts { return @([pscustomobject]@{ IP = '192.168.1.1'; MACAddress = 'aa-bb-cc-00-00-01' }) }

            { New-AxisProvisioningJob -SingleThreaded } | Should -Throw "No Axis Devices Found"
            Should @m -Invoke "Invoke-AxisProvisioningTask" -Exactly -Times 0
        }

        It "Throws when the scan returns nothing" {
            Mock @m Find-LANHosts { return @() }

            { New-AxisProvisioningJob -SingleThreaded } | Should -Throw "No Axis Devices Found"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

#Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

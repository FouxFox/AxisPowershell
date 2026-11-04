Describe "Get-AxisSDCardStatus" {
    Context "Device with SD cards" {
        BeforeAll {
            Mock @m Invoke-AxisWebApi {
                return [xml]@"
<?xml version="1.0" encoding="UTF-8"?>
<root>
  <disks numberofdisks="3">
    <disk diskid="SD_DISK" name="" totalsize="465864704" freesize="451300000" cleanuplevel="99" cleanupmaxage="0" cleanuppolicy="fifo" locked="no" full="no" readonly="no" status="OK" filesystem="ext4" group="S0" requiredfilesystem="none" encryptionenabled="false" diskencrypted="false"/>
    <disk diskid="SD_DISK2" name="" totalsize="465864704" freesize="451300000" cleanuplevel="99" cleanupmaxage="7" cleanuppolicy="fifo" locked="no" full="no" readonly="no" status="OK" filesystem="ext4" group="S1" requiredfilesystem="none" encryptionenabled="false" diskencrypted="true"/>
    <disk diskid="NetworkShare" name="" totalsize="0" freesize="0" cleanuplevel="90" cleanupmaxage="7" cleanuppolicy="fifo" locked="no" full="no" readonly="no" status="disconnected" filesystem="cifs" group="S2" requiredfilesystem="none" encryptionenabled="false" diskencrypted="false"/>
  </disks>
</root>
"@
            }
        }

        It "Lists all disks" {
            Get-AxisSDCardStatus -Device "192.168.0.100"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and $Path -eq "/axis-cgi/disks/list.cgi?diskid=all"
            }
        }

        It "Returns only SD cards with sizes converted to GB" {
            $result = Get-AxisSDCardStatus -Device "192.168.0.100"

            ($result | Measure-Object).Count | Should -Be 2
            $result[0].Id            | Should -Be 'SD_DISK'
            $result[0].Group         | Should -Be 'S0'
            $result[0].Status        | Should -Be 'OK'
            $result[0].MaxAge        | Should -Be '0'
            $result[0].TotalSizeGB   | Should -Be 444.28
            $result[0].FreeSizeGB    | Should -Be 430.39
            $result[1].Id            | Should -Be 'SD_DISK2'
            $result[1].DiskEncrypted | Should -Be 'true'
        }
    }

    Context "Device without SD card" {
        It "Warns and returns nothing" {
            Mock @m Write-Warning {}
            Mock @m Invoke-AxisWebApi {
                return [xml]'<root><disks numberofdisks="1"><disk diskid="NetworkShare" totalsize="0" freesize="0" status="disconnected" group="S0" cleanupmaxage="7" diskencrypted="false"/></disks></root>'
            }

            $result = Get-AxisSDCardStatus -Device "192.168.0.100"

            $result | Should -BeNullOrEmpty
            Should @m -Invoke "Write-Warning" -Exactly -Times 1
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

Describe "Get-AxisStorageOptions" {
    Context "Storage options retrieval" {
        BeforeAll {
            Mock @m Get-AxisParameter {
                return @{
                    'Storage.S0.DiskID'              = 'SD_DISK'
                    'Storage.S0.Enabled'             = 'yes'
                    'Storage.S0.AutoRepair'          = 'yes'
                    'Storage.S0.CleanupMaxAge'       = '0'
                    'Storage.S0.CleanupPolicyActive' = 'fifo'
                    'Storage.S0.FileSystem'          = 'ext4'
                    'Storage.S0.Locked'              = 'no'
                }
            }
        }

        It "Requests the Storage.S0 group" {
            Get-AxisStorageOptions -Device "192.168.0.100"

            Should @m -Invoke "Get-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and $Group -eq 'Storage.S0'
            }
        }

        It "Returns the storage options with booleans" {
            $result = Get-AxisStorageOptions -Device "192.168.0.100"

            $result.Disk                | Should -Be 'SD_DISK'
            $result.Enabled             | Should -BeTrue
            $result.AutoRepair          | Should -BeTrue
            $result.CleanupMaxAge       | Should -Be '0'
            $result.CleanupPolicyActive | Should -Be 'fifo'
            $result.FileSystem          | Should -Be 'ext4'
            $result.Locked              | Should -BeFalse
        }

        It "Throws when the parameters cannot be fetched" {
            Mock @m Get-AxisParameter { Throw "Unable to fetch parameter(s)" }

            { Get-AxisStorageOptions -Device "192.168.0.100" } | Should -Throw "Unable to fetch parameter(s)"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

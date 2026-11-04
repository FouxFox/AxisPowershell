Describe "Set-AxisStorageOptions" {
    BeforeAll {
        Mock @m Set-AxisParameter {}
    }

    Context "Single SD card" {
        It "Sets CleanupMaxAge to 0 by default" {
            Mock @m Get-AxisSDCardStatus { return [pscustomobject]@{ Id = "SD_DISK"; Group = "S0"; Status = "OK" } }

            Set-AxisStorageOptions -Device "192.168.0.100"

            Should @m -Invoke "Set-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $ParameterSet.Count -eq 1 -and
                $ParameterSet["Storage.S0.CleanupMaxAge"] -eq 0
            }
        }
    }

    Context "Dual SD card" {
        It "Sets MaxAge for every storage group" {
            Mock @m Get-AxisSDCardStatus { return @(
                [pscustomobject]@{ Id = "SD_DISK"; Group = "S0"; Status = "OK" }
                [pscustomobject]@{ Id = "SD_DISK2"; Group = "S1"; Status = "OK" }
            ) }

            Set-AxisStorageOptions -Device "192.168.0.100" -MaxAge 30

            Should @m -Invoke "Set-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $ParameterSet.Count -eq 2 -and
                $ParameterSet["Storage.S0.CleanupMaxAge"] -eq 30 -and
                $ParameterSet["Storage.S1.CleanupMaxAge"] -eq 30
            }
        }
    }

    Context "Errors" {
        It "Propagates a parameter failure" {
            Mock @m Get-AxisSDCardStatus { return [pscustomobject]@{ Id = "SD_DISK"; Group = "S0"; Status = "OK" } }
            Mock @m Set-AxisParameter { Throw "Unable to update parameter(s)" }

            { Set-AxisStorageOptions -Device "192.168.0.100" -MaxAge 7 } | Should -Throw "Unable to update parameter(s)"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

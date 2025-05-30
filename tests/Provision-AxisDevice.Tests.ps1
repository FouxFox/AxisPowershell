Describe "Provision-AxisDevice" {
    Context "Called from New-AxisProvisioningJob: Commands" {
        BeforeAll {
            # Mock necessary functions
            Mock @m Initialize-AxisDevice {}
            Mock @m Get-AxisNetworkInfo {}
            Mock @m Set-AxisPSFactoryConfig {}
            Mock @m Update-AxisDevice {}
            Mock @m Set-AxisIPAddress {}
            Mock @m Enable-AxisDNSUpdate {}
            Mock @m Set-AxisServices {}
            Mock @m Format-AxisSDCard {}
            Mock @m New-AxisRecordingProfile {}
            Mock @m Write-Progress {}
            Mock New-AxisProvisioningJob { Provision-AxisDevice -Device "192.168.1.100" -FactoryPrepTest }

            New-AxisProvisioningJob
        }

        It "<cmd>" -ForEach @(
            @{
                cmd = "Initialize-AxisDevice"
                Filter = {$NewPassword -eq "password"}
            }
            @{
                cmd = "Enable-AxisDNSUpdate"
                Filter = { $true }
            }
            @{
                cmd = "Set-AxisServices"
                Filter = { $true }
            }
            @{
                cmd = "Format-AxisSDCard"
                Filter = { $Wait -eq $true }
            }
            @{
                cmd = "New-AxisRecordingProfile"
                Filter = { $SDCard -eq $true }
            }) {

            Should @m -Scope Context -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Does not call Set-AxisIPAddress" {
            $cmd = "Set-AxisIPAddress"
            Should @m -Scope Context -Not -Invoke $cmd
        }
    }

    Context "Called from New-AxisProvisioningJob: Progress" {
        BeforeAll {
            # Mock necessary functions
            Mock @m Initialize-AxisDevice {}
            Mock @m Get-AxisNetworkInfo {}
            Mock @m Set-AxisPSConfig {}
            Mock @m Update-AxisDevice {}
            Mock @m Set-AxisIPAddress {}
            Mock @m Enable-AxisDNSUpdate {}
            Mock @m Set-AxisServices {}
            Mock @m Format-AxisSDCard {}
            Mock @m New-AxisRecordingProfile {}
            Mock @m Write-Progress {}

            Invoke-AxisProvisioningTask -Device "192.168.1.100" -MacAddress "00:00:00:00:00:00"
        }

        It "<Desc>" -ForEach @(
            @{
                Desc = "Write-Progress for Setting Password"
                Filter = {$Status -eq "Stage 1/6: Setting Password"}
            }
            @{
                Desc = "Write-Progress for Updating Firmware"
                Filter = {$Status -eq "Stage 2/6: Updating Firmware"}
            }
            @{
                Desc = "Write-Progress for DNS Update"
                Filter = {$Status -eq "Stage 3/6: Set Network Configuration"}
            }
            @{
                Desc = "Write-Progress for Security Settings"
                Filter = {$Status -eq "Stage 4/6: Applying Security Best Practices"}
            }
            @{
                Desc = "Write-Progress for Format SD Card"
                Filter = {$Status -eq "Stage 5/6: Formatting SD Card"}
            }
            @{
                Desc = "Write-Progress for Recording Profile"
                Filter = {$Status -eq "Stage 6/6: Creating Edge Recording Profile"}
            }
            @{
                Desc = "Write-Progress Completes"
                Filter = {$Status -eq "Done" -and $PercentComplete -eq 100}
            }) {
            Should @m -Scope Context -Invoke Write-Progress -ParameterFilter $Filter
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

#Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
Describe "Format-AxisSDCard" {
    Context "Single SD Card" {
        BeforeAll {
            # Required Mock Functions
            $Param = @{
                CommandName = "Invoke-AxisWebApi"
                ModuleName = "AxisPowerShell"
                MockWith = {
                    return @{root=@{job=@{
                        result = 'OK'
                        jobid = '123'
                        progress = 100
                    }}}
                }
            }
            Mock @Param

            Mock @m Get-AxisDeviceInfo { return @{ProdNbr = "P3268-LVE"} }
            Mock @m Start-Sleep {}
            Mock @m Write-Progress {}
            Mock @m Write-Host {}

            Format-AxisSDCard -Device "192.168.1.100"
        }

        It "Checks the model number" {            
            Should -Scope Context @m -Invoke "Get-AxisDeviceInfo"
        }

        It "Unmounts the SD Card" {          
            $Filter = { $Path -eq "/axis-cgi/disks/mount.cgi?diskid=SD_DISK&action=unmount" }
            Should -Scope Context @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Waits 5 seconds for the unmount operation" {
            Should -Scope Context @m -Invoke "Start-Sleep" -ParameterFilter { $Seconds -eq 5 } -Exactly -Times 1
        }

        It "Starts formatting the SD Card" {      
            $Filter = { $Path -eq "/axis-cgi/disks/format.cgi?diskid=SD_DISK&filesystem=ext4" }
            Should -Scope Context @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Does not wait for completion" {
            Should -Scope Context @m -Not -Invoke "Write-Progress"
        }

        It "Printed a message" {
            Should -Scope Context @m -Invoke "Write-Host"
        }
    }

    Context "Dual SD Card (P3737-PLE)" {
        BeforeAll {
            # Required Mock Functions
            $Param = @{
                CommandName = "Invoke-AxisWebApi"
                ModuleName = "AxisPowerShell"
                MockWith = {
                    return @{root=@{job=@{
                        result = 'OK'
                        jobid = '123'
                        progress = 100
                    }}}
                }
            }
            Mock @Param
            
            Mock @m Get-AxisDeviceInfo { return @{ProdNbr = "P3737-PLE"} }
            Mock @m Start-Sleep {}
            Mock @m Write-Progress {}
            Mock @m Write-Host {}

            Format-AxisSDCard -Device "192.168.1.100"
        }

        It "Checks the model number" {            
            Should -Scope Context @m -Invoke "Get-AxisDeviceInfo"
        }

        It "Unmounts the first SD Card" {   
            $Filter = { $Path -eq "/axis-cgi/disks/mount.cgi?diskid=SD_DISK&action=unmount" }
            Should -Scope Context @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Starts formatting the first SD Card" {
            $Filter = { $Path -eq "/axis-cgi/disks/format.cgi?diskid=SD_DISK&filesystem=ext4" }
            Should -Scope Context @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Unmounts the second SD Card" {   
            $Filter = { $Path -eq "/axis-cgi/disks/mount.cgi?diskid=SD_DISK2&action=unmount" }
            Should -Scope Context @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Starts formatting the second SD Card" {
            $Filter = { $Path -eq "/axis-cgi/disks/format.cgi?diskid=SD_DISK2&filesystem=ext4" }
            Should -Scope Context @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Waits 5 seconds for the unmount operation" {
            Should -Scope Context @m -Invoke "Start-Sleep" -ParameterFilter { $Seconds -eq 5 } -Exactly -Times 2
        }

        It "Does not wait for completion" {
            Should -Scope Context @m -Not -Invoke "Write-Progress"
        }

        It "Printed a message" {
            Should -Scope Context @m -Invoke "Write-Host"
        }
    }

    Context "Dual SD Card (P3737-PLE)" {
        BeforeAll {
            # Required Mock Functions
            $Param = @{
                CommandName = "Invoke-AxisWebApi"
                ModuleName = "AxisPowerShell"
                MockWith = {
                    return @{root=@{job=@{
                        result = 'OK'
                        jobid = '123'
                        progress = 100
                    }}}
                }
            }
            Mock @Param
            
            Mock @m Get-AxisDeviceInfo { return @{ProdNbr = "P3719-PLE"} }
            Mock @m Start-Sleep {}
            Mock @m Write-Progress {}
            Mock @m Write-Host {}

            Format-AxisSDCard -Device "192.168.1.100"
        }

        It "Checks the model number" {            
            Should -Scope Context @m -Invoke "Get-AxisDeviceInfo"
        }

        It "Unmounts the first SD Card" {   
            $Filter = { $Path -eq "/axis-cgi/disks/mount.cgi?diskid=SD_DISK&action=unmount" }
            Should -Scope Context @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Starts formatting the first SD Card" {
            $Filter = { $Path -eq "/axis-cgi/disks/format.cgi?diskid=SD_DISK&filesystem=ext4" }
            Should -Scope Context @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Unmounts the second SD Card" {   
            $Filter = { $Path -eq "/axis-cgi/disks/mount.cgi?diskid=SD_DISK2&action=unmount" }
            Should -Scope Context @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Starts formatting the second SD Card" {
            $Filter = { $Path -eq "/axis-cgi/disks/format.cgi?diskid=SD_DISK2&filesystem=ext4" }
            Should -Scope Context @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Waits 5 seconds for the unmount operation" {
            Should -Scope Context @m -Invoke "Start-Sleep" -ParameterFilter { $Seconds -eq 5 } -Exactly -Times 2
        }

        It "Does not wait for completion" {
            Should -Scope Context @m -Not -Invoke "Write-Progress"
        }

        It "Printed a message" {
            Should -Scope Context @m -Invoke "Write-Host"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

#Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
Describe "Format-AxisSDCard" {
    Context "When formatting the SD card successfully" {
        BeforeAll {
            # Required Mock Functions
            Mock -ModuleName AxisPowerShell Invoke-AxisWebApi { return @{root = @{job = @{result = 'OK'; jobid = '123'; progress = 100}}} }
        }

        It "Formats the SD card" {
            $Device = "TestDevice"
            Format-AxisSDCard -Device $Device
            $Param = @{
                Device = $Device
                Path = "/axis-cgi/disks/format.cgi?diskid=SD_DISK&filesystem=ext4"
            }
            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter $Param
        }

        It "Does not wait for completion" {
            $Device = "TestDevice"
            Format-AxisSDCard -Device $Device -Wait:$false
            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1
            Should @m -Invoke "Write-Progress" -Exactly -Times 0
        }

        It "Waits for completion" {
            $Device = "TestDevice"
            Format-AxisSDCard -Device $Device -Wait:$true
            $Param = @{
                Device = $Device
                Path = "/axis-cgi/disks/format.cgi?diskid=SD_DISK&filesystem=ext4"
            }
            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter $Param
            $Param = @{
                Device = $Device
                Path = "/axis-cgi/disks/job.cgi?jobid=123&diskid=SD_DISK"
            }
            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter $Param
            Should @m -Invoke "Write-Progress" -Exactly -Times 1
        }
    }

    Context "When formatting the SD card fails" {
        BeforeAll {
            # Required Mock Functions
            Mock -ModuleName AxisPowerShell Invoke-AxisWebApi { return @{root = @{job = @{result = 'Error'}}} }
        }

        It "Throws an error" {
            $Device = "TestDevice"
            { Format-AxisSDCard -Device $Device } | Should -Throw "Could not format: Error"
        }
    }
}
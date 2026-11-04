Describe "Update-AxisDevice" {
    BeforeAll {
        $Script:FwFolder = Join-Path $TestDrive "Firmware"
        New-Item -ItemType Directory -Path $Script:FwFolder | Out-Null
        New-Item -ItemType File -Path (Join-Path $Script:FwFolder "P3719-PLE_11_11_73.bin") | Out-Null

        Mock @m Write-Host {}
        Mock @m Start-Sleep {}
        Mock @m Initialize-AxisDevice {}
        Mock @m Get-AxisDeviceInfo { return [pscustomobject]@{ ProdNbr = "P3719-PLE"; Version = "11.10.61" } }
        Mock @m Invoke-MultiPartWebRequest { return '{"apiVersion":"1.0","data":{}}' }
        Mock @m Test-Connection { return $false }
        Mock @m Get-AxisDeviceStatus { return [pscustomobject]@{ Status = "Ready" } }
    }

    Context "Successful upgrade" {
        BeforeAll {
            Mock @m Test-Connection { return $false }
            Mock @m Get-AxisDeviceStatus { return [pscustomobject]@{ Status = "Ready" } }

            Update-AxisDevice -Device "192.168.0.100" -FirmwareFolder $Script:FwFolder
        }

        It "Uploads the matching firmware file to firmwaremanagement.cgi" {
            Should -Scope Context @m -Invoke "Invoke-MultiPartWebRequest" -Exactly -Times 1 -ParameterFilter {
                $Url -eq "https://192.168.0.100/axis-cgi/firmwaremanagement.cgi" -and
                $File -eq (Join-Path $Script:FwFolder "P3719-PLE_11_11_73.bin") -and
                ($Data | ConvertFrom-Json).method -eq "upgrade"
            }
        }

        It "Waits for the device to go down and come back" {
            Should -Scope Context @m -Invoke "Test-Connection" -Exactly -Times 1 -ParameterFilter { $ComputerName -eq "192.168.0.100" }
            Should -Scope Context @m -Invoke "Get-AxisDeviceStatus" -Exactly -Times 1 -ParameterFilter { $TimeoutSec -eq 1 }
        }

        It "Does not initialize the device" {
            Should -Scope Context @m -Not -Invoke "Initialize-AxisDevice"
        }
    }

    Context "Preconditions" {
        BeforeAll {
            Mock @m Test-Connection { return $false }
            Mock @m Get-AxisDeviceStatus { return [pscustomobject]@{ Status = "Ready" } }
        }

        It "Does nothing when the firmware is already current" {
            Mock @m Get-AxisDeviceInfo { return [pscustomobject]@{ ProdNbr = "P3719-PLE"; Version = "11.11.73" } }

            Update-AxisDevice -Device "192.168.0.100" -FirmwareFolder $Script:FwFolder

            Should @m -Not -Invoke "Invoke-MultiPartWebRequest"
            Should @m -Invoke "Write-Host" -ParameterFilter { $Object -like "*already up to date*" }
        }

        It "Does nothing when the device firmware is newer" {
            Mock @m Get-AxisDeviceInfo { return [pscustomobject]@{ ProdNbr = "P3719-PLE"; Version = "12.0.5" } }

            Update-AxisDevice -Device "192.168.0.100" -FirmwareFolder $Script:FwFolder

            Should @m -Not -Invoke "Invoke-MultiPartWebRequest"
        }

        It "Uploads anyway with -Force" {
            Mock @m Get-AxisDeviceInfo { return [pscustomobject]@{ ProdNbr = "P3719-PLE"; Version = "11.11.73" } }

            Update-AxisDevice -Device "192.168.0.100" -FirmwareFolder $Script:FwFolder -Force

            Should @m -Invoke "Invoke-MultiPartWebRequest" -Exactly -Times 1
        }

        It "Throws when no firmware file matches the model" {
            Mock @m Get-AxisDeviceInfo { return [pscustomobject]@{ ProdNbr = "Q6075-E"; Version = "11.10.61" } }

            { Update-AxisDevice -Device "192.168.0.100" -FirmwareFolder $Script:FwFolder } | Should -Throw "No firmware file found*"

            Should @m -Not -Invoke "Invoke-MultiPartWebRequest"
        }
    }

    Context "Factory default" {
        It "Initializes a factory default device first and requests factoryDefaultMode soft" {
            Mock @m Test-Connection { return $false }
            Mock @m Get-AxisDeviceStatus { return [pscustomobject]@{ Status = "Needs Setup" } }

            Update-AxisDevice -Device "192.168.0.100" -FirmwareFolder $Script:FwFolder -FactoryDefault

            Should @m -Invoke "Initialize-AxisDevice" -Exactly -Times 1 -ParameterFilter { $Device -eq "192.168.0.100" }
            Should @m -Invoke "Invoke-MultiPartWebRequest" -Exactly -Times 1 -ParameterFilter {
                ($Data | ConvertFrom-Json).params.factoryDefaultMode -eq "soft"
            }
        }
    }

    Context "Errors" {
        It "Throws the device error from the upload" {
            Mock @m Invoke-MultiPartWebRequest { return '{"apiVersion":"1.0","error":{"code":1000,"message":"Invalid firmware"}}' }

            { Update-AxisDevice -Device "192.168.0.100" -FirmwareFolder $Script:FwFolder } | Should -Throw "Invalid firmware"

            Should @m -Not -Invoke "Test-Connection"
        }

        It "Throws when the device never goes down" {
            Mock @m Test-Connection { return $true }

            { Update-AxisDevice -Device "192.168.0.100" -FirmwareFolder $Script:FwFolder } | Should -Throw "Device did not reboot in a timely manner."

            Should @m -Invoke "Test-Connection" -Exactly -Times 20
        }

        It "Throws when the device never comes back" {
            Mock @m Test-Connection { return $false }
            Mock @m Get-AxisDeviceStatus { return [pscustomobject]@{ Status = "Not Ready" } }

            { Update-AxisDevice -Device "192.168.0.100" -FirmwareFolder $Script:FwFolder } | Should -Throw "Device did not come back online in a timely manner."

            Should @m -Invoke "Get-AxisDeviceStatus" -Exactly -Times 40 -ParameterFilter { $TimeoutSec -eq 1 }
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

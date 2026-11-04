Describe "Invoke-AxisProvisioningTask" {
    # Every stage cmdlet is mocked; nothing here talks to a device
    BeforeAll {
        $Script:StageMocks = {
            Mock @m Write-Log {}
            Mock @m Write-Progress {}
            Mock @m Start-Sleep {}
            Mock @m Update-AxisDevice {}
            Mock @m Get-AxisDeviceStatus { Throw "401 Unauthorized" }   # factory default: no password yet
            Mock @m Initialize-AxisDevice {}
            Mock @m Enable-AxisDNSUpdate {}
            Mock @m Set-AxisDSCP {}
            Mock @m Set-AxisServices {}
            Mock @m Request-AxisCertificate { return [pscustomobject]@{Action = 'Installed'; Message = 'ok'} }
            Mock @m Format-AxisSDCard {}
            Mock @m Set-AxisStorageOptions {}
            Mock @m New-AxisStreamProfile {}
            Mock @m New-AxisRecordingProfile {}
            Mock @m Get-AxisSnapshot {}
        }
    }

    Context "All 8 stages, certificate provisioning disabled" {
        BeforeAll {
            . $StageMocks
            InModuleScope AxisPowerShell {
                $Script:Config.ProvisionCertificate = $false
                $Script:Config.Certificate = @{ DefaultAuthority = 'LabCA' }
                $Script:Config.DefaultEdgeRecordingParameters = 'videocodec=h265&fps=30'
                $Script:Config.ProvisioningSnapshotPath = 'C:\Snapshots'
            }

            Invoke-AxisProvisioningTask -Device "192.168.1.100" -MacAddress "00-40-8c-00-00-01"
        }

        It "<cmd>" -ForEach @(
            @{ cmd = "Update-AxisDevice";        Filter = { $Device -eq "192.168.1.100" -and $FactoryDefault -eq $true -and $Force -eq $true } }
            @{ cmd = "Get-AxisDeviceStatus";     Filter = { $Device -eq "192.168.1.100" } }
            @{ cmd = "Initialize-AxisDevice";    Filter = { $Device -eq "192.168.1.100" } }
            @{ cmd = "Enable-AxisDNSUpdate";     Filter = { $Device -eq "192.168.1.100" } }
            @{ cmd = "Set-AxisDSCP";             Filter = { $Device -eq "192.168.1.100" } }
            @{ cmd = "Set-AxisServices";         Filter = { $Device -eq "192.168.1.100" } }
            @{ cmd = "Format-AxisSDCard";        Filter = { $Device -eq "192.168.1.100" -and $Wait -eq $true -and $NoProgress -eq $true -and $EncryptionKey -eq "password" } }
            @{ cmd = "Set-AxisStorageOptions";   Filter = { $Device -eq "192.168.1.100" } }
            @{ cmd = "New-AxisStreamProfile";    Filter = { $Device -eq "192.168.1.100" -and $Name -eq "EdgeRecording" -and $Parameters -eq 'videocodec=h265&fps=30' } }
            @{ cmd = "New-AxisRecordingProfile"; Filter = { $Device -eq "192.168.1.100" -and $StreamProfile -eq "EdgeRecording" } }
            @{ cmd = "Get-AxisSnapshot";         Filter = { $Device -eq "192.168.1.100" -and $Path -eq 'C:\Snapshots' -and $FileName -eq "00-40-8c-00-00-01" } }
        ) {
            Should @m -Scope Context -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Skips Request-AxisCertificate when ProvisionCertificate is false" {
            Should @m -Scope Context -Invoke "Request-AxisCertificate" -Exactly -Times 0
        }

        It "Logs every message against the MAC address" {
            Should @m -Scope Context -Invoke "Write-Log" -ParameterFilter { $ID -eq "00-40-8c-00-00-01" }
            Should @m -Scope Context -Invoke "Write-Log" -Exactly -Times 0 -ParameterFilter { $ID -ne "00-40-8c-00-00-01" }
        }

        It "Logs that the certificate stage was skipped" {
            Should @m -Scope Context -Invoke "Write-Log" -Exactly -Times 1 -ParameterFilter { $Message -like "Certificate stage skipped*" }
        }

        It "<Desc>" -ForEach @(
            @{ Desc = "Write-Progress Stage 1"; Filter = { $Status -eq "Stage 1/8: Updating Firmware" -and $PercentComplete -eq 0 } }
            @{ Desc = "Write-Progress Stage 2"; Filter = { $Status -eq "Stage 2/8: Setting Password" } }
            @{ Desc = "Write-Progress Stage 3"; Filter = { $Status -eq "Stage 3/8: Set Network Configuration" } }
            @{ Desc = "Write-Progress Stage 4"; Filter = { $Status -eq "Stage 4/8: Applying Security Best Practices" } }
            @{ Desc = "Write-Progress Stage 5"; Filter = { $Status -eq "Stage 5/8: Deploying Certificate" } }
            @{ Desc = "Write-Progress Stage 6"; Filter = { $Status -eq "Stage 6/8: Formatting SD Card" } }
            @{ Desc = "Write-Progress Stage 7"; Filter = { $Status -eq "Stage 7/8: Creating Edge Recording Profile" } }
            @{ Desc = "Write-Progress Stage 8"; Filter = { $Status -eq "Stage 8/8: Getting Snapshot from camera" } }
            @{ Desc = "Write-Progress Completes"; Filter = { $Status -eq "Done" -and $PercentComplete -eq 100 } }
        ) {
            Should @m -Scope Context -Invoke "Write-Progress" -Exactly -Times 1 -ParameterFilter $Filter
        }

        It "Reports progress in increasing order" {
            Should @m -Scope Context -Invoke "Write-Progress" -Exactly -Times 9
        }
    }

    Context "Certificate provisioning enabled" {
        BeforeAll {
            . $StageMocks
            InModuleScope AxisPowerShell {
                $Script:Config.ProvisionCertificate = $true
                $Script:Config.Certificate = @{ DefaultAuthority = 'LabCA' }
            }
        }

        It "Runs Request-AxisCertificate for the device" {
            Invoke-AxisProvisioningTask -Device "192.168.1.100" -MacAddress "00-40-8c-00-00-01"

            Should @m -Invoke "Request-AxisCertificate" -Exactly -Times 1 -ParameterFilter { $Device -eq "192.168.1.100" }
            Should @m -Invoke "Write-Log" -Exactly -Times 1 -ParameterFilter { $Message -eq "Certificate: Installed - ok" }
        }

        It "Runs the certificate stage after the network stage and before the SD card stage" {
            $Script:Order = @()
            Mock @m Enable-AxisDNSUpdate     { $Script:Order += 'DNS' }
            Mock @m Request-AxisCertificate  { $Script:Order += 'Cert'; return [pscustomobject]@{Action = 'Installed'; Message = 'ok'} }
            Mock @m Format-AxisSDCard        { $Script:Order += 'SD' }

            Invoke-AxisProvisioningTask -Device "192.168.1.100" -MacAddress "00-40-8c-00-00-01"

            $Script:Order | Should -Be @('DNS','Cert','SD')
        }

        It "Skips the certificate stage when no DefaultAuthority is configured" {
            InModuleScope AxisPowerShell { $Script:Config.Certificate = @{ DefaultAuthority = '' } }

            Invoke-AxisProvisioningTask -Device "192.168.1.100" -MacAddress "00-40-8c-00-00-01"

            Should @m -Invoke "Request-AxisCertificate" -Exactly -Times 0
            InModuleScope AxisPowerShell { $Script:Config.Certificate = @{ DefaultAuthority = 'LabCA' } }
        }

        It "Continues with a warning when the firmware does not support certificate requests" {
            Mock @m Request-AxisCertificate { Throw "Command not supported on this device" }

            { Invoke-AxisProvisioningTask -Device "192.168.1.100" -MacAddress "00-40-8c-00-00-01" -WarningAction SilentlyContinue } | Should -Not -Throw

            Should @m -Invoke "Format-AxisSDCard" -Exactly -Times 1
            Should @m -Invoke "Write-Log" -Exactly -Times 1 -ParameterFilter { $Message -like "Certificate stage skipped: not supported*" }
        }

        It "Fails the job when the certificate request fails for another reason" {
            Mock @m Request-AxisCertificate { Throw "CA unreachable" }

            { Invoke-AxisProvisioningTask -Device "192.168.1.100" -MacAddress "00-40-8c-00-00-01" } | Should -Throw "CA unreachable"

            Should @m -Invoke "Format-AxisSDCard" -Exactly -Times 0
            Should @m -Invoke "Write-Log" -Exactly -Times 1 -ParameterFilter { $Message -eq "Failed to deploy certificate" }
        }
    }

    Context "Password stage" {
        BeforeAll {
            . $StageMocks
            InModuleScope AxisPowerShell { $Script:Config.ProvisionCertificate = $false }
        }

        It "Does not call Initialize-AxisDevice when the device already reports Ready" {
            Mock @m Get-AxisDeviceStatus { return [pscustomobject]@{Status = 'Ready'} }

            Invoke-AxisProvisioningTask -Device "192.168.1.100" -MacAddress "00-40-8c-00-00-01"

            Should @m -Invoke "Initialize-AxisDevice" -Exactly -Times 0
            Should @m -Invoke "Write-Log" -Exactly -Times 1 -ParameterFilter { $Message -eq "Device has already had password set" }
        }

        It "Calls Initialize-AxisDevice when the device is in factory default state" {
            Invoke-AxisProvisioningTask -Device "192.168.1.100" -MacAddress "00-40-8c-00-00-01"

            Should @m -Invoke "Initialize-AxisDevice" -Exactly -Times 1 -ParameterFilter { $Device -eq "192.168.1.100" }
            Should @m -Invoke "Write-Log" -Exactly -Times 1 -ParameterFilter { $Message -eq "Device in Factory default state" }
        }
    }

    Context "Stage failures" {
        BeforeAll {
            . $StageMocks
            InModuleScope AxisPowerShell { $Script:Config.ProvisionCertificate = $false }
        }

        It "<cmd> failure stops the job and is logged" -ForEach @(
            @{ cmd = "Update-AxisDevice";        LogMessage = "Failed to Update Device";                        NotCalled = "Initialize-AxisDevice" }
            @{ cmd = "Initialize-AxisDevice";    LogMessage = "Failed to set password";                         NotCalled = "Enable-AxisDNSUpdate" }
            @{ cmd = "Enable-AxisDNSUpdate";     LogMessage = "Failed to set DNS Hostname";                     NotCalled = "Set-AxisDSCP" }
            @{ cmd = "Set-AxisDSCP";             LogMessage = "Failed to set DSCP values";                      NotCalled = "Set-AxisServices" }
            @{ cmd = "Set-AxisServices";         LogMessage = "Failed to set security settings";                NotCalled = "Format-AxisSDCard" }
            @{ cmd = "Format-AxisSDCard";        LogMessage = "Failed to format SD Card";                       NotCalled = "Set-AxisStorageOptions" }
            @{ cmd = "Set-AxisStorageOptions";   LogMessage = "Failed to set retention";                        NotCalled = "New-AxisStreamProfile" }
            @{ cmd = "New-AxisStreamProfile";    LogMessage = "Failed to create Stream Profile";                NotCalled = "New-AxisRecordingProfile" }
            @{ cmd = "New-AxisRecordingProfile"; LogMessage = "Failed to create Continuious Recording Profile"; NotCalled = "Get-AxisSnapshot" }
            @{ cmd = "Get-AxisSnapshot";         LogMessage = "Failed to create snapshot from camera";          NotCalled = $null }
        ) {
            Mock @m $cmd { Throw "boom" }

            { Invoke-AxisProvisioningTask -Device "192.168.1.100" -MacAddress "00-40-8c-00-00-01" } | Should -Throw "boom"

            Should @m -Invoke "Write-Log" -Exactly -Times 1 -ParameterFilter { $Message -eq $LogMessage }
            Should @m -Invoke "Write-Log" -Exactly -Times 1 -ParameterFilter { $Message -eq "boom" }
            Should @m -Invoke "Write-Log" -Exactly -Times 0 -ParameterFilter { $Message -eq "Provisioning Complete" }
            Should @m -Invoke "Write-Progress" -Exactly -Times 0 -ParameterFilter { $Status -eq "Done" }
            if($NotCalled) {
                Should @m -Invoke $NotCalled -Exactly -Times 0
            }
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

#Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

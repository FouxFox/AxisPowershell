Describe "New-AxisRecordingProfile" {
    Context "SD Card not formatted" {
        BeforeAll {
            # Required Mock Functions
            Mock @m Get-AxisRecordingProfile {}
            Mock @m Get-AxisRecordingSupport { return @{NumberofLenses = 1} }
            Mock @m Invoke-AxisWebApi {}
        }

        It "<Desc>" -ForEach @(
            @{ Desc = "1/1 SD Cards bad";  Disks = @(@{Status = 'failed'}) }
            @{ Desc = "1/2 SD Cards bad";  Disks = @(@{Status = 'OK'},@{Status = 'failed'}) }
            @{ Desc = "2/2 SD Cards bad";  Disks = @(@{Status = 'failed'},@{Status = 'failed'}) }
            @{ Desc = "SD Card disconnected"; Disks = @(@{Status = 'disconnected'}) }
            @{ Desc = "No SD Card";        Disks = @() }
        ) {
            Mock @m Get-AxisSDCardStatus { return $Disks }
            { New-AxisRecordingProfile -Device "192.168.0.100" -StreamProfile "Recording" -Lens 1 } | Should -Throw "SD Card is not in a valid state"

            Should @m -Invoke "Get-AxisSDCardStatus" -ParameterFilter { $Device -eq "192.168.0.100" }
            Should @m -Invoke "Invoke-AxisWebApi" -Times 0 -Exactly
        }

        It "Accepts a mix of 'OK' and 'connected' disks" {
            Mock @m Get-AxisSDCardStatus { return @(@{Status = 'connected'},@{Status = 'OK'}) }
            Mock @m Invoke-AxisWebApi { return @{root=@{configure=@{result = 'OK'}}} }

            { New-AxisRecordingProfile -Device "192.168.0.100" -StreamProfile "Recording" -Lens 1 } | Should -Not -Throw

            Should @m -Invoke "Invoke-AxisWebApi" -Times 1 -Exactly
        }
    }

    Context "Parameters" {
        It "StreamProfile is mandatory" {
            (Get-Command New-AxisRecordingProfile).Parameters['StreamProfile'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }
    }

    Context "Single Lens" {
        BeforeAll {
            Mock @m Get-AxisSDCardStatus { return @{Status = 'OK'} }
            Mock @m Get-AxisRecordingSupport { return @{NumberofLenses = 1} }
        }

        It "Adds a continuous recording configuration for the lens and stream profile" {
            Mock @m Invoke-AxisWebApi { return @{root=@{configure=@{result = 'OK'}}} }
            Mock @m Get-AxisRecordingProfile {}

            New-AxisRecordingProfile -Device "192.168.0.100" -StreamProfile "Recording" -Lens 1

            Should @m -Invoke "Get-AxisSDCardStatus" -ParameterFilter { $Device -eq "192.168.0.100" }
            Should @m -Invoke "Get-AxisRecordingProfile" -ParameterFilter { $Device -eq "192.168.0.100" }
            Should @m -Invoke "Invoke-AxisWebApi" -Times 1 -Exactly -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path.StartsWith("/axis-cgi/record/continuous/addconfiguration.cgi?") -and
                $Path.Contains("diskid=SD_DISK&") -and
                $Path.Contains("options=camera%3D1%26streamprofile%3DRecording")
            }
        }

        It "Skips the lens when an operational recording profile already exists" {
            Mock @m Invoke-AxisWebApi { return @{root=@{configure=@{result = 'OK'}}} }
            Mock @m Get-AxisRecordingProfile { return [pscustomobject]@{Lens = 1; Status = 'OK'} }

            New-AxisRecordingProfile -Device "192.168.0.100" -StreamProfile "Recording" -Lens 1 -WarningVariable Warn -WarningAction SilentlyContinue

            $Warn | Should -Not -BeNullOrEmpty
            Should @m -Invoke "Invoke-AxisWebApi" -Times 0 -Exactly
        }

        It "Does not skip a lens whose existing profile is not 'OK'" {
            Mock @m Invoke-AxisWebApi { return @{root=@{configure=@{result = 'OK'}}} }
            Mock @m Get-AxisRecordingProfile { return [pscustomobject]@{Lens = 1; Status = 'Error'} }

            New-AxisRecordingProfile -Device "192.168.0.100" -StreamProfile "Recording" -Lens 1

            Should @m -Invoke "Invoke-AxisWebApi" -Times 1 -Exactly
        }

        It "Throws when the device does not answer OK" {
            Mock @m Invoke-AxisWebApi { return @{root=@{configure=@{result = 'Error'}}} }
            Mock @m Get-AxisRecordingProfile {}

            { New-AxisRecordingProfile -Device "192.168.0.100" -StreamProfile "Recording" -Lens 1 } | Should -Throw "Lens 1: Unable to add Continuious Recording Profile"
        }
    }

    Context "All Lenses" {
        BeforeAll {
            Mock @m Get-AxisRecordingProfile {}
            Mock @m Invoke-AxisWebApi { return @{root=@{configure=@{result = 'OK'}}} }
        }

        It "<Desc>" -ForEach @(
            @{
                Desc = "1 Lens, 1 SD Card"
                Lenses = 1
                Disks = @(@{Status = 'OK'})
                Expected = @{ 1 = 'SD_DISK' }
            }
            @{
                Desc = "2 Lenses, 1 SD Card"
                Lenses = 2
                Disks = @(@{Status = 'OK'})
                Expected = @{ 1 = 'SD_DISK'; 2 = 'SD_DISK' }
            }
            @{
                Desc = "4 Lenses, 1 SD Card"
                Lenses = 4
                Disks = @(@{Status = 'OK'})
                Expected = @{ 1 = 'SD_DISK'; 2 = 'SD_DISK'; 3 = 'SD_DISK'; 4 = 'SD_DISK' }
            }
            @{
                Desc = "4 Lenses, 2 SD Cards"
                Lenses = 4
                Disks = @(@{Status = 'OK'},@{Status = 'OK'})
                # Odd lenses (other than 1) go to the second card
                Expected = @{ 1 = 'SD_DISK'; 2 = 'SD_DISK'; 3 = 'SD_DISK2'; 4 = 'SD_DISK' }
            }
        ) {
            Mock @m Get-AxisSDCardStatus { return $Disks }
            Mock @m Get-AxisRecordingSupport { return @{NumberofLenses = $Lenses} }

            New-AxisRecordingProfile -Device "192.168.0.100" -StreamProfile "Recording"

            Should @m -Invoke "Get-AxisSDCardStatus"     -ParameterFilter { $Device -eq "192.168.0.100" }
            Should @m -Invoke "Get-AxisRecordingSupport" -ParameterFilter { $Device -eq "192.168.0.100" }
            Should @m -Invoke "Invoke-AxisWebApi" -Times $Lenses -Exactly

            ForEach ($L in $Expected.Keys) {
                $Disk = $Expected[$L]
                Should @m -Invoke "Invoke-AxisWebApi" -Times 1 -Exactly -ParameterFilter {
                    $Device -eq "192.168.0.100" -and
                    $Path.Contains("options=camera%3D$L%26streamprofile%3DRecording") -and
                    $Path.Contains("diskid=$Disk&options=camera%3D$L%26")
                }
            }
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

#Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

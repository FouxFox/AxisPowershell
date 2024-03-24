Describe "New-AxisRecordingProfile" {
    Context "SD Card not formatted" {
        BeforeAll {
            # Required Mock Functions
            Mock @m Get-AxisRecordingProfile {}
            Mock @m Invoke-AxisWebApi {}
        }

        It "1/1 SD Cards bad" {
            Mock @m Get-AxisSDCardStatus { return @{Status = 'failed'} }
            { New-AxisRecordingProfile -Device "192.168.0.100" -Lens 1 } | Should -Throw "SD Card is not in a valid state"

            Should @m -Invoke "Get-AxisSDCardStatus" -ParameterFilter { $Device -eq "192.168.0.100" }
        }

        It "1/2 SD Cards bad" {
            Mock @m Get-AxisSDCardStatus { return @(@{Status = 'OK'},@{Status = 'failed'}) }
            { New-AxisRecordingProfile -Device "192.168.0.100" -Lens 1 } | Should -Throw "SD Card is not in a valid state"

            Should @m -Invoke "Get-AxisSDCardStatus" -ParameterFilter { $Device -eq "192.168.0.100" }
        }

        It "2/2 SD Cards bad" {
            Mock @m Get-AxisSDCardStatus { return @(@{Status = 'failed'},@{Status = 'failed'}) }
            { New-AxisRecordingProfile -Device "192.168.0.100" -Lens 1 } | Should -Throw "SD Card is not in a valid state"

            Should @m -Invoke "Get-AxisSDCardStatus" -ParameterFilter { $Device -eq "192.168.0.100" }
        }
    }

    #Need to rehas this to actually test for the other lenses and SD cards
    Context -Tag "Test" "Variations on All Lenses" {
        It "<Desc>" -ForEach @(
            @{
                Desc = "1 Lens, 1 SD Card"
                LensScript = {return @{NumberofLenses = 1}}
                SDScript = { return @{Status = 'OK'} }
                InvokeScript = { return @{root=@{configure=@{result = 'OK'}}} }
                URIString = { $Path.contains("diskid=SD_DISK") -and $Path.contains("camera%3D1") }
                TestCases = @(
                    "Mocks"
                    "Invoke"
                )
            }
            @{
                Desc = "2 Lenses, 1 SD Card"
                LensScript = {return @{NumberofLenses = 2}}
                SDScript = { return @{Status = 'OK'} }
                InvokeScript = { return @{root=@{configure=@{result = 'OK'}}} }
                URIString = { $Path.contains("diskid=SD_DISK") -and $Path.contains("camera%3D1") }
                TestCases = @(
                    "Mocks"
                    "Invoke"
                )
            }
            @{
                Desc = "4 Lenses, 1 SD Card"
                LensScript = {return @{NumberofLenses = 1}}
                SDScript = { return @{Status = 'OK'} }
                InvokeScript = { return @{root=@{configure=@{result = 'OK'}}} }
                URIString = { $Path.contains("diskid=SD_DISK") -and $Path.contains("camera%3D1") }
                TestCases = @(
                    "Mocks"
                    "Invoke"
                )
            }
            @{
                Desc = "4 Lenses, 2 SD Cards"
                LensScript = {return @{NumberofLenses = 1}}
                SDScript = { return @{Status = 'OK'} }
                InvokeScript = { return @{root=@{configure=@{result = 'OK'}}} }
                URIString = { $Path.contains("diskid=SD_DISK") -and $Path.contains("camera%3D1") }
                TestCases = @(
                    "Mocks"
                    "Invoke"
                )
            }
        ) {
            Mock @m Invoke-AxisWebApi $InvokeScript
            Mock @m Get-AxisSDCardStatus $SDScript
            Mock @m Get-AxisRecordingSupport $LensScript
            Mock @m Get-AxisRecordingProfile {}
            if($TestCases.contains("Throw")) {
                { New-AxisRecordingProfile -Device "192.168.0.100" } | Should -Throw
            }
            else {
                New-AxisRecordingProfile -Device "192.168.0.100"
            }

            if($TestCases.contains("Mocks")) {
                Should @m -Invoke "Get-AxisSDCardStatus"     -ParameterFilter { $Device -eq "192.168.0.100" }
                Should @m -Invoke "Get-AxisRecordingSupport" -ParameterFilter { $Device -eq "192.168.0.100" }
            }

            if($TestCases.contains("Invoke")) {
                Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter $URIString
            }
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

#Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
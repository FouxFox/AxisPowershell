Describe "Set-AxisParameter" {
    Context "Single parameter" {
        It "Calls param.cgi with action=update and the encoded value" {
            Mock @m Invoke-AxisWebApi { return 'OK' }

            Set-AxisParameter -Device "192.168.0.100" -Parameter "Network.Bonjour.FriendlyName" -Value "Front Door"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/param.cgi?action=update&Network.Bonjour.FriendlyName=Front%20Door"
            }
        }

        It "Throws when the device does not answer OK" {
            Mock @m Invoke-AxisWebApi { return '# Error: Error setting value' }

            { Set-AxisParameter -Device "192.168.0.100" -Parameter "Brightness" -Value "50" } | Should -Throw "Unable to update parameter(s)"
        }
    }

    Context "Multiple parameters" {
        It "Puts every key of the ParameterSet in the query string" {
            Mock @m Invoke-AxisWebApi { return 'OK' }

            Set-AxisParameter -Device "192.168.0.100" -ParameterSet @{ Brightness = "50"; Contrast = "75" }

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Path.StartsWith("/axis-cgi/param.cgi?action=update&") -and
                $Path.Contains("&Brightness=50") -and
                $Path.Contains("&Contrast=75")
            }
        }
    }

    Context "Alias" {
        It "Is reachable as Update-AxisParameter" {
            $Alias = Get-Alias -Name Update-AxisParameter -ErrorAction Stop
            $Alias.ResolvedCommandName | Should -Be "Set-AxisParameter"
        }

        It "Alias performs the same request" {
            Mock @m Invoke-AxisWebApi { return 'OK' }

            Update-AxisParameter -Device "192.168.0.100" -Parameter "Brightness" -Value "50"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Path -eq "/axis-cgi/param.cgi?action=update&Brightness=50"
            }
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

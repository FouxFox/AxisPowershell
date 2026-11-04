Describe "Initialize-AxisDevice" {
    BeforeAll {
        Mock @m Add-AxisUserAccount {}
        Mock @m Write-Host {}
    }

    Context "Device already initialized" {
        It "Skips and does not create a root account" {
            Mock @m Get-AxisDeviceStatus { return [pscustomobject]@{ Status = "Ready" } }

            Initialize-AxisDevice -Device "192.168.0.100"

            Should @m -Not -Invoke "Add-AxisUserAccount"
            Should @m -Invoke "Write-Host" -Exactly -Times 1 -ParameterFilter { $Object -like "*Skipping initialization*" }
        }
    }

    Context "Factory default device" {
        BeforeAll {
            Mock @m Get-AxisDeviceStatus { return [pscustomobject]@{ Status = "Needs Setup" } }
        }

        It "Creates root with the stored module credential when no password is given" {
            Initialize-AxisDevice -Device "192.168.0.100"

            Should @m -Invoke "Add-AxisUserAccount" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Credential.UserName -eq $TestCredential.UserName -and
                $AsRoot -eq $true -and
                $NoAuth -eq $true
            }
        }

        It "Creates root with the supplied password" {
            $Pw = ConvertTo-SecureString -AsPlainText -Force "P@ssw0rd"

            Initialize-AxisDevice -Device "192.168.0.100" -NewPassword $Pw

            Should @m -Invoke "Add-AxisUserAccount" -Exactly -Times 1 -ParameterFilter {
                $Credential.UserName -eq "root" -and
                $Credential.GetNetworkCredential().Password -eq "P@ssw0rd" -and
                $AsRoot -eq $true -and
                $NoAuth -eq $true
            }
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

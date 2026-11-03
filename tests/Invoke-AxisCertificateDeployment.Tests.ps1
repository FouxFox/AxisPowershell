Describe "Invoke-AxisCertificateDeployment" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        InModuleScope AxisPowerShell {
            $Script:Config.CertificateAuthorities = @{ TestCA = @{ Type = "Command"; Template = "server"; SignCommand = "fake" } }
            $Script:Config.Certificate = @{ DefaultAuthority = "TestCA"; Alias = "AxisPowershell"; RenewWithinDays = 30; HttpsOnly = $true }
        }
    }

    BeforeEach {
        Mock @m Check-Credential { }
        Mock @m Write-Log { }
        Mock @m Request-AxisCertificate {
            [pscustomobject]@{ Device = $Device; Action = "Issued"; Alias = "AxisPowershell"; Subject = "CN=x"; Serial = "01"; NotAfter = (Get-Date).AddYears(1); Thumbprint = "T"; HttpsVerified = $true; RevokedSerial = $null; Authority = "TestCA"; Message = "ok" }
        }
    }

    It "Runs Request-AxisCertificate for every unique device and returns one row each" {
        $Results = Invoke-AxisCertificateDeployment -IP 10.0.0.1,10.0.0.2,10.0.0.1 -SingleThreaded
        $Results.Count | Should -Be 2
        $Results.Action | Should -Be @("Issued","Issued")
        Should @m -Invoke "Request-AxisCertificate" -Times 2 -Exactly
        Should @m -Invoke "Request-AxisCertificate" -ParameterFilter { $CertificateAuthority -eq "TestCA" } -Times 2
    }

    It "Turns a per-device exception into a Failed row and continues" {
        Mock @m Request-AxisCertificate {
            if($Device -eq "10.0.0.1") { Throw "camera offline" }
            [pscustomobject]@{ Device = $Device; Action = "Issued"; Alias = "a"; Subject = "s"; Serial = "1"; NotAfter = (Get-Date); Thumbprint = "T"; HttpsVerified = $true; RevokedSerial = $null; Authority = "TestCA"; Message = "" }
        }
        $Results = Invoke-AxisCertificateDeployment -IP 10.0.0.1,10.0.0.2 -SingleThreaded
        ($Results | Where-Object Device -eq "10.0.0.1").Action | Should -Be "Failed"
        ($Results | Where-Object Device -eq "10.0.0.1").Message | Should -Be "camera offline"
        ($Results | Where-Object Device -eq "10.0.0.2").Action | Should -Be "Issued"
    }

    It "Mode Apply skips devices that already have a CA-issued certificate" {
        Mock @m Get-AxisCertificate {
            if($Device -eq "10.0.0.1") { return @([pscustomobject]@{ Alias = "AxisPowershell"; Subject = "CN=a"; Issuer = "CN=CA" }) }
            return @()
        }
        $Results = Invoke-AxisCertificateDeployment -IP 10.0.0.1,10.0.0.2 -Mode Apply -SingleThreaded
        ($Results | Where-Object Device -eq "10.0.0.1").Action | Should -Be "Skipped"
        ($Results | Where-Object Device -eq "10.0.0.2").Action | Should -Be "Issued"
        Should @m -Invoke "Request-AxisCertificate" -Times 1 -Exactly
    }

    It "Mode Renew skips devices without a CA-issued certificate" {
        Mock @m Get-AxisCertificate { return @() }
        $Results = Invoke-AxisCertificateDeployment -IP 10.0.0.1 -Mode Renew -SingleThreaded
        $Results.Action | Should -Be "Skipped"
        Should @m -Invoke "Request-AxisCertificate" -Times 0
    }

    It "Reads devices from a CSV file and writes a report" {
        $In = Join-Path $TestDrive "cams.csv"
        "Site,IP`nA,10.0.0.5`nB,10.0.0.6" | Set-Content $In
        $Out = Join-Path $TestDrive "report.csv"
        $Results = Invoke-AxisCertificateDeployment -InputFile $In -ReportPath $Out -SingleThreaded
        $Results.Count | Should -Be 2
        (Import-Csv $Out).Count | Should -Be 2
        (Import-Csv $Out)[0].Device | Should -Be "10.0.0.5"
    }

    It "Passes -Force and -RenewWithinDays through" {
        $null = Invoke-AxisCertificateDeployment -IP 10.0.0.1 -Force -RenewWithinDays 60 -SingleThreaded
        Should @m -Invoke "Request-AxisCertificate" -ParameterFilter { $Force -eq $true -and $RenewWithinDays -eq 60 } -Times 1
    }

    It "Throws when the authority is unknown" {
        { Invoke-AxisCertificateDeployment -IP 10.0.0.1 -CertificateAuthority Nope -SingleThreaded } | Should -Throw "*not configured*"
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }

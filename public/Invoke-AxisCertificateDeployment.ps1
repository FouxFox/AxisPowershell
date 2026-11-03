<#
.SYNOPSIS
Deploys or renews CA-issued certificates on many Axis devices in parallel.

.DESCRIPTION
Runs Request-AxisCertificate against a list of devices (given, read from a file, or discovered on the local
network by Axis MAC prefix) using a runspace pool, and returns one result row per device. Use -Mode to limit the
run to first-time deployment (Apply), renewals (Renew) or both (Auto, default). Devices whose certificate is
still valid are reported as Current and left alone, so the command is safe to schedule for lifecycle management.
Per-device log files are written when logging is enabled (Set-AxisPSConfig -EnableLogging).

.PARAMETER IP
IP addresses or hostnames of the devices.

.PARAMETER InputFile
A text file with one device per line, or a CSV with an IP (or Device) column.

.PARAMETER InterfaceIP
Discover devices on the subnet of this local interface instead of supplying a list.

.PARAMETER CertificateAuthority
Name of a configured authority. Defaults to the template's DefaultAuthority.

.PARAMETER Mode
Auto (default): issue where missing, renew where expiring. Apply: only devices without a CA-issued certificate.
Renew: only devices that already have one.

.PARAMETER RenewWithinDays
Renewal window override.

.PARAMETER Force
Re-issue on every device, including devices with valid certificates.

.PARAMETER NoRevoke
Do not revoke superseded certificates on the CA.

.PARAMETER ThrottleLimit
Maximum parallel devices. Default 10, to keep the CA responsive.

.PARAMETER ReportPath
Write the results to this CSV file as well.

.EXAMPLE
Invoke-AxisCertificateDeployment -IP 192.168.1.10,192.168.1.11 -CertificateAuthority CorpCA

.EXAMPLE
Invoke-AxisCertificateDeployment -InputFile .\cameras.csv -Mode Renew -ReportPath .\renewals.csv
#>
function Invoke-AxisCertificateDeployment {
    [cmdletbinding(DefaultParameterSetName='IP')]
    Param(
        [Parameter(Mandatory,ParameterSetName='IP')]
        [String[]]$IP,

        [Parameter(Mandatory,ParameterSetName='File')]
        [String]$InputFile,

        [Parameter(Mandatory,ParameterSetName='Discover')]
        [String]$InterfaceIP,

        [Parameter()]
        [String]$CertificateAuthority,

        [Parameter()]
        [ValidateSet("Auto","Apply","Renew")]
        [String]$Mode="Auto",

        [Parameter()]
        [Int]$RenewWithinDays,

        [Parameter()]
        [Switch]$Force,

        [Parameter()]
        [Switch]$NoRevoke,

        [Parameter()]
        [ValidateRange(1,50)]
        [Int]$ThrottleLimit=10,

        [Parameter()]
        [String]$ReportPath,

        [Parameter(DontShow)]
        [Switch]$SingleThreaded
    )

    Check-Credential
    #Fail early if the authority is not configured
    $Authority = Resolve-AxisCertificateAuthority -Name $CertificateAuthority

    $ModuleString = "AxisPowershell"
    if($env:TestModulePath) {
        $ModuleString = $env:TestModulePath
    }

    ######################
    ## Build target list ##
    ######################
    $TargetDevices = @()
    switch($PSCmdlet.ParameterSetName) {
        "IP" {
            $TargetDevices = $IP
        }
        "File" {
            $Content = Get-Content -Path $InputFile | Where-Object { $_.Trim() -ne "" }
            if($Content[0] -match ',') {
                $Csv = $Content | ConvertFrom-Csv
                $Column = @($Csv[0].PSObject.Properties.Name) | Where-Object { $_ -in "IP","Device","IPAddress","Host" } | Select-Object -First 1
                if(!$Column) { Throw "CSV file needs an IP, Device, IPAddress or Host column." }
                $TargetDevices = $Csv.$Column
            }
            else {
                $TargetDevices = $Content | ForEach-Object { $_.Trim() }
            }
        }
        "Discover" {
            #Same OUI filter as New-AxisProvisioningJob
            $AxisOUIs = @(
                "e8-27-25"
                "00-40-8c"
                "b8-a4-4f"
                "ac-cc-8e"
            )
            $ipInfo = Get-NetIPAddress $InterfaceIP
            $IPRange = Out-SubnetRange -Subnet $ipInfo.IPAddress -Prefix $ipInfo.PrefixLength
            $TargetDevices = (Find-LANHosts -IP $IPRange | Where-Object { $_.MACAddress -match "($($AxisOUIs -join '|'))" }).IP
        }
    }
    $TargetDevices = @($TargetDevices | Where-Object { $_ } | Select-Object -Unique)

    if($TargetDevices.Count -eq 0) {
        Throw "No Axis Devices Found"
    }
    Write-Verbose "Deploying certificates from $($Authority.Name) to $($TargetDevices.Count) device(s), mode $Mode"

    $RequestParam = @{
        CertificateAuthority = $Authority.Name
        Force = [bool]$Force
        NoRevoke = [bool]$NoRevoke
    }
    if($RenewWithinDays) { $RequestParam.Add('RenewWithinDays',$RenewWithinDays) }

    #Per-device work: Mode filter, then Request-AxisCertificate; every outcome becomes a row
    $Worker = {
        param($Device, $Mode, $RequestParam)

        $Row = [pscustomobject]@{
            Device = $Device
            Action = "Failed"
            Alias = $null
            Subject = $null
            Serial = $null
            NotAfter = $null
            Thumbprint = $null
            HttpsVerified = $false
            RevokedSerial = $null
            Authority = $RequestParam.CertificateAuthority
            Message = ""
        }

        Try {
            if($Mode -ne "Auto") {
                $Alias = $Config.Certificate.Alias
                $HasCert = [bool](Get-AxisCertificate -Device $Device | Where-Object { ($_.Alias -eq $Alias -or $_.Alias -like "$Alias-*") -and $_.Issuer -ne $_.Subject })
                if($Mode -eq "Apply" -and $HasCert) {
                    $Row.Action = "Skipped"
                    $Row.Message = "Already has a CA-issued certificate (Mode Apply)"
                    return $Row
                }
                if($Mode -eq "Renew" -and !$HasCert) {
                    $Row.Action = "Skipped"
                    $Row.Message = "No CA-issued certificate to renew (Mode Renew)"
                    return $Row
                }
            }

            Write-Log -ID $Device -Message "Certificate deployment started"
            $Row = Request-AxisCertificate -Device $Device @RequestParam
            Write-Log -ID $Device -Message "Certificate deployment: $($Row.Action) - $($Row.Message)"
        }
        Catch {
            $Row.Message = $_.Exception.Message
            Write-Log -ID $Device -Message "Certificate deployment failed: $($Row.Message)"
        }

        return $Row
    }

    $Results = @()

    ##Single Thread
    if($SingleThreaded) {
        ForEach($Device in $TargetDevices) {
            $Results += & $Worker $Device $Mode $RequestParam
        }
    }
    else {
        ##MultiThreaded
        $runspacePool = [runspacefactory]::CreateRunspacePool(1, $ThrottleLimit)
        $runspacePool.Open()

        $ScriptBlock = {
            param($RuntimeData)
            Import-Module $RuntimeData.ModulePath
            Set-AxisCredential -Credential $RuntimeData.Credential
            #Run the worker inside the module so it sees $Config and private functions
            $Module = Get-Module AxisPowershell
            & $Module ([scriptblock]::Create($RuntimeData.Worker)) $RuntimeData.Device $RuntimeData.Mode $RuntimeData.RequestParam
        }

        #@() keeps a single job an array on Windows PowerShell 5.1 (otherwise .Count is null -> divide by zero)
        $jobs = @(ForEach($Device in $TargetDevices) {
            $RuntimeData = @{
                ModulePath = $ModuleString
                Credential = $Config.Credential
                Worker = $Worker.ToString()
                Device = $Device
                Mode = $Mode
                RequestParam = $RequestParam
            }
            $PowerShell = [powershell]::Create().AddScript($ScriptBlock).AddArgument($RuntimeData)
            $PowerShell.RunspacePool = $runspacePool
            [pscustomobject]@{
                Device = $Device
                PowerShell = $PowerShell
                Handle = $PowerShell.BeginInvoke()
            }
        })

        $Total = $jobs.Count
        While($jobs | Where-Object { !$_.Handle.IsCompleted }) {
            $Done = ($jobs | Where-Object { $_.Handle.IsCompleted }).Count
            Write-Progress -Activity "Deploying certificates" -Status "$Done of $Total devices complete" -PercentComplete (100 * $Done / $Total)
            Start-Sleep -Milliseconds 500
        }
        Write-Progress -Activity "Deploying certificates" -Completed

        ForEach($job in $jobs) {
            Try {
                $Output = $job.PowerShell.EndInvoke($job.Handle)
                $Row = $Output | Where-Object { $_.PSObject.Properties.Name -contains "Action" } | Select-Object -Last 1
                if(!$Row) {
                    $Row = [pscustomobject]@{ Device = $job.Device; Action = "Failed"; Alias = $null; Subject = $null; Serial = $null; NotAfter = $null; Thumbprint = $null; HttpsVerified = $false; RevokedSerial = $null; Authority = $Authority.Name; Message = "No result returned" }
                }
                if($job.PowerShell.Streams.Error.Count -gt 0 -and $Row.Action -eq "Failed" -and !$Row.Message) {
                    $Row.Message = $job.PowerShell.Streams.Error[0].ToString()
                }
                $Results += $Row
            }
            Catch {
                $Results += [pscustomobject]@{ Device = $job.Device; Action = "Failed"; Alias = $null; Subject = $null; Serial = $null; NotAfter = $null; Thumbprint = $null; HttpsVerified = $false; RevokedSerial = $null; Authority = $Authority.Name; Message = $_.Exception.Message }
            }
            Finally {
                $job.PowerShell.Dispose()
            }
        }

        $runspacePool.Close()
        $runspacePool.Dispose()
    }

    if($ReportPath) {
        $Results | Select-Object Device, Action, Alias, Subject, Serial, NotAfter, Thumbprint, HttpsVerified, RevokedSerial, Authority, Message |
            Export-Csv -Path $ReportPath -NoTypeInformation
        Write-Verbose "Report written to $ReportPath"
    }

    $Summary = $Results | Group-Object Action | ForEach-Object { "$($_.Name): $($_.Count)" }
    Write-Verbose "Deployment complete - $($Summary -join ', ')"

    return $Results
}

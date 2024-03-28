<#
.SYNOPSIS
Creates a new Axis provisioning job.

.DESCRIPTION
The New-AxisProvisioningJob function creates a new provisioning job for Axis devices.
It allows you to specify a list of IP addresses or automatically discover devices on the local network.

.PARAMETER IP
Specifies the IP addresses of the target devices. 
If not provided, the function will automatically discover devices on the local network.

.EXAMPLE
New-AxisProvisioningJob -IP 192.168.1.10,192.168.1.20
Creates a new provisioning job for the specified IP addresses.

.EXAMPLE
New-AxisProvisioningJob
Creates a new provisioning job by automatically discovering devices on the local network.
#>
function New-AxisProvisioningJob {
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [String[]]$IP
    )

    Check-Credential
    
    if(!$Config.FirmwareFolder) {
        Throw "Firmware Folder not set. Please use Set-AxisPSConfig to set the firmware folder."
    }

    $TargetDevices = @()
    $ModuleString = "AxisPowershell"
    if($env:TestModulePath) {
        $ModuleString = $env:TestModulePath
    }

    $AxisOUIs = @(
        "e8-27-25"
        "00-40-8c"
        "b8-a4-4f"
        "ac-cc-8e"
    )

    if(!$IP) {
        $ipInfo = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceIndex -ne 1 }
        $IPRange = Out-SubnetRange -Subnet $ipInfo.IPAddress -Prefix $ipInfo.PrefixLength
        $TargetDevices = Find-LANHosts -IP $IPRange | Where-Object { $_.MACAddress -match "($($AxisOUIs -join '|'))" }
    }
    else {
        ForEach ($item in $IP) {
            $TargetDevices += [pscustomobject]@{
                IP = $item
                MacAddress = $item
            }
        }
    }
    
    if($TargetDevices.Count -eq 0) {
        Throw "No Axis Devices Found"
    }

    $runspacePool = [runspacefactory]::CreateRunspacePool(1, 255)
    $runspacePool.Open()

    $ScriptBlock = {
        param($RuntimeData)
        Import-Module $RuntimeData.ModulePath
        Set-AxisCredential -Credential $RuntimeData.Credential
        "$($RuntimeData.Device.MacAddress)): Starting Provisioning"
        Provision-AxisDevice -Device $RuntimeData.Device.IP -MacAddress $RuntimeData.Device.MacAddress
        "$($RuntimeData.Device.MacAddress)): Complete"
    }
    

    $jobs = foreach ($Device in $TargetDevices) {
        $RuntimeData = @{
            Device = $Device
            ModulePath = $ModuleString
            Credential = $Config.Credential
        }

        $runspace = [powershell]::Create().AddScript($ScriptBlock).AddArgument($RuntimeData)
        $runspace.RunspacePool = $runspacePool
        
        [PSCustomObject]@{
            RuntimeData = $RuntimeData
            Handle = $runspace.BeginInvoke()
            Pipe = $runspace
        }
    }

    Write-Verbose "Jobs Sent"

    #$jobs.pipe[0].Streams.Progress[0].StatusDescription
    while ($jobs.Handle.IsCompleted -notcontains $true) {
        Clear-Host
        ForEach ($item in $Jobs) {
            $ProgressIndex = $item.Pipe.Streams.Progress.count - 1
            if($item.Pipe.HadErrors) {
                Write-Host "$($item.RuntimeData.Device.MacAddress): ERROR - $($item.Pipe.InvocationStateInfo.Reason.Message)"
                return
            }
            Write-Host "$($item.RuntimeData.Device.MacAddress): $($item.Pipe.Streams.Progress[$ProgressIndex].StatusDescription)"
        }
        Start-Sleep -Seconds 5
    }

    Clear-Host
    foreach ($item in $jobs) {
        # EndInvoke method retrieves the results of the asynchronous call
        if($item.pipe.HadErrors) {
            Write-Host "$($item.RuntimeData.Device.MacAddress): ERROR - $($item.Pipe.InvocationStateInfo.Reason.Message)"
            return
        }
        Write-Host "$($item.RuntimeData.Device.MacAddress): Provisioning Complete"
        $item.Pipe.Dispose()
    }

    $runspacePool.Close()
    $runspacePool.Dispose()
}
<#
.SYNOPSIS
Enables DNS update for an Axis device.

.DESCRIPTION
The Enable-AxisDNSUpdate function enables DNS update for an Axis device by updating the device's configuration and forcing a DNS update.

.PARAMETER Device
The name or IP address of the Axis device.

.PARAMETER Hostname
The hostname to be updated in the DNS.

.EXAMPLE
Enable-AxisDNSUpdate -Device "192.168.1.100" -Hostname "axis-camera"

This example enables DNS update for the Axis device with the IP address "192.168.1.100" and updates the hostname to "axis-camera".

#>
function Enable-AxisDNSUpdate {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$true)]
        [String]$Hostname
    )

    #Update Configuration
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=update&Network.DNSUpdate.DNSName=$Hostname&Network.DNSUpdate.Enabled=yes"
    }

    Write-Host "$($Device): Setting Configuration..." -NoNewline
    Try {
        $null = Invoke-AxisWebApi @Param 
        Write-Host -ForegroundColor Green "OK!"
    } Catch {
        Write-Host -ForegroundColor Red "Failed!"
        Throw
    }
    
    #Force DNS Update
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/dnsupdate.cgi?add=$Hostname&hdgen=yes"
        Method = "Get"
    }
    
    Write-Host "$($Device): Forcing DNS Update..." -NoNewline
    Try {
        $null = Invoke-AxisWebApi @Param 
        Write-Host -ForegroundColor Green "OK!"
    } Catch {
        Write-Host -ForegroundColor Red "Failed!"
        Throw
    }
}
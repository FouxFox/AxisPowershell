<#
.SYNOPSIS
Enables the Dynamic DNS update functionality for an Axis device.

.DESCRIPTION
The Enable-AxisDNSUpdate function configures the Axis device to periodically send DNS updates to the DNS server. 
This allows the device to be accessed by a hostname instead of an IP address.

The function also forces a DNS update to ensure the hostname is immediately available though on older models this may not be supported.

.PARAMETER Device
The hostname or IP address of the Axis device.

.PARAMETER Hostname
The hostname to be updated in the DNS. 
If no hostname is provided, the serail number of the device is used in the following format:
axis-<SerialNumber>.<DNS Suffix>

.EXAMPLE
Enable-AxisDNSUpdate -Device "192.168.1.100" -Hostname "axis-camera.example.com"

Setting Configuration...OK!
Forcing DNS Update...OK!

#>
function Enable-AxisDNSUpdate {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [String]$Hostname
    )

    if(!$Hostname) {
        $NewHostName = "axis-$((Get-AxisDeviceInfo -Device $Device).SerialNumber).$($Config.DNSSuffix)"
    }
    else {
        $NewHostName = $Hostname
    }

    #Update Configuration
    $Param = @{
        'Network.DNSUpdate.DNSName' = $NewHostname
        'Network.DNSUpdate.Enabled' = 'yes'
    }

    Write-Host "$($Device): Setting Configuration..." -NoNewline
    Try {
        Update-AxisParameter -Device $Device -ParameterSet $Param
        Write-Host -ForegroundColor Green "OK!"
    } Catch {
        Write-Host -ForegroundColor Red "Failed!"
        Throw
    }
    
    #Force DNS Update
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/dnsupdate.cgi?add=$NewHostname&hdgen=yes"
        Method = "Get"
    }
    
    Write-Host "$($Device): Forcing DNS Update..." -NoNewline
    Try {
        $null = Invoke-AxisWebApi @Param 
        Write-Host -ForegroundColor Green "OK!"
    } Catch {
        #This functionality is not supported on older devices
        Write-Host -ForegroundColor Yellow "Failed Successfully!"
    }
}
<#
.SYNOPSIS
Retrieves NTP client information from an Axis device.

.DESCRIPTION
The Get-AxisNTPClient function retrieves NTP client information from an Axis device.

.PARAMETER Device
Specifies the IP address or hostname of the Axis device.

.EXAMPLE
Get-AxisNTPClient -Device 192.168.1.100

This example retrieves NTP client information from the Axis device with the IP address "192.168.1.100".

.OUTPUTS
The function returns a custom object with the following properties:
- Enabled: Indicates whether the NTP client is enabled.
- NTSecurity: Indicates whether NT security is enabled.
- ConfigurationSource: Indicates the source of the NTP server configuration.
- Servers: The list of NTP servers used by the client.
- KEServers: The list of NTS key exchange servers used by the client.
- FallbackServers: The list of fallback NTP servers used by the client.
- Synced: Indicates whether the client is synchronized with the NTP server.
- TimeToNextSync: The time remaining until the next synchronization.
- TimeOffset: The time offset between the client and the NTP server.
#>
function Get-AxisNTPClient {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/ntp.cgi"
        Method = "Post"
        Body = @{
            "apiVersion" = '1.0'
            "method" = "getNTPInfo"
        }
    }

    $result = Invoke-AxisWebApi @Param

    if($result.error) {
        Write-Warning $result.error.message
    }

    #Create base object
    $NTPClient = $result.data.client
    $ResultObj = [ordered]@{
        Enabled = $NTPClient.Enabled
        NTSecurity = $NTPClient.NTSEnabled
        ConfigurationSource = $NTPClient.serversSource
        Servers = ''
        KEServers = 'N/A'
        FallbackServers = 'N/A'
        Synced = $NTPClient.Synced
        TimeToNextSync = $NTPClient.TimeToNextSync
        TimeOffset = 'N/A'
    }

    #If DHCP, populate from advertisedServers
    if($NTPClient.serversSource -eq 'DHCP') {
        $ResultObj.Servers = $NTPClient.advertisedServers -join ', '
        if($NTPClient.staticServers) {
            $ResultObj.FallbackServers = $NTPClient.staticServers -join ', '
        }
    }
    else {
        $ResultObj.Servers = $NTPClient.staticServers -join ', '
    }

    #Populate KEServers if NTS is enabled
    if($NTPClient.NTSEnabled) {
        $ResultObj.KEServers = $NTPClient.staticNTSKEServers -join ', '
    }

    #Populate Time Offset if time is synced
    if($NTPClient.synced) {
        $ResultObj.TimeOffset = [math]::Round($NTPClient.TimeOffset,2)
    }

    [PSCustomObject]$ResultObj
}
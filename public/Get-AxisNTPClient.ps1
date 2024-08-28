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
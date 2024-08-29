<#
.SYNOPSIS
Sets the NTP client configuration for an Axis device.

.DESCRIPTION
The Set-AxisNTPClient function is used to configure the NTP (Network Time Protocol) client settings for an Axis device.
It allows you to specify whether the device should obtain its time settings from a DHCP server, use static NTP servers, or disable NTP synchronization altogether.

.PARAMETER Device
Specifies the device for which the NTP client configuration should be set.

.PARAMETER Disable
Indicates whether NTP synchronization should be disabled. 
If this switch is specified, the NTP client will be disabled on the device.

.PARAMETER DHCP
Indicates that the device should obtain its NTP settings from a DHCP server.

.PARAMETER FallbackServers
Specifies a comma-separated list of fallback NTP servers to be used if DHCP fails to provide NTP settings.

.PARAMETER Servers
Specifies a comma-separated list of static NTP servers to be used.

.PARAMETER NTSecurity
Enables NT security for NTP communication.

.PARAMETER KEServers
Specifies a comma-separated list of static NTP key exchange (KE) servers to be used.

.EXAMPLE
Set-AxisNTPClient -Device 192.168.1.10 -DHCP -FallbackServers "ntp1.example.com,ntp2.example.com"
Configures the NTP client to obtain its NTP settings from a DHCP server and use "ntp1.example.com" and "ntp2.example.com" as fallback servers.

.EXAMPLE
Set-AxisNTPClient -Device 192.168.1.10 -Static -Servers "ntp1.example.com,ntp2.example.com"
Configures the NTP client to use "ntp1.example.com" and "ntp2.example.com" as static NTP servers.

.EXAMPLE
Set-AxisNTPClient -Device 192.168.1.10 -Disabled
Disables the NTP client.
#>
function Set-AxisNTPClient {
    [cmdletbinding(DefaultParameterSetName='DHCP')]
    Param(
        [Parameter(Mandatory,ParameterSetName='DHCP')]
        [Parameter(Mandatory,ParameterSetName='Static')]
        [Parameter(Mandatory,ParameterSetName='Disabled')]
        [String]$Device,

        [Parameter(Mandatory,ParameterSetName='Disabled')]
        [Switch]$Disable,

        [Parameter(Mandatory,ParameterSetName='DHCP')]
        [Switch]$DHCP,

        [Parameter(ParameterSetName='DHCP')]
        [String]$FallbackServers,

        [Parameter(Mandatory,ParameterSetName='Static')]
        [String]$Servers,

        [Parameter(ParameterSetName='DHCP')]
        [Parameter(ParameterSetName='Static')]
        [Switch]$NTSecurity,

        [Parameter(ParameterSetName='DHCP')]
        [Parameter(ParameterSetName='Static')]
        [String]$KEServers
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/ntp.cgi"
        Method = "Post"
        Body = @{
            "apiVersion" = '1.0'
            "method" = "setNTPClientConfiguration"
            "params" = @{}
        }
    }

    #Shorthand for request parameters to simplify code
    $ReqParams = $Param.Body.params

    if($PSCmdlet.ParameterSetName -eq 'Disabled') {
        $ReqParams.Add("enabled",$false)
    }
    else {
        $ReqParams.Add("enabled",$true)
    }

    if($NTSecurity.IsPresent -or $KEServers) {
        $ReqParams.Add("NTSEnabled",$NTSecurity)
    }

    if($KEServers) {
        $ReqParams.Add("staticNTSKEServers",($KEServers -split ','))
    }
    
    if($PSCmdlet.ParameterSetName -eq 'DHCP') {
        $ReqParams.Add("serversSource","DHCP")
        if($FallbackServers) {
            $ReqParams.Add("staticServers",($FallbackServers -split ','))
        }
    }
    
    if($PSCmdlet.ParameterSetName -eq 'Static') {
        $ReqParams.Add("serversSource","Static")
        $ReqParams.Add("staticServers",($Servers -split ','))
    }

    $result = Invoke-AxisWebApi @Param

    if($result.error) {
        Write-Warning $result.error.message
    }
    else {
        Get-AxisNTPClient -Device $Device
    }
}
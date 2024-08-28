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
        [String]$KEServers,
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
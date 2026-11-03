function Invoke-AxisCertApi {
    <#
    .SYNOPSIS
    Calls the VAPIX Certificate Management REST API (/config/rest/cert/v1) on an Axis device.

    .DESCRIPTION
    Thin wrapper around Invoke-AxisWebApi for the JSON certificate API available on AXIS OS 11.6 and later.
    Wraps the payload in the {"data": ...} envelope the Device Configuration framework expects, unwraps the
    response and throws on {"status":"error"}. Availability is checked through /config/discover/apis
    (Get-AxisConfigApiPath), so callers can fall back to the SOAP API on older firmware by catching the error.

    .PARAMETER Device
    The IP address or hostname of the Axis device.

    .PARAMETER Path
    The path below /config/rest/cert/v1, e.g. "/certificates" or "/certificates/MyCert/get_csr".

    .PARAMETER Method
    HTTP method. GET (default), POST, PATCH or DELETE.

    .PARAMETER Data
    The payload to place inside "data". Hashtable or scalar.
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [String]$Path="",

        [Parameter()]
        [ValidateSet("GET","POST","PATCH","DELETE")]
        [String]$Method="GET",

        [Parameter()]
        $Data
    )

    #Throws "Command not supported on this device" when the API is missing (firmware < 11.6).
    #The path carries the state suffix (v1beta before 11.11), so it is resolved, never hard-coded.
    $BasePath = Get-AxisConfigApiPath -Device $Device -API "cert"

    $Param = @{
        Device = $Device
        Path = "$BasePath$Path"
        Method = $Method
    }

    if($PSBoundParameters.ContainsKey('Data')) {
        $Param.Add('Body',@{ data = $Data })
    }
    elseif($Method -ne "GET") {
        #PATCH/DELETE without payload still need the method to stick
        $Param.Add('Body',"")
    }

    $Response = Invoke-AxisWebApi @Param

    if($Response.status -ne "success") {
        $Message = $Response.error.message
        if(!$Message) { $Message = "Unknown error" }
        Throw "Certificate API error: $Message"
    }

    return $Response.data
}

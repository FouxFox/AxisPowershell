function Get-AxisConfigApiPath {
    <#
    .SYNOPSIS
    Resolves the REST path of a Device Configuration API (e.g. cert, cert-est) on an Axis device.

    .DESCRIPTION
    Device Configuration APIs (AXIS OS 11.6+) are discovered through /config/discover/apis. The returned
    rest_api path includes the state suffix (/config/rest/cert/v1beta on 11.6-11.10, /config/rest/cert/v1
    from 11.11), so callers must not hard-code it. Results are stored in the device cache. Throws
    "Command not supported on this device" when the API (or the framework) is missing.

    .PARAMETER Device
    The IP address or hostname of the Axis device.

    .PARAMETER API
    The API ID, e.g. "cert" or "cert-est".

    .PARAMETER MajorVersion
    The major version to use. Default 1.
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter(Mandatory)]
        [String]$API,

        [Parameter()]
        [Int]$MajorVersion=1
    )

    if(!$Cache.ContainsKey($Device)) {
        $Cache.Add($Device,@{})
    }

    if(!$Cache.$Device.ContainsKey("ConfigAPIs")) {
        $Apis = @{}
        Try {
            $Response = Invoke-AxisWebApi -Device $Device -Path "/config/discover/apis"
            ForEach($Property in $Response.PSObject.Properties) {
                $Apis.Add($Property.Name, $Property.Value)
            }
        }
        Catch {
            Write-Verbose "Device does not expose /config/discover/apis: $_"
        }
        $Cache.$Device.Add("ConfigAPIs",$Apis)
    }

    $Versions = $Cache.$Device.ConfigAPIs.$API
    $Entry = $null
    if($Versions) {
        $Entry = $Versions."v$MajorVersion"
    }

    if(!$Entry -or !$Entry.rest_api) {
        Throw "Command not supported on this device"
    }

    return $Entry.rest_api
}

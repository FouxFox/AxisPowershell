<#
.SYNOPSIS
Retrieves the list of installed Axis Camera Application Platform (ACAP) applications from a specified device.

.DESCRIPTION
The Get-AxisACAP function connects to an Axis device and retrieves the list of installed ACAP applications.

.PARAMETER Device
The hostname or IP address of the Axis device from which to retrieve the ACAP information. This parameter is mandatory.

.OUTPUTS
Returns a list of installed ACAP applications on the specified device.

.EXAMPLES
Get-AxisACAP -Device "192.168.0.100"

Name              : objectanalytics
ApplicationID     : 412806
NiceName          : AXIS Object Analytics
Vendor            : Axis Communications
Version           : 1.20.36
Status            : Stopped
License           : None
ConfigurationPage : local/objectanalytics/index.html
VendorHomePage    : http://www.axis.com
LicenseName       : available

Name              : vmd
ApplicationID     : 143440
NiceName          : AXIS Video Motion Detection
Vendor            : Axis Communications
Version           : 4.5.13
Status            : Stopped
License           : None
ConfigurationPage : local/vmd/config.html
VendorHomePage    : http://www.axis.com
LicenseName       : available
#>
function Get-AxisACAP {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/applications/list.cgi"
    }
    $result = (Invoke-AxisWebApi @Param).reply

    if($result.result -ne 'ok') {
        Throw "Unable to retrieve ACAP information"
    }

    return $result.application
}
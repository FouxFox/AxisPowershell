
<#
.SYNOPSIS
Retrieves the enabled HTTPS cipher list from an Axis device.

.DESCRIPTION
Provides a convenient way to fetch and parse the HTTPS cipher configuration from an Axis device.
Cipher strength can be looked up using external resources such as https://ciphersuite.info/

.PARAMETER Device
The hostname, IPv4/IPv6 address, or resolvable identifier of the Axis device from which to query the HTTPS cipher configuration.

.PARAMETER AsString
When present, returns the raw colon-delimited cipher string exactly as provided by the device instead of an array.
This format is used when setting the ciphers via Set-AxisParameter.

.EXAMPLE
PS> Get-AxisHttpsCiphers -Device 192.168.0.90
ECDHE-ECDSA-AES128-GCM-SHA256
ECDHE-RSA-AES128-GCM-SHA256
ECDHE-ECDSA-AES256-GCM-SHA384
ECDHE-RSA-AES256-GCM-SHA384
ECDHE-ECDSA-CHACHA20-POLY1305
ECDHE-RSA-CHACHA20-POLY1305

.EXAMPLE
PS> Get-AxisHttpsCiphers -Device 192.168.0.90 -AsString
ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:(...)

.NOTES
The Cipher suite can be set using Set-AxisParameter -Parameter "HTTPS.Ciphers" -Value "<cipher string>"
#>
function Get-AxisHttpsCiphers {
    [cmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Device,

        [Parameter()]
        [switch]$AsString
    )

    $Param = @{
        Device = $Device
        Group = "HTTPS.Ciphers"
    }

    if($AsString) {
        return (Get-AxisParameter @Param).'HTTPS.Ciphers'
    }
    return (Get-AxisParameter @Param).'HTTPS.Ciphers'.Split(':')
}
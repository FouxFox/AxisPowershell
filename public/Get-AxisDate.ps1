<#
.SYNOPSIS
Retrieves date and time information from an Axis device.

.DESCRIPTION
The Get-AxisDate function retrieves the date and time information from an Axis device.

.PARAMETER Device
Specifies the Hostname or IP address of the Axis device.

.PARAMETER Quiet
Indicates whether to return only the offset in seconds from the current time.

.PARAMETER Raw
Indicates whether to return the raw result from the Axis Web API.

.EXAMPLE
Get-AxisDate -Device 192.168.1.100


Device            : 192.168.1.100
UTCTime           : 2024-08-27T19:29:56Z
LocalTime         :
TimeZone          : America/Chicago
PosixTimeZone     : CST6CDT,M3.2.0,M11.1.0
DST               : True
OffsetFromCurrent : -1

.OUTPUTS
If the Raw switch is not used, the function returns a custom object with the following properties:
- Device: The name or IP address of the Axis device.
- UTCTime: The UTC time of the Axis device.
- LocalTime: The local time of the Axis device.
- TimeZone: The time zone of the Axis device.
- PosixTimeZone: The POSIX time zone of the Axis device.
- DST: The daylight saving time status of the Axis device.
- OffsetFromCurrent: The offset from the current time in seconds.

If the Raw switch is used, the function returns the raw result from the Axis Web API.
#>
function Get-AxisDate {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [Switch]$Quiet,

        [Parameter()]
        [switch]$LegacyMethod
    )

    if(!$LegacyMethod) {
        $Version = (Get-AxisDeviceInfo -Device $Device).Version
    }
    else {
        $Version = 0
    }

    $Output = [ordered]@{
        Device = $Device
        UTCTime = 'N/A'
        LocalTime = ''
        TimeZone = 'N/A'
        PosixTimeZone = ''
        DST = ''
        OffsetFromCurrent = 'N/A'
    }

    #Compare version returns 0 for matching versions, -1 for a newer version, and 1 for an older version
    $VersionComparison = Compare-Version -Version $Version -TargetVersion '9.30'
    if($VersionComparison -eq 1) {
        Write-Warning "Cannot calculate time offset for firmware versions less than 9.30."
        $DeviceTime = [datetime](Invoke-AxisWebApi -Device 10.72.244.60 -Path "/axis-cgi/admin/date.cgi?action=get")
        $DeviceTimeSettings = Get-AxisParameter -Device $Device -Group Time

        $Output.LocalTime = $DeviceTime
        $Output.PosixTimeZone = $DeviceTimeSettings.'Time.POSIXTimeZone'
        $Output.DST = $DeviceTimeSettings.'Time.DST.Enabled'
    }
    else {
        $Param = @{
            Device = $Device
            Path = "/axis-cgi/time.cgi"
            Body = @{
                apiVersion = "1.0"
                method = "getDateTimeInfo"
            }
        }
        $result = Invoke-AxisWebApi @Param

        $utcNow = Get-CurrentTime
        $DeviceTime = [datetime]::Parse($result.data.dateTime).ToUniversalTime()
        $OffsetSeconds = [math]::Round(($DeviceTime - $utcNow).TotalSeconds)

        $Output.UTCTime = $result.data.dateTime
        $Output.LocalTime = $result.data.localTime
        $Output.TimeZone = $result.data.timeZone
        $Output.PosixTimeZone = $result.data.posixTimeZone
        $Output.DST = $result.data.dstEnabled
        $Output.OffsetFromCurrent = $OffsetSeconds
    }    

    if($Quiet) {
        return $Output.OffsetFromCurrent
    }

    return [pscustomobject]$Output
}


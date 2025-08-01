<#
.SYNOPSIS
Retrieves the Differentiated Services Code Point (DSCP) values for various network classes on an Axis device.

.DESCRIPTION
The Get-AxisDSCP function retrieves the DSCP values for different network classes on an Axis device. It uses the Get-AxisParameter cmdlet to fetch the values from the device.

.PARAMETER Device
Specifies the name or IP address of the Axis device.

.EXAMPLE
Get-AxisDSCP -Device "192.168.1.100"

Class      DSCP
-----      ----
Audio      0
Management 0
Video      0
Remote     0
Metadata   0
#>

function Get-AxisDSCP {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device
    )

    $ClassMap = @{}

    $result = Get-AxisParameter -Device $Device -Group 'Network.QoS.*'
    $descriptions = $result.Keys | Where-Object { $_.contains('Desc') }
    $settings = $result.Keys | Where-Object { $_.contains('DSCP') }

    ForEach ($class in $descriptions) {
        $ClassMap.Add($class.Replace('Desc','DSCP'),$result.$class.Replace('Axis','').Replace('Live','').Replace('Service','').Replace('MetaData','Metadata').Trim())
    }

    

    ForEach ($class in $settings) {
        [pscustomobject]@{
            Class = $ClassMap[$class]
            DSCP  = $result.$class
        }
    }
}
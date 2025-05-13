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

    $ClassMap = @{
        'Network.QoS.Class1.DSCP' = 'Video'
        'Network.QoS.Class2.DSCP' = 'Audio'
        'Network.QoS.Class3.DSCP' = 'Management'
        'Network.QoS.Class4.DSCP' = 'Remote'
        'Network.QoS.Class5.DSCP' = 'Metadata'
    }

    $result = Get-AxisParameter -Device $Device -Group 'Network.QoS.*.DSCP'

    ForEach ($class in $result.Keys) {
        [pscustomobject]@{
            Class = $ClassMap[$class]
            DSCP  = $result.$class
        }
    }
}
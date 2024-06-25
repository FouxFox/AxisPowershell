<#
.SYNOPSIS
Sets the Differentiated Services Code Point (DSCP) values for Axis network devices.

.DESCRIPTION
The Set-AxisDSCP function allows you to set the DSCP values for different QoS classes on Axis network devices. 
The function supports setting the DSCP values for all QoS classes at once or for specific QoS classes individually.

.PARAMETER Device
Specifies the Axis network device for which the DSCP values should be set.

.PARAMETER Value
Specifies the DSCP value to be set for all QoS classes. 
The default value is 26.

.PARAMETER VideoValue
Specifies the DSCP value to be set for Live Video. 
The default value is 26.

.PARAMETER AudioValue
Specifies the DSCP value to be set for Live Audio. 
The default value is 26.

.PARAMETER ManagementValue
Specifies the DSCP value to be set for Management traffic. 
The default value is 26.

.PARAMETER RemoteValue
Specifies the DSCP value to be set for traffic that uses the O3C Remote connection. 
The default value is 26.

.PARAMETER MetadataValue
Specifies the DSCP value to be set for Metadata. 
The default value is 26.

.EXAMPLE
Set-AxisDSCP -Device "192.168.0.1" -Value 46
Sets the DSCP value to 46 for all QoS classes.

.EXAMPLE
Set-AxisDSCP -Device "192.168.0.1" -VideoValue 34 -AudioValue 36
Sets the DSCP value to 34 for Live Video and 36 for Live Audio.
#>

function Set-AxisDSCP {
    [cmdletbinding(DefaultParameterSetName='All')]
    Param(
        [Parameter(Mandatory=$true,DefaultParameterSetName='All')]
        [Parameter(Mandatory=$true,DefaultParameterSetName='Specific')]
        [String]$Device,

        [Parameter(Mandatory=$false,ParameterSetName='All')]
        [Int]$Value=26,

        [Parameter(Mandatory=$false,ParameterSetName='Specific')]
        [Int]$VideoValue=26,

        [Parameter(Mandatory=$false,ParameterSetName='Specific')]
        [Int]$AudioValue=26,

        [Parameter(Mandatory=$false,ParameterSetName='Specific')]
        [Int]$ManagementValue=26,

        [Parameter(Mandatory=$false,ParameterSetName='Specific')]
        [Int]$RemoteValue=26,

        [Parameter(Mandatory=$false,ParameterSetName='Specific')]
        [Int]$MetadataValue=26
    )

    if($PSCmdlet.ParameterSetName -eq 'All') {
        $ParamSet = @{
            "Network.QoS.Class1.DSCP" = 26 #AxisLiveVideo
            "Network.QoS.Class2.DSCP" = 26 #AxisLiveAudio
            "Network.QoS.Class3.DSCP" = 26 #AxisManagement
            "Network.QoS.Class4.DSCP" = 26 #AxisRemoteService
            "Network.QoS.Class5.DSCP" = 26 #AxisMetaData
        }
    }
    else {
        $ParamSet = @{
            $ParamSet["Network.QoS.Class1.DSCP"] = $VideoValue
            $ParamSet["Network.QoS.Class2.DSCP"] = $AudioValue
            $ParamSet["Network.QoS.Class3.DSCP"] = $ManagementValue
            $ParamSet["Network.QoS.Class4.DSCP"] = $RemoteValue
            $ParamSet["Network.QoS.Class5.DSCP"] = $MetadataValue
        }
    }

    Try {
        Update-AxisParameter -Device $Device -ParameterSet $ParamSet
    }
    Catch {
        Throw "Unable to apply DSCP values"
    }
}
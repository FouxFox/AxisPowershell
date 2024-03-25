<#
.SYNOPSIS
Retrieves Axis parameters for a specified device and group.

.DESCRIPTION
The Get-AxisParameter function retrieves Axis parameters for a specified device and group.

.PARAMETER Device
Specifies the hostname or IP address of the Axis device.

.PARAMETER Group
Specifies the group(s) of parameters to retrieve. Multiple groups can be specified by providing an array of strings.

.EXAMPLE
Get-AxisParameter -Device "192.168.0.100" -Group "System", "Network"
Retrieves the parameters for the "System" and "Network" groups from the Axis device with the IP address "192.168.0.100".
#>
function Get-AxisParameter {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$true)]
        [String[]]$Group
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=list&group=$($Group -join ',')"
    }
    Try{
        $result = Invoke-AxisWebApi @Param
    } Catch {
        Throw "Unable to fetch parameter(s)"
    }

    $Parsed = @{}
    ForEach ($line in $result.split("`n")) {
        if(!$line.contains('=')) {
            continue
        }
        $Parsed.Add($line.split("=")[0].replace("root.",''),$line.split("=")[1])
    }

    $Parsed
}

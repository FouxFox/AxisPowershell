function Get-AxisACAP {
    <#
    .SYNOPSIS
    Retrieves information about Axis ACAP.

    .DESCRIPTION
    This function is used to retrieve details about Axis ACAP.

    .PARAMETER ParameterName
    Description of the parameter.

    .EXAMPLE
    Get-AxisACAP -ParameterName Value

    .NOTES
    Author: Your Name
    Date: $(Get-Date -Format "yyyy-MM-dd")
    #>

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
#In development
function Get-AxisZipStreamSupport {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/zipstream/listprofiles.cgi?schemaversion=1"
    }
    Invoke-AxisWebApi @Param
}
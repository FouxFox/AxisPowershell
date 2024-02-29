function Get-AxisSupportedResolutions {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )
    
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=listdefinitions&listformat=xmlschema&group=root.Image.*.Appearance.Resolution"
    }
    return (Invoke-AxisWebApi @Param).parameterDefinitions.group.group.group.Where({ $_.name -eq "I0"}).group.parameter.type.enum.entry.value
}
function Get-AxisSDCardStatus {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/disks/list.cgi?diskid=all"
    }

    return (Invoke-AxisWebApi @Param).root.disks.disk | Where-Object { $_.diskid -eq 'SD_DISK' }
}
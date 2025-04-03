
function Get-AxisStreamStatus {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/streamstatus.cgi"
        Body = @{
            "apiVersion" = "1.0"
            "method" = "getAllStreams"
        }
    }

    (Invoke-AxisWebApi @Param).data.streams
}
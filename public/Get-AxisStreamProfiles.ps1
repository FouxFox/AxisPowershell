function Get-AxisStreamProfiles {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/streamprofile.cgi"
        Body = @{
            "apiVersion" = "1.0"
            "method" = "list"
            "params" = @{
                "streamProfileName" = @()
            }
        }
    }

    $result = (Invoke-AxisWebApi @Param).data.streamProfile

    ForEach ($streamProfile in $result) {
        $ProfileParameters = [ordered]@{
            Name =        $streamProfile.name
            Description = $streamProfile.description
        }
        ForEach ($item in $streamProfile.parameters.Split('&')) {
            $ProfileParameters.Add($item.Split('=')[0],$item.Split('=')[1])
        }
        
        [pscustomobject]$ProfileParameters
    }
}
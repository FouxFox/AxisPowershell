function Get-AxisStorageOptions {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=list&group=Storage.S0"
    }
    $result = Invoke-AxisWebApi @Param

    $Parsed = [ordered]@{}
    ForEach ($line in $result.split("`n")) {
        $Parsed.Add($line.split("=")[0].replace("root.Storage.S0.",''),$line.split("=")[1])
    }

    $out = [pscustomobject]@{
        Disk =                $Parsed.DiskID
        Enabled =             $Parsed.Enabled             -eq 'yes'
        AutoRepair =          $Parsed.AutoRepair          -eq 'yes'
        CleanupMaxAge =       $Parsed.CleanupMaxAge
        CleanupPolicyActive = $Parsed.CleanupPolicyActive
        FileSystem =          $Parsed.FileSystem
        Locked =              $Parsed.Locked              -eq 'yes'
    }

    return $out
}
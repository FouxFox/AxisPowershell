function Get-AxisRecordingSupport {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=list&group=Properties.LocalStorage"
    }
    $result = Invoke-AxisWebApi @Param

    $Parsed = [ordered]@{}
    ForEach ($line in $result.split("`n")) {
        $Parsed.Add($line.split("=")[0].replace("root.Properties.LocalStorage.",''),$line.split("=")[1])
    }

    [pscustomobject]@{
        AutoRepair =          $Parsed.AutoRepair          -eq 'yes'
        ContinuousRecording = $Parsed.ContinuousRecording -eq 'yes'
        DiskEncryption =      $Parsed.DiskEncryption      -eq 'yes'
        DiskHealth =          $Parsed.DiskHealth          -eq 'yes'
        ExportRecording =     $Parsed.ExportRecording     -eq 'yes'
        FailOverRecording =   $Parsed.FailOverRecording   -eq 'yes'
        LocalStorage =        $Parsed.LocalStorage        -eq 'yes'
        RequiredFileSystem =  $Parsed.RequiredFileSystem  -eq 'yes'
        SDCard =              $Parsed.SDCard              -eq 'yes'
        StorageLimit =        $Parsed.StorageLimit        -eq 'yes'
        NbrOfContinuousRecordingProfiles = $Parsed.NbrOfContinuousRecordingProfiles
    }
}
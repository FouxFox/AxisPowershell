<#
.SYNOPSIS
Retrieves the recording support information for an Axis device.

.DESCRIPTION
The Get-AxisRecordingSupport function retrieves the supported recording features for an Axis device.

.PARAMETER Device
Specifies the hostname or IP address of the Axis device.

.EXAMPLE
Get-AxisRecordingSupport -Device "192.168.1.100"

AutoRepair                       : True
ContinuousRecording              : True
DiskEncryption                   : True
DiskHealth                       : True
ExportRecording                  : True
FailOverRecording                : True
LocalStorage                     : True
RequiredFileSystem               : True
SDCard                           : True
StorageLimit                     : True
NbrOfContinuousRecordingProfiles : 1
#>

function Get-AxisRecordingSupport {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=list&group=Properties.LocalStorage,ImageSource.NbrOfSources"
    }
    $result = Invoke-AxisWebApi @Param

    $Parsed = [ordered]@{}
    ForEach ($line in $result.split("`n")) {
        $Parsed.Add($line.split("=")[0].replace("root.",'').replace("Properties.LocalStorage.",'').replace("ImageSource.",''),$line.split("=")[1])
    }

    [pscustomobject]@{
        AutoRepair =                        $Parsed.AutoRepair          -eq 'yes'
        ContinuousRecording =               $Parsed.ContinuousRecording -eq 'yes'
        DiskEncryption =                    $Parsed.DiskEncryption      -eq 'yes'
        DiskHealth =                        $Parsed.DiskHealth          -eq 'yes'
        ExportRecording =                   $Parsed.ExportRecording     -eq 'yes'
        FailOverRecording =                 $Parsed.FailOverRecording   -eq 'yes'
        LocalStorage =                      $Parsed.LocalStorage        -eq 'yes'
        RequiredFileSystem =                $Parsed.RequiredFileSystem  -eq 'yes'
        SDCard =                            $Parsed.SDCard              -eq 'yes'
        StorageLimit =                      $Parsed.StorageLimit        -eq 'yes'
        NbrOfContinuousRecordingProfiles =  $Parsed.NbrOfContinuousRecordingProfiles
        NumberofLenses =                    $Parsed.NbrOfSources 
    }
}
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
NumberofLenses                   : 2
H265Support                      : True
#>

function Get-AxisRecordingSupport {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device
    )

    $Groups = @(
        'Properties.LocalStorage'
        'ImageSource.NbrOfSources'
        'Properties.Image.Format'
    )
    $result = Get-AxisParameter -Device $Device -Group $Groups

    [pscustomobject]@{
        AutoRepair =                        $result.'Properties.LocalStorage.AutoRepair'          -eq 'yes'
        ContinuousRecording =               $result.'Properties.LocalStorage.ContinuousRecording' -eq 'yes'
        DiskEncryption =                    $result.'Properties.LocalStorage.DiskEncryption'      -eq 'yes'
        DiskHealth =                        $result.'Properties.LocalStorage.DiskHealth'          -eq 'yes'
        ExportRecording =                   $result.'Properties.LocalStorage.ExportRecording'     -eq 'yes'
        FailOverRecording =                 $result.'Properties.LocalStorage.FailOverRecording'   -eq 'yes'
        LocalStorage =                      $result.'Properties.LocalStorage.LocalStorage'        -eq 'yes'
        RequiredFileSystem =                $result.'Properties.LocalStorage.RequiredFileSystem'  -eq 'yes'
        SDCard =                            $result.'Properties.LocalStorage.SDCard'              -eq 'yes'
        StorageLimit =                      $result.'Properties.LocalStorage.StorageLimit'        -eq 'yes'
        NbrOfContinuousRecordingProfiles =  $result.'Properties.LocalStorage.NbrOfContinuousRecordingProfiles'
        NumberofLenses =                    $result.'ImageSource.NbrOfSources' 
        SupportedCodecs =                   $result.'Properties.Image.Format'
    }
}
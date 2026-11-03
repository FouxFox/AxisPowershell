<#
.SYNOPSIS
Sets the configuration for the AxisPowerShell module.

.DESCRIPTION
The Set-AxisPSConfig function is used to change the behavior when values are not provided.

.PARAMETER FirmwareFolder
Specifies the path to the firmware folder.

.PARAMETER EnableCertificateProvisioning
Adds the certificate deployment stage to New-AxisProvisioningJob, using the default certificate authority
(see New-AxisCertificateAuthority and Set-AxisPSCertificateTemplate).

.PARAMETER DisableCertificateProvisioning
Removes the certificate deployment stage from the provisioning job.

.EXAMPLE
Set-AxisPSConfig -FirmwareFolder "C:\Firmware"

This example sets the firmware folder path to "C:\Firmware".

#>
function Set-AxisPSConfig {
    [cmdletbinding(DefaultParameterSetName='LoggingOn')]
    Param(
        [Parameter(ParameterSetName='LoggingOn')]
        [Parameter(ParameterSetName='LoggingOff')]
        [String]$FirmwareFolder,

        [Parameter(ParameterSetName='LoggingOn')]
        [Parameter(ParameterSetName='LoggingOff')]
        [String]$LogPath,

        [Parameter(ParameterSetName='LoggingOn')]
        [Parameter(ParameterSetName='LoggingOff')]
        [String]$ProvisioningSnapshotPath,

        [Parameter(ParameterSetName='LoggingOn')]
        [Parameter(ParameterSetName='LoggingOff')]
        [String]$DNSSuffix,

        [Parameter(ParameterSetName='LoggingOn')]
        [Switch]$EnableLogging,

        [Parameter(ParameterSetName='LoggingOff')]
        [Switch]$DisableLogging,

        [Parameter(ParameterSetName='LoggingOn')]
        [Parameter(ParameterSetName='LoggingOff')]
        [Switch]$EnableCertificateProvisioning,

        [Parameter(ParameterSetName='LoggingOn')]
        [Parameter(ParameterSetName='LoggingOff')]
        [Switch]$DisableCertificateProvisioning
    )
    
    if($FirmwareFolder) {
        $Config.FirmwareFolder = $FirmwareFolder
    }
    if($LogPath) {
        $Config.LogPath = $LogPath
    }
    if ($ProvisioningSnapshotPath) {
        $Config.ProvisioningSnapshotPath = $ProvisioningSnapshotPath
    }
    if ($DNSSuffix) {
        $Config.DNSSuffix = $DNSSuffix
    }
    if($EnableLogging) {
        $Config.LogEnabled = $true
    }
    if ($DisableLogging) {
        $Config.LogEnabled = $false
    }
    if($EnableCertificateProvisioning) {
        if(!$Config.Certificate.DefaultAuthority) {
            Throw "No default certificate authority is configured. Run New-AxisCertificateAuthority first."
        }
        $Config.ProvisionCertificate = $true
    }
    if($DisableCertificateProvisioning) {
        $Config.ProvisionCertificate = $false
    }

    Write-ModuleConfiguration
}
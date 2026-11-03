<#
.SYNOPSIS
Removes a certificate authority from the AxisPowershell configuration.

.DESCRIPTION
Deletes the authority definition and its stored credentials. Certificates already issued are not affected.
If the removed authority was the default, the default is cleared.

.PARAMETER Name
The authority to remove.

.EXAMPLE
Remove-AxisPSCertificateAuthority -Name LabCA
#>
function Remove-AxisPSCertificateAuthority {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Name
    )

    if(!$Config.CertificateAuthorities.ContainsKey($Name)) {
        Throw "Certificate authority '$Name' is not configured."
    }

    $Authority = $Config.CertificateAuthorities.$Name
    ForEach($Target in @($Authority.CredentialTarget, $Authority.RevokeCredentialTarget)) {
        if($Target) {
            Try {
                $null = Remove-StoredCredential -Target $Target
            }
            Catch {
                Write-Verbose "No stored credential '$Target' to remove."
            }
        }
    }

    $Config.CertificateAuthorities.Remove($Name)
    if($Config.Certificate.DefaultAuthority -eq $Name) {
        $Config.Certificate.DefaultAuthority = $false
    }

    Write-ModuleConfiguration
}

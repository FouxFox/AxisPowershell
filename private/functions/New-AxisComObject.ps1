function New-AxisComObject {
    <#
    .SYNOPSIS
    Creates a COM object by ProgId (Windows only).

    .DESCRIPTION
    Tiny wrapper around New-Object -ComObject so the AD CS backends (CertificateAuthority.Request /
    CertificateAuthority.Admin) can be mocked in Pester on non-Windows hosts. COM is only available on
    Windows PowerShell (Desktop) and PowerShell 7 running on Windows; elsewhere a clear error is thrown.

    .PARAMETER ProgId
    The COM ProgId, e.g. "CertificateAuthority.Request".
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$ProgId
    )

    #$IsWindows does not exist on PS 5.1 (Desktop edition), which is always Windows.
    if(!($PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows)) {
        Throw "COM object $ProgId requires Windows. The WindowsCA backend (AD CS) can only be used from a Windows host with the CA client components (certcli.dll/certadm.dll, part of Windows/RSAT)."
    }

    Try {
        return New-Object -ComObject $ProgId
    }
    Catch {
        Throw "Failed to create COM object $ProgId. Is the Certificate Services client (RSAT-ADCS / certcli.dll) installed? $_"
    }
}

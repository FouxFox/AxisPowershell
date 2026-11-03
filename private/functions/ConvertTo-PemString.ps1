function ConvertTo-PemString {
    <#
    .SYNOPSIS
    Encodes DER bytes (or an X509Certificate2) as a PEM string.

    .DESCRIPTION
    PowerShell 5.1 / .NET Framework has no built-in PEM writer (ExportCertificatePem is .NET 7+), so this
    helper wraps base64 with 64-character lines and the BEGIN/END markers. Works on both PowerShell editions.

    .PARAMETER Bytes
    The DER encoded bytes.

    .PARAMETER Certificate
    An X509Certificate2 object. Its RawData is encoded.

    .PARAMETER Label
    The PEM label, e.g. CERTIFICATE (default), CERTIFICATE REQUEST, PKCS7.
    #>
    [cmdletbinding(DefaultParameterSetName='Bytes')]
    Param(
        [Parameter(Mandatory,ParameterSetName='Bytes')]
        [Byte[]]$Bytes,

        [Parameter(Mandatory,ParameterSetName='Certificate',ValueFromPipeline)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter()]
        [String]$Label="CERTIFICATE"
    )

    if($Certificate) {
        $Bytes = $Certificate.RawData
    }

    $Base64 = [Convert]::ToBase64String($Bytes)
    $Lines = @()
    for($i = 0; $i -lt $Base64.Length; $i += 64) {
        $Lines += $Base64.Substring($i, [Math]::Min(64, $Base64.Length - $i))
    }

    return "-----BEGIN $Label-----`n$($Lines -join "`n")`n-----END $Label-----"
}

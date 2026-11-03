function ConvertFrom-PemString {
    <#
    .SYNOPSIS
    Splits a PEM string into its blocks and returns the DER bytes of each.

    .DESCRIPTION
    Returns one object per PEM block ({Label, Bytes, Pem}). A concatenated bundle (leaf + intermediates + root)
    yields several objects, which matters for Axis devices: they do not accept chain files, so each CA
    certificate has to be installed separately. Use -AsCertificate to get X509Certificate2 objects for
    CERTIFICATE blocks. Works on both PowerShell editions (no .NET 5+ PEM APIs are used).

    .PARAMETER Pem
    The PEM text. May contain several blocks.

    .PARAMETER AsCertificate
    Return X509Certificate2 objects instead of raw blocks. Non-certificate blocks are skipped.
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [String]$Pem,

        [Parameter()]
        [Switch]$AsCertificate
    )

    $Pattern = '-----BEGIN ([A-Z0-9 ]+)-----(.*?)-----END \1-----'
    $Blocks = [regex]::Matches($Pem, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

    if($Blocks.Count -eq 0) {
        Throw "No PEM blocks found in input."
    }

    ForEach($Block in $Blocks) {
        $Label = $Block.Groups[1].Value
        $Body = $Block.Groups[2].Value -replace '\s',''
        $Bytes = [Convert]::FromBase64String($Body)

        if($AsCertificate) {
            if($Label -ne "CERTIFICATE") { continue }
            New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,$Bytes)
        }
        else {
            [pscustomobject]@{
                Label = $Label
                Bytes = $Bytes
                Pem = $Block.Value
            }
        }
    }
}

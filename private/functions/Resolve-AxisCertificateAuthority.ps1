function Resolve-AxisCertificateAuthority {
    <#
    .SYNOPSIS
    Returns the authority hashtable for a configured certificate authority name (or the default).

    .DESCRIPTION
    Looks the name up in $Config.CertificateAuthorities, falls back to $Config.Certificate.DefaultAuthority when
    no name is given, and returns a clone with the Name key filled in so backends can log and look up credentials.
    #>
    [cmdletbinding()]
    Param(
        [Parameter()]
        [String]$Name
    )

    if(!$Name) {
        $Name = $Config.Certificate.DefaultAuthority
    }

    if(!$Name) {
        Throw "No certificate authority specified and no default is set. Use New-AxisCertificateAuthority -Default or Set-AxisPSCertificateTemplate -DefaultAuthority."
    }

    if(!$Config.CertificateAuthorities.ContainsKey($Name)) {
        Throw "Certificate authority '$Name' is not configured. Use New-AxisCertificateAuthority to add it."
    }

    $Authority = @{}
    ForEach($Key in $Config.CertificateAuthorities.$Name.Keys) {
        $Authority[$Key] = $Config.CertificateAuthorities.$Name.$Key
    }
    $Authority["Name"] = $Name

    return $Authority
}

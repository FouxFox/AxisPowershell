function Get-AxisCertificateKeyType {
    <#
    .SYNOPSIS
    Picks the key type and keystore to use when generating a certificate key on an Axis device.

    .DESCRIPTION
    Reads the keystores the device offers (GET /config/rest/cert/v1/keystores, AXIS OS 11.6+) and selects
    the most secure keystore first (security_level STRONG e.g. TPM0/SE0 > TRUSTED_ENVIRONMENT e.g. TEE >
    SOFTWARE e.g. SOFTWARE0) and then the strongest key type that keystore supports:
    NIST-P384 > NIST-P256 > RSA-4096 > RSA-3072 > RSA-2048.
    The device documentation uses both the "NIST-P256" (examples) and "EC-P256" (data type enum) spelling;
    both are accepted and the spelling advertised by the keystore is what is sent back to the device.
    Explicit -KeyType / -Keystore values are honoured (validated against the keystore list when possible).
    On firmware without the JSON API (SOAP only, < 11.6) the device chooses the key itself; RSA-2048 with no
    keystore is returned so callers can still report what will be created.
    Source: https://developer.axis.com/vapix/device-configuration/certificate-management/ (keystores, key_types)

    .PARAMETER Device
    The IP address or hostname of the Axis device.

    .PARAMETER KeyType
    Auto (default) or an explicit key type (NIST-P256, EC-P384, RSA-2048, ...).

    .PARAMETER Keystore
    Auto (default) or an explicit keystore id (TPM0, SE0, TEE, SOFTWARE0, ...).

    .PARAMETER AllowedKeyTypes
    Optional whitelist. Useful when the CA template only accepts e.g. RSA keys: -AllowedKeyTypes RSA-4096,RSA-2048
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [String]$KeyType="Auto",

        [Parameter()]
        [String]$Keystore="Auto",

        [Parameter()]
        [String[]]$AllowedKeyTypes
    )

    #Canonical spelling used for comparison (device may say EC-P256 or NIST-P256)
    $Normalize = {
        Param($Name)
        return ([String]$Name).ToUpper().Replace("EC-P","NIST-P").Replace("ECC-P","NIST-P")
    }

    $KeyPreference = @("NIST-P384","NIST-P256","RSA-4096","RSA-3072","RSA-2048")
    $LevelRank = @{ STRONG = 0; TRUSTED_ENVIRONMENT = 1; SOFTWARE = 2 }

    if($AllowedKeyTypes) {
        $Allowed = @($AllowedKeyTypes | ForEach-Object { & $Normalize $_ })
    }
    else {
        $Allowed = $KeyPreference
    }

    #Fetch keystores; SOAP-only firmware cannot choose keys at all
    $Keystores = $null
    Try {
        $Keystores = @(Invoke-AxisCertApi -Device $Device -Path "/keystores")
    }
    Catch {
        if($_.Exception.Message -like "*Command not supported*") {
            Write-Verbose "Device has no certificate REST API; key type is chosen by the device (SOAP CreateCertificate2)."
            $Result = "RSA-2048"
            if($KeyType -ne "Auto") { $Result = $KeyType }
            return [pscustomobject]@{
                KeyType = $Result
                Keystore = $null
                SecurityLevel = $null
                Source = "SOAP"
            }
        }
        Throw "Unable to read keystores from $($Device): $_"
    }

    #Order keystores by security level, then by id so the result is stable
    $Ordered = @($Keystores | Sort-Object -Property @{Expression={ $Rank = $LevelRank[[String]$_.security_level]; if($null -eq $Rank) { 9 } else { $Rank } }}, @{Expression={ $_.id }})

    if($Keystore -ne "Auto") {
        $Candidates = @($Ordered | Where-Object { $_.id -eq $Keystore })
        if($Candidates.Count -eq 0) {
            if($KeyType -eq "Auto") {
                Throw "Keystore '$Keystore' was not reported by $Device. Available: $(($Keystores | ForEach-Object { $_.id }) -join ', ')"
            }
            #Both explicit: trust the caller
            Write-Warning "Keystore '$Keystore' was not reported by $Device; using the explicit values without validation."
            return [pscustomobject]@{ KeyType = $KeyType; Keystore = $Keystore; SecurityLevel = $null; Source = "REST" }
        }
    }
    else {
        $Candidates = $Ordered
    }

    ForEach($Store in $Candidates) {
        $Supported = @($Store.key_types)
        if($KeyType -ne "Auto") {
            $Match = $Supported | Where-Object { (& $Normalize $_) -eq (& $Normalize $KeyType) } | Select-Object -First 1
            if($Match) {
                return [pscustomobject]@{ KeyType = [String]$Match; Keystore = [String]$Store.id; SecurityLevel = [String]$Store.security_level; Source = "REST" }
            }
            if($Supported.Count -eq 0) {
                #Keystore does not advertise key types; send what was asked for
                return [pscustomobject]@{ KeyType = $KeyType; Keystore = [String]$Store.id; SecurityLevel = [String]$Store.security_level; Source = "REST" }
            }
            continue
        }

        ForEach($Preferred in $KeyPreference) {
            if($Allowed -notcontains $Preferred) { continue }
            $Match = $Supported | Where-Object { (& $Normalize $_) -eq $Preferred } | Select-Object -First 1
            if($Match) {
                Write-Verbose "Selected key type $Match in keystore $($Store.id) ($($Store.security_level))"
                return [pscustomobject]@{ KeyType = [String]$Match; Keystore = [String]$Store.id; SecurityLevel = [String]$Store.security_level; Source = "REST" }
            }
        }
    }

    if($KeyType -ne "Auto") {
        Throw "Key type '$KeyType' is not supported by the selected keystore(s) on $Device"
    }
    Throw "No keystore on $Device supports any of the allowed key types ($($Allowed -join ', '))"
}

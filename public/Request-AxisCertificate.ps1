<#
.SYNOPSIS
Requests, installs and (on renewal) replaces a CA-issued HTTPS certificate on an Axis device.

.DESCRIPTION
End-to-end certificate lifecycle for one device, with the private key generated and kept on the camera:
 1. Looks for an existing AxisPowershell-managed certificate on the device. If it was issued by a CA and is not
    within the renewal window, nothing is done (Action = Current) unless -Force is given.
 2. Builds subject and SAN from the certificate template (Get-AxisCertificateSubject).
 3. Creates a key and CSR on the camera (New-AxisCertificateRequest) using the strongest supported key type.
 4. Submits the CSR to the certificate authority (WindowsCA, Dogtag, EST or Command).
 5. Installs the certificate and the CA chain, binds it to the web server and optionally enforces HTTPS-only.
 6. On renewal: once the new certificate is verified on port 443, the old certificate is removed from the device
    and revoked on the CA with reason Superseded (failures to revoke are warnings; the new certificate is live).
Renewals use a new alias (<Alias>-<timestamp>) so the camera never loses its web server certificate mid-way.
Firmware 11.6+ uses the JSON certificate API (with SAN); older firmware falls back to SOAP without SAN.

.PARAMETER Device
The IP address or hostname of the Axis device.

.PARAMETER CertificateAuthority
Name of a configured authority (New-AxisCertificateAuthority). Defaults to the template's DefaultAuthority.

.PARAMETER Alias
Base alias for the certificate on the camera. Defaults to the template's Alias (AxisPowershell).

.PARAMETER RenewWithinDays
Renew when the current certificate expires within this many days. Defaults to the template value.

.PARAMETER Force
Request a new certificate even if the current one is valid.

.PARAMETER NoHttpsOnly
Do not switch the device to HTTPS-only even if the template says so.

.PARAMETER NoRevoke
Keep the superseded certificate valid on the CA.

.EXAMPLE
Request-AxisCertificate -Device 192.168.1.100

.EXAMPLE
Request-AxisCertificate -Device cam-lobby.example.com -CertificateAuthority CorpCA -Force
#>
function Request-AxisCertificate {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [String]$CertificateAuthority,

        [Parameter()]
        [String]$Alias,

        [Parameter()]
        [Int]$RenewWithinDays,

        [Parameter()]
        [Switch]$Force,

        [Parameter()]
        [Switch]$NoHttpsOnly,

        [Parameter()]
        [Switch]$NoRevoke
    )

    Check-Credential
    $Authority = Resolve-AxisCertificateAuthority -Name $CertificateAuthority

    if(!$Alias) { $Alias = $Config.Certificate.Alias }
    if(!$RenewWithinDays) { $RenewWithinDays = $Config.Certificate.RenewWithinDays }
    $HttpsOnly = $Config.Certificate.HttpsOnly -and !$NoHttpsOnly

    $Result = [pscustomobject]@{
        Device = $Device
        Action = "Failed"
        Alias = $Alias
        Subject = $null
        Serial = $null
        NotAfter = $null
        Thumbprint = $null
        HttpsVerified = $false
        RevokedSerial = $null
        Authority = $Authority.Name
        Message = ""
    }

    ##########################################
    ## Step 1: Inspect existing certificate ##
    ##########################################
    Write-Verbose "$($Device): Checking existing certificates"
    $Existing = $null
    Try {
        $Managed = Get-AxisCertificate -Device $Device | Where-Object { $_.Alias -eq $Alias -or $_.Alias -like "$Alias-*" }
        #The newest CA-issued one is the one we manage; self-signed placeholders (Issuer = Subject) do not count
        $Existing = $Managed | Where-Object { $_.Issuer -ne $_.Subject } | Sort-Object NotAfter -Descending | Select-Object -First 1
    }
    Catch {
        Throw "$($Device): Unable to list certificates: $($_.Exception.Message)"
    }

    if($Existing) {
        $Result.Alias = $Existing.Alias
        $Result.Subject = $Existing.Subject
        $Result.Serial = $Existing.Serial
        $Result.NotAfter = $Existing.NotAfter
        $Result.Thumbprint = $Existing.Thumbprint
        $DaysLeft = [Math]::Floor(($Existing.NotAfter - (Get-Date)).TotalDays)
        if(!$Force -and $DaysLeft -gt $RenewWithinDays) {
            $Result.Action = "Current"
            $Result.Message = "Certificate valid for $DaysLeft more days"
            Write-Verbose "$($Device): $($Result.Message)"
            return $Result
        }
        $Action = "Renewed"
        #New alias so the web server keeps its certificate until the new one is bound
        $NewAlias = "$Alias-$(Get-Date -Format 'yyyyMMddHHmm')"
    }
    else {
        $Action = "Issued"
        $NewAlias = $Alias
    }

    ###############################
    ## Step 2: Subject and SAN   ##
    ###############################
    Write-Verbose "$($Device): Resolving subject from template"
    Try {
        $Names = Get-AxisCertificateSubject -Device $Device
    }
    Catch {
        Throw "$($Device): Unable to build certificate subject: $($_.Exception.Message)"
    }
    $Result.Subject = $Names.Subject

    ###############################
    ## Step 3: Key and CSR       ##
    ###############################
    Write-Verbose "$($Device): Creating key and CSR ($NewAlias)"
    $Param = @{
        Device = $Device
        Alias = $NewAlias
        Subject = $Names.Subject
        SubjectAltNames = $Names.SubjectAltNames
        KeyType = $Config.Certificate.KeyType
        Keystore = $Config.Certificate.Keystore
        Force = $true
    }
    if($Authority.KeyTypes) {
        #The CA template may only accept some algorithms (e.g. RSA-only AD CS templates)
        $Param.Add('AllowedKeyTypes',$Authority.KeyTypes)
    }
    Try {
        $Request = New-AxisCertificateRequest @Param
    }
    Catch {
        Throw "$($Device): Unable to create certificate request: $($_.Exception.Message)"
    }

    ###############################
    ## Step 4: Submit to CA      ##
    ###############################
    Write-Verbose "$($Device): Submitting CSR to $($Authority.Name) ($($Authority.Type))"
    Try {
        $Issued = Submit-AxisCertificateRequest -Authority $Authority -Csr $Request.Csr -Device $Device -TimeoutSec $Authority.TimeoutSec
    }
    Catch {
        #Leave the camera clean: the placeholder key is useless without a certificate
        if($Action -eq "Issued") {
            Try { Remove-AxisCertificate -Device $Device -Alias $NewAlias -Force } Catch {}
        }
        Throw "$($Device): Certificate authority rejected the request: $($_.Exception.Message)"
    }
    if($Issued.Status -ne "Issued") {
        Throw "$($Device): Certificate request $($Issued.RequestId) is $($Issued.Status) on $($Authority.Name)"
    }

    ###############################
    ## Step 5: Install and bind  ##
    ###############################
    Write-Verbose "$($Device): Installing certificate"
    $Param = @{
        Device = $Device
        Alias = $NewAlias
        Certificate = $Issued.Certificate
        CACertificates = $Issued.Chain
        AssignToHttps = $true
        HttpsOnly = $HttpsOnly
    }
    Try {
        $Installed = Install-AxisCertificate @Param
    }
    Catch {
        Throw "$($Device): Unable to install certificate: $($_.Exception.Message)"
    }

    $Result.Action = $Action
    $Result.Alias = $NewAlias
    $Result.Serial = $Issued.Serial
    $Result.NotAfter = $Installed.NotAfter
    $Result.Thumbprint = $Installed.Thumbprint
    $Result.HttpsVerified = $Installed.HttpsVerified
    $Result.Message = "$Action $($Request.KeyType) certificate"

    if(!$Installed.HttpsVerified) {
        $Result.Message += "; HTTPS binding could not be verified, old certificate kept"
        Write-Warning "$($Device): $($Result.Message)"
        return $Result
    }

    ###############################
    ## Step 6: Retire the old    ##
    ###############################
    if($Existing) {
        Write-Verbose "$($Device): Removing superseded certificate $($Existing.Alias)"
        Try {
            Remove-AxisCertificate -Device $Device -Alias $Existing.Alias -Force
        }
        Catch {
            Write-Warning "$($Device): Could not remove old certificate $($Existing.Alias): $($_.Exception.Message)"
        }

        $SameIssuer = $Existing.Issuer -eq (ConvertFrom-PemString -Pem $Issued.Certificate -AsCertificate | Select-Object -First 1).Issuer
        if(!$NoRevoke -and $SameIssuer -and $Existing.Serial) {
            Try {
                $null = Revoke-AxisIssuedCertificate -Authority $Authority -Serial $Existing.Serial -Reason Superseded
                $Result.RevokedSerial = $Existing.Serial
                $Result.Message += "; revoked $($Existing.Serial) (Superseded)"
            }
            Catch {
                $Result.Message += "; revocation of $($Existing.Serial) failed: $($_.Exception.Message)"
                Write-Warning "$($Device): $($Result.Message)"
            }
        }
    }

    Write-Verbose "$($Device): $($Result.Message)"
    return $Result
}

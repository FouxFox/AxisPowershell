<#
.SYNOPSIS
Hands certificate enrollment and renewal over to the Axis device itself (EST profile, AXIS OS 12.9/12.10+).

.DESCRIPTION
The Set-AxisCertificateEnrollment function creates (or updates) an EST profile on an Axis device through the
VAPIX Enrollment over secure transport API (POST/PATCH /config/rest/cert-est/v1/profiles). From then on the device
acts as the EST client (RFC 7030) and the module is no longer involved:
    - the device sends a CSR to <server>/simpleenroll as soon as server, certificate and caCertificates are set,
    - it re-enrolls (/simplereenroll) at 50 % of the certificate validity and retries daily on failure,
    - the enrolled certificate is assigned to the selected services (WEBSERVER by default),
    - failures are published as the stateless event tnsaxis:CertificateManagement/EST/Error (ErrorCode 0-7,
      readable via ws(s)://<device>/vapix/ws-data-stream?sources=events).
The profile status (UNCONNECTED / CONNECTED / ENROLLED) can be read with Get-AxisCertificateEnrollment.

Bootstrap trust: CA certificates returned by the EST /cacerts operation are added to the device trust store
automatically, without out-of-band verification. Whichever server the device reaches first becomes trusted.
This function therefore pre-loads the EST server root CA (-CACertificate) into the device trust store
(POST /config/rest/cert/v1/ca_certificates, skipped when the same thumbprint is already present) and references
its alias in the profile's caCertificates list, so the device authenticates the server before trusting anything.
A profile without a CA certificate alias is refused for that reason.

The device authenticates itself to the EST server with mutual TLS using an existing device certificate
(-ClientCertificateAlias). By default the Axis device ID (IEEE 802.1AR) certificate is used when it can be
found with Get-AxisCertificate; Dogtag/EJBCA/ClearPass EST servers trust the Axis device ID chain for this.
The authority must be of Type Dogtag or EST (New-AxisCertificateAuthority). The EST URL sent to the device is
built as "host:port/.well-known/est[/label]" from Authority.Server (Dogtag: EstServer when set) and
Authority.Label (fallback Authority.Template). Credentials stored for the authority are NOT used: the device
only supports certificate (mTLS) authentication, so the EST server must accept the client certificate.
A device holds at most two EST profiles (AXIS OS 12.11+; one before).
Sources: https://developer.axis.com/vapix/device-configuration/enrollment-over-secure-transport-api/
         https://help.axis.com/en-us/axis-os-knowledge-base ; https://newsroom.axis.com/en-us/news/support-est
         https://www.rfc-editor.org/rfc/rfc7030

.PARAMETER Device
Specifies the IP address or hostname of the Axis device.

.PARAMETER CertificateAuthority
Name of a configured certificate authority of Type Dogtag or EST. Default $Config.Certificate.DefaultAuthority.

.PARAMETER ProfileId
EST profile identifier on the device (1-128 characters). Default "AxisPowershell". An existing profile with this id is patched.

.PARAMETER ClientCertificateAlias
Alias of an existing device certificate used to authenticate to the EST server (mutual TLS).
Default: the Axis device ID certificate, if one is found on the device; otherwise the parameter is required.

.PARAMETER CACertificate
The EST server's root (or issuing) CA certificate as PEM text or a PEM file path. Installed on the device when
not already present. Alternatively the alias of a CA certificate that is already installed on the device.
When omitted, a CA certificate already on the device matching Authority.CAThumbprint is used.

.PARAMETER Services
Services the enrolled certificate is assigned to: WEBSERVER, NETAUTH, MQTT, RTSPS. Default WEBSERVER.

.PARAMETER SubjectTemplate
Subject DN template passed to Get-AxisCertificateSubject (only the CN is sent to the device). Default from configuration.

.PARAMETER SanTemplate
SAN templates passed to Get-AxisCertificateSubject. Default from configuration.

.PARAMETER HttpsOnly
Force HTTPS for all user roles (System.BoaGroupPolicy.*=https). Default $Config.Certificate.HttpsOnly.
Note: the setting is applied immediately, before the device has enrolled; the web server keeps serving its current certificate until then.

.EXAMPLE
Set-AxisCertificateEnrollment -Device "192.168.1.100" -CertificateAuthority Dogtag -CACertificate C:\pki\dogtag-root.pem

Device    : 192.168.1.100
ProfileId : AxisPowershell
Server    : pki.example.com:8443/.well-known/est/cameras
Status    : UNCONNECTED

.EXAMPLE
Set-AxisCertificateEnrollment -Device "192.168.1.100" -ClientCertificateAlias "AxisPowershell" -CACertificate "EST-Root" -Services WEBSERVER,RTSPS -HttpsOnly:$false
Uses a previously issued module certificate for mTLS and the CA certificate already installed under alias "EST-Root".
#>
function Set-AxisCertificateEnrollment {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [String]$CertificateAuthority,

        [Parameter()]
        [ValidateLength(1,128)]
        [String]$ProfileId="AxisPowershell",

        [Parameter()]
        [String]$ClientCertificateAlias,

        [Parameter()]
        [String]$CACertificate,

        [Parameter()]
        [ValidateSet("WEBSERVER","NETAUTH","MQTT","RTSPS")]
        [String[]]$Services=@("WEBSERVER"),

        [Parameter()]
        [String]$SubjectTemplate,

        [Parameter()]
        [String[]]$SanTemplate,

        [Parameter()]
        [Switch]$HttpsOnly
    )

    if(!$PSBoundParameters.ContainsKey('HttpsOnly')) {
        $HttpsOnly = [bool]$Config.Certificate.HttpsOnly
    }

    #Authority: only EST-capable types can be handed off to the device
    $Authority = Resolve-AxisCertificateAuthority -Name $CertificateAuthority
    if($Authority.Type -notin @("Dogtag","EST")) {
        Throw "Certificate authority '$($Authority.Name)' is of type '$($Authority.Type)'; native device enrollment requires an EST capable authority (Type Dogtag or EST)"
    }
    $Server = $Authority.Server
    if($Authority.Type -eq "Dogtag" -and $Authority.EstServer) {
        $Server = $Authority.EstServer
    }
    if(!$Server) {
        Throw "Certificate authority '$($Authority.Name)' has no Server (expected 'https://host:port')"
    }

    #Device expects "host[:port][/.well-known/est[/label]]" without scheme (API doc: "192.168.0.1:443/.well-known/est")
    $HostPort = ([String]$Server).Trim()
    $HostPort = $HostPort -replace '^[A-Za-z][A-Za-z0-9+.-]*://',''
    $HostPort = $HostPort.Split('/')[0]
    if(!$HostPort) {
        Throw "Unable to determine host and port from authority server '$Server'"
    }
    $EstServer = "$HostPort/.well-known/est"
    $Label = $Authority.Label
    if(!$Label) { $Label = $Authority.Template }
    if($Label) {
        $EstServer = "$EstServer/$(([String]$Label).Trim('/'))"
    }

    #API availability (AXIS OS 12.9/12.10+); throws "Command not supported on this device" otherwise
    $BasePath = Get-AxisConfigApiPath -Device $Device -API "cert-est"

    #Existing device certificates: default mTLS client certificate = Axis device ID (IEEE 802.1AR)
    $DeviceCerts = @()
    Try {
        $DeviceCerts = @(Get-AxisCertificate -Device $Device)
    }
    Catch {
        Write-Verbose "Could not list device certificates on $($Device): $_"
    }
    if(!$ClientCertificateAlias) {
        #Alias/subject/issuer naming of the factory certificate is not documented; match on "Axis device ID", prefer ECC
        $DeviceIds = @($DeviceCerts | Where-Object {
            $_.Alias -like "*Axis*device*ID*" -or $_.Subject -like "*Axis*Device*ID*" -or $_.Issuer -like "*Axis*Device*ID*"
        })
        $Candidate = $DeviceIds | Where-Object { $_.KeyType -like "NIST-*" } | Select-Object -First 1
        if(!$Candidate) { $Candidate = $DeviceIds | Select-Object -First 1 }
        if(!$Candidate) {
            Throw "No Axis device ID certificate found on $Device; specify -ClientCertificateAlias with the alias of an existing device certificate to authenticate to the EST server"
        }
        $ClientCertificateAlias = $Candidate.Alias
        Write-Verbose "Using '$ClientCertificateAlias' as EST client certificate"
    }
    elseif($DeviceCerts.Count -gt 0 -and ($DeviceCerts | ForEach-Object { $_.Alias }) -notcontains $ClientCertificateAlias) {
        Throw "Certificate '$ClientCertificateAlias' does not exist on $Device"
    }

    #EST server CA: pre-load on the device so the first contact is authenticated (bootstrap trust problem)
    $ExistingCAs = @()
    Try {
        $ExistingCAs = @(Get-AxisCertificate -Device $Device -CA)
    }
    Catch {
        Write-Verbose "Could not list CA certificates on $($Device): $_"
    }
    $CaAlias = $null
    if($CACertificate) {
        $CaPem = $null
        if($CACertificate -like "*-----BEGIN*") {
            $CaPem = $CACertificate
        }
        elseif(Test-Path -LiteralPath $CACertificate) {
            $CaPem = [String](Get-Content -LiteralPath $CACertificate -Raw)
        }
        elseif(($ExistingCAs | ForEach-Object { $_.Alias }) -contains $CACertificate) {
            $CaAlias = $CACertificate
        }
        else {
            Throw "'$CACertificate' is neither PEM text, an existing file nor the alias of a CA certificate installed on $Device"
        }

        if($CaPem) {
            $Blocks = @(ConvertFrom-PemString -Pem $CaPem | Where-Object { $_.Label -eq "CERTIFICATE" })
            if($Blocks.Count -eq 0) { Throw "No CERTIFICATE block found in -CACertificate" }
            #Devices reject bundles; the first block is the trust anchor used for the EST server
            $CaPem = $Blocks[0].Pem
            $CaCert = ConvertFrom-PemString -Pem $CaPem -AsCertificate | Select-Object -First 1
            $Present = $ExistingCAs | Where-Object { $_.Thumbprint -eq $CaCert.Thumbprint } | Select-Object -First 1
            if($Present) {
                $CaAlias = $Present.Alias
                Write-Verbose "CA certificate $($CaCert.Thumbprint) already installed as '$CaAlias'; skipping"
            }
            else {
                #Alias from the CN, safe characters only, unique on the device (same scheme as Install-AxisCertificate)
                $CN = $CaCert.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
                if(!$CN) { $CN = $CaCert.Thumbprint }
                $CaAlias = ($CN -replace '[^A-Za-z0-9._-]','-').Trim('-')
                if($CaAlias.Length -gt 120) { $CaAlias = $CaAlias.Substring(0,120) }
                $ExistingAliases = @($ExistingCAs | ForEach-Object { $_.Alias })
                $Base = $CaAlias
                $n = 2
                while($ExistingAliases -contains $CaAlias) {
                    $CaAlias = "$Base-$n"
                    $n++
                }
                Write-Verbose "Installing EST server CA certificate '$CaAlias' ($($CaCert.Thumbprint)) on $Device"
                Try {
                    #Install-AxisCertificate cannot install a CA certificate on its own, so call the certificate API directly
                    $null = Invoke-AxisCertApi -Device $Device -Path "/ca_certificates" -Method POST -Data @{ alias = $CaAlias; certificate = $CaPem }
                }
                Catch {
                    Throw "Unable to install CA certificate '$CaAlias' on $($Device): $_"
                }
            }
        }
    }
    elseif($Authority.CAThumbprint) {
        $Pin = ($Authority.CAThumbprint -replace '[^0-9A-Fa-f]','').ToUpper()
        $Present = $ExistingCAs | Where-Object { $_.Thumbprint -eq $Pin } | Select-Object -First 1
        if($Present) {
            $CaAlias = $Present.Alias
            Write-Verbose "Using installed CA certificate '$CaAlias' (matches authority CAThumbprint)"
        }
    }
    if(!$CaAlias) {
        Throw "No EST server CA certificate available on $Device. Supply -CACertificate (PEM or file) so the device can authenticate the EST server; without it the device would blindly trust the first /cacerts response"
    }

    #Subject / SAN for the CSR the device will generate
    Try {
        $SubjectParam = @{ Device = $Device }
        if($SubjectTemplate) { $SubjectParam.Add('SubjectTemplate',$SubjectTemplate) }
        if($SanTemplate) { $SubjectParam.Add('SanTemplate',$SanTemplate) }
        $SubjectInfo = Get-AxisCertificateSubject @SubjectParam
    }
    Catch {
        Throw "Unable to build the certificate subject for $($Device): $_"
    }
    $CN = $null
    if([String]$SubjectInfo.Subject -match '(?i)(?:^|,)\s*CN=([^,]+)') {
        $CN = $Matches[1].Trim()
    }
    if(!$CN) {
        Throw "Subject '$($SubjectInfo.Subject)' contains no CN; the EST profile only supports a Common Name"
    }
    if($CN.Length -gt 64) {
        Throw "Common Name '$CN' exceeds the 64 character limit of the EST profile"
    }
    $SANs = @($SubjectInfo.SubjectAltNames | Where-Object { $_ -match '^(DNS|IP):.+$' })

    $ProfileData = @{
        id = $ProfileId
        server = $EstServer
        caCertificates = @($CaAlias)
        certificate = $ClientCertificateAlias
        subject = @{ cn = $CN }
        subjectAlternativeNames = $SANs
        services = @($Services)
    }

    #Create or update the profile (collection keyed on id; devices hold at most 2 profiles)
    $Existing = @()
    Try {
        $Response = Invoke-AxisWebApi -Device $Device -Path "$BasePath/profiles"
        if($Response.status -and $Response.status -ne "success") {
            Throw "$($Response.error.message)"
        }
        $Existing = @($Response.data | Where-Object { $_ })
    }
    Catch {
        Throw "Unable to list EST profiles on $($Device): $_"
    }
    $EncodedId = [uri]::EscapeDataString($ProfileId)

    if(($Existing | ForEach-Object { $_.id }) -contains $ProfileId) {
        Write-Verbose "Updating EST profile '$ProfileId' on $Device"
        $Body = $ProfileData.Clone()
        $Body.Remove('id')
        $Param = @{
            Device = $Device
            Path = "$BasePath/profiles/$EncodedId"
            Method = "PATCH"
            Body = @{ data = $Body }
        }
        $Action = "Updated"
    }
    else {
        if($Existing.Count -ge 2) {
            Throw "$Device already holds $($Existing.Count) EST profiles ($(($Existing | ForEach-Object { $_.id }) -join ', ')); remove one with Remove-AxisCertificateEnrollment first"
        }
        Write-Verbose "Creating EST profile '$ProfileId' on $Device (server $EstServer)"
        $Param = @{
            Device = $Device
            Path = "$BasePath/profiles"
            Method = "POST"
            Body = @{ data = $ProfileData }
        }
        $Action = "Created"
    }

    Try {
        $Response = Invoke-AxisWebApi @Param
    }
    Catch {
        Throw "Unable to set EST profile '$ProfileId' on $($Device): $_"
    }
    if($Response.status -and $Response.status -ne "success") {
        $Message = $Response.error.message
        if(!$Message) { $Message = "Unknown error" }
        Throw "Unable to set EST profile '$ProfileId' on $($Device): $Message"
    }

    #Enforce HTTPS (same parameters as Install-AxisCertificate; https://help.axis.com/en-us/axis-os-hardening-guide)
    if($HttpsOnly) {
        $ParamSet = @{
            "System.BoaGroupPolicy.admin" = 'https'
            "System.BoaGroupPolicy.operator" = 'https'
            "System.BoaGroupPolicy.viewer" = 'https'
        }
        Try {
            Update-AxisParameter -Device $Device -ParameterSet $ParamSet
        }
        Catch {
            Throw "EST profile set, but unable to enable HTTPS-only on $($Device): $_"
        }
        Initialize-AxisCache -Device $Device
        $Cache.$Device.Type = "https"
    }

    #Read back the status (UNCONNECTED until the device has talked to the server)
    $Status = $null
    Try {
        $Response = Invoke-AxisWebApi -Device $Device -Path "$BasePath/profiles/$EncodedId/status"
        $Status = [String]$Response.data
    }
    Catch {
        Write-Verbose "Could not read status of EST profile '$ProfileId': $_"
    }
    if(!$Status) { $Status = "UNKNOWN" }

    Write-Log -ID $Device -Message "$Action EST profile '$ProfileId' (server $EstServer, client cert '$ClientCertificateAlias', CA '$CaAlias', services $($Services -join ',')); status $Status"

    [pscustomobject]@{
        Device = $Device
        ProfileId = $ProfileId
        Server = $EstServer
        Status = $Status
    }
}

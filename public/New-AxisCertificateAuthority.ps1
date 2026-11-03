<#
.SYNOPSIS
Adds (or replaces) a certificate authority definition in the AxisPowershell configuration.

.DESCRIPTION
Certificate authorities are the issuers used by Request-AxisCertificate, Invoke-AxisCertificateDeployment and the
provisioning job. Four types are supported:
 - WindowsCA : Microsoft AD CS, reached through the ICertRequest2/ICertAdmin2 COM interfaces (Windows only).
 - Dogtag    : Dogtag PKI / FreeIPA; enrollment through its EST subsystem, revocation through the CA REST API.
 - EST       : any RFC 7030 EST server (OpenXPKI, EJBCA, ...). EST has no revocation; supply -RevokeCommand if needed.
 - Command   : any command line CA such as 'openssl ca', run locally or over SSH.
A template (AD CS template name, EST label, or a token in your command) is always required so the CA controls
the certificate profile. Passwords and tokens are never written to the configuration file: they are stored in the
Windows Credential Manager under 'AxisPowershell-CA-<Name>'.
The authority is tested before it is saved unless -SkipTest is given.

.PARAMETER Name
Short name used to refer to this authority, e.g. "CorpCA".

.PARAMETER Template
WindowsCA: certificate template name. Dogtag/EST: EST label (may be empty string if the server has none).
Command: free text available as {Template} in the command.

.PARAMETER CAConfig
WindowsCA only. The CA config string "host\CA Name" as shown by certutil -dump.

.PARAMETER Server
Dogtag/EST: base URL of the server, e.g. https://pki.example.com:8443.

.PARAMETER Credential
Dogtag/EST: HTTP Basic credential for enrollment (and Dogtag agent revocation unless -RevokeCredential is given).

.PARAMETER RevokeCredential
Dogtag: separate agent credential for revocation.

.PARAMETER ClientCertThumbprint
Dogtag/EST: thumbprint of a client certificate in Cert:\CurrentUser\My for mutual TLS instead of Basic auth.

.PARAMETER CAThumbprint
Dogtag/EST: pin the CA certificate returned by /cacerts to this thumbprint.

.PARAMETER SkipCertificateCheck
Dogtag/EST: do not validate the server's TLS certificate.

.PARAMETER SignCommand
Command: command template. Tokens: {CsrFile} {CertFile} {Device} {Subject} {Template}.

.PARAMETER RevokeCommand
Command/EST: command template for revocation. Tokens: {Serial} {Reason}.

.PARAMETER TestCommand
Command: optional command run by the connectivity test.

.PARAMETER SshHost
Command: run the commands on this host over SSH (uses ssh/scp from the PATH).

.PARAMETER SshUser
Command: SSH user name.

.PARAMETER SshKeyFile
Command: SSH private key file passed to ssh -i.

.PARAMETER KeyTypes
Key algorithms this CA/template accepts, e.g. RSA-2048,RSA-4096 for an RSA-only AD CS template. The camera's
strongest key type within this list is used. Default: any.

.PARAMETER TimeoutSec
How long to wait for issuance (pending approvals, slow commands). Default 300.

.PARAMETER Default
Make this the default authority for Request-AxisCertificate and provisioning.

.PARAMETER SkipTest
Save without running the connectivity test.

.EXAMPLE
New-AxisCertificateAuthority -Name CorpCA -Type WindowsCA -CAConfig "pki01.example.com\Example Issuing CA" -Template AxisCamera -Default

.EXAMPLE
New-AxisCertificateAuthority -Name Dogtag -Type Dogtag -Server https://pki.example.com:8443 -Template cameras -Credential (Get-Credential)

.EXAMPLE
New-AxisCertificateAuthority -Name LabCA -Type Command -Template server_cert -SshHost ca.lab -SshUser ca -SignCommand 'openssl ca -batch -config /etc/pki/ca/openssl.cnf -extensions {Template} -in {CsrFile} -out {CertFile}' -RevokeCommand 'openssl ca -config /etc/pki/ca/openssl.cnf -revoke /etc/pki/ca/newcerts/{Serial}.pem -crl_reason {Reason}'
#>
function New-AxisCertificateAuthority {
    [cmdletbinding(DefaultParameterSetName='WindowsCA')]
    Param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [String]$Name,

        [Parameter(Mandatory)]
        [ValidateSet("WindowsCA","Dogtag","EST","Command")]
        [String]$Type,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String]$Template,

        [Parameter()]
        [String]$CAConfig,

        [Parameter()]
        [String]$Server,

        [Parameter()]
        [PSCredential]$Credential,

        [Parameter()]
        [PSCredential]$RevokeCredential,

        [Parameter()]
        [String]$ClientCertThumbprint,

        [Parameter()]
        [String]$CAThumbprint,

        [Parameter()]
        [Switch]$SkipCertificateCheck,

        [Parameter()]
        [String]$SignCommand,

        [Parameter()]
        [String]$RevokeCommand,

        [Parameter()]
        [String]$TestCommand,

        [Parameter()]
        [String]$SshHost,

        [Parameter()]
        [String]$SshUser,

        [Parameter()]
        [String]$SshKeyFile,

        [Parameter()]
        [ValidateSet("NIST-P384","NIST-P256","RSA-4096","RSA-3072","RSA-2048")]
        [String[]]$KeyTypes,

        [Parameter()]
        [Int]$TimeoutSec=300,

        [Parameter()]
        [Switch]$Default,

        [Parameter()]
        [Switch]$SkipTest
    )

    $Authority = @{
        Type = $Type
        Template = $Template
        TimeoutSec = $TimeoutSec
    }
    if($KeyTypes) {
        #The CA template may only sign some algorithms (an RSA-only AD CS template, for example)
        $Authority.Add("KeyTypes",@($KeyTypes))
    }

    switch($Type) {
        "WindowsCA" {
            if(!$CAConfig) { Throw "WindowsCA requires -CAConfig 'host\CA Name'" }
            $Authority.Add("CAConfig",$CAConfig)
            $Authority.Add("PollSeconds",5)
        }
        { $_ -in "Dogtag","EST" } {
            if(!$Server) { Throw "$Type requires -Server 'https://host:port'" }
            if(!$Credential -and !$ClientCertThumbprint) { Throw "$Type requires -Credential or -ClientCertThumbprint" }
            $Authority.Add("Server",$Server.TrimEnd('/'))
            $Authority.Add("Label",$Template)
            $Authority.Add("SkipCertificateCheck",[bool]$SkipCertificateCheck)
            if($ClientCertThumbprint) { $Authority.Add("ClientCertThumbprint",$ClientCertThumbprint) }
            if($CAThumbprint) { $Authority.Add("CAThumbprint",$CAThumbprint) }
            if($Credential) {
                $Authority.Add("CredentialTarget","AxisPowershell-CA-$Name")
            }
            if($RevokeCredential) {
                $Authority.Add("RevokeCredentialTarget","AxisPowershell-CA-$Name-Revoke")
            }
            if($Type -eq "EST" -and $RevokeCommand) {
                $Authority.Add("RevokeCommand",$RevokeCommand)
            }
        }
        "Command" {
            if(!$SignCommand) { Throw "Command requires -SignCommand" }
            $Authority.Add("SignCommand",$SignCommand)
            if($RevokeCommand) { $Authority.Add("RevokeCommand",$RevokeCommand) }
            if($TestCommand) { $Authority.Add("TestCommand",$TestCommand) }
            if($SshHost) {
                $Authority.Add("SshHost",$SshHost)
                if($SshUser) { $Authority.Add("SshUser",$SshUser) }
                if($SshKeyFile) { $Authority.Add("SshKeyFile",$SshKeyFile) }
            }
        }
    }

    #Secrets go to the credential vault, never to config.json
    if($Credential) {
        $Param = @{
            Target = $Authority.CredentialTarget
            Persist = 'Enterprise'
            Credentials = $Credential
        }
        $null = New-StoredCredential @Param
    }
    if($RevokeCredential) {
        $Param = @{
            Target = $Authority.RevokeCredentialTarget
            Persist = 'Enterprise'
            Credentials = $RevokeCredential
        }
        $null = New-StoredCredential @Param
    }

    if(!$SkipTest) {
        $TestAuthority = $Authority.Clone()
        $TestAuthority.Add("Name",$Name)
        $Result = & "Test-AxisCertificateAuthority$Type" -Authority $TestAuthority
        if(!$Result.Reachable) {
            Throw "Certificate authority test failed: $($Result.Message). Use -SkipTest to save anyway."
        }
        Write-Verbose "Authority test: $($Result.Message)"
    }

    $Config.CertificateAuthorities[$Name] = $Authority
    if($Default -or !$Config.Certificate.DefaultAuthority) {
        $Config.Certificate.DefaultAuthority = $Name
    }

    Write-ModuleConfiguration

    return Get-AxisPSCertificateAuthority -Name $Name
}

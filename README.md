# AxisPowershell

AxisPowershell is a PowerShell module designed to simplify and automate interactions with Axis network devices. This repository provides cmdlets and scripts for device management, configuration, and monitoring.

## Features

- Session or persistent credential cache
- Retrieve and update basic configurations such as IP, DSCP, NTP, and Date/Time
- Create and use recording profiles with onboard SD cards
- Workflow for mass provisioning of devices
- Certificate lifecycle: CA-issued HTTPS certificates with the private key generated and kept on the camera
- Pluggable certificate authorities: Microsoft AD CS, Dogtag PKI, any RFC 7030 EST server, or a command line CA such as `openssl ca`
- Mass apply/renew of certificates with a CSV report, and optional certificate deployment during provisioning

## Compatability
Not every feature can be feasibly tested on every camera. If you have a feature that's not working right, open an issue.

Tested on:
- 6.55.9
- 7.25.1.1
- 8.50.1
- 9.80.78
- 10.6.0
- 11.9.63
- 12.2.62

| Command                       | v6 | v7 | v8 | v9 | v10 | v11 | v12 |
| ----------------------------- | -- | -- | -- | -- | --- | --- | --- |
| Action                        | ❓ | ❓ | ❓ | ❓ | ❓ | ✅ | ❓ |
| Certificate (JSON API, SAN)   | ❌<sup>4</sup> | ❌<sup>4</sup> | ❌<sup>4</sup> | ❌<sup>4</sup> | ❌<sup>4</sup> | ✅<sup>4</sup> | ✅ |
| Certificate (SOAP fallback, no SAN) | ❓<sup>5</sup> | ❓<sup>5</sup> | ❓<sup>5</sup> | ❓<sup>5</sup> | ❓<sup>5</sup> | - | - |
| CertificateEnrollment (EST)   | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅<sup>6</sup> |
| ContinuousRecordingProfile    | ❓ | ✅<sup>2</sup> | ✅ | ✅ | ✅ | ✅ | ✅ |
| Date                          | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| DeviceInfo                    | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| DSCP                          | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| NetworkInfo                   | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| NTPClient                     | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Parameter                     | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| RecordingProfile              | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| RecordingSupport              | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| SDCardStatus                  | ❓ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Snapshot                      | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| StorageOptions                | ✅<sup>3</sup> | ✅<sup>3</sup> | ✅<sup>3</sup> | ✅<sup>3</sup> | ✅<sup>3</sup> | ✅ | ✅ |
| StreamProfile                 | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| StreamStatus                  | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| SupportedResolutions          | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| UserAccount                   | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| ViewStatus                    | ❌<sup>1</sup> | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

<sup>1</sup>: Command works, but disabling views is not supported and "Enabled" returns null

<sup>2</sup>: This version doesn't return the stream profile in my tests...

<sup>3</sup>: In these versions, "As long as possible" MaxAge is listed as 7000 rather than 0

<sup>4</sup>: The JSON Certificate Management API (`/config/rest/cert/v1`) was added in AXIS OS 11.6 and left beta in 11.11.135. It is required for CSRs with Subject Alternative Names, ECC/RSA>2048 keys and keystore (TPM/SE) selection. Firmware older than 11.6 has no JSON API, so the certificate cmdlets fall back to SOAP.

<sup>5</sup>: On firmware older than 11.6 the cmdlets use the SOAP certificate operations (`acertificates:CreateCertificate2`, `tds:GetPkcs10Request`, `tds:LoadCertificates`, ...). The CSR has no SAN and the Pkcs10 operation is not documented by Axis. This path has **not been verified on hardware**.

<sup>6</sup>: Native EST enrollment (`/config/rest/cert-est/v1`) requires AXIS OS 12.9 or later (Axis documents state 12.9 and 12.10; the exact minimum is unverified). Not available on any earlier firmware.

## Installation

Install the latest version of the module from PowerShell Gallery

```powershell
Install-Module -Scope CurrentUser AxisPowershell
Import-Module AxisPowershell
```
>The Import-Module

### Execution Policy
If this is your first time using PowerShell, you may need to enable execution of downloaded scripts. Open a PowerShell window as administrator and run the following

```powershell
Set-ExecutionPolicy Unrestricted
```
Close this window afterwards to avoid conflicts when installing the module.

## Configuration
Before starting work with the module, it's important to do some basic configuration of the module.

### Credentials

The AxisPowershell module uses per-session credentials. To set the credentials for the current session:
```powershell
Set-AxisCredential
```

If you want to save the crednetials between sessions, you can add the ```-StoreCredential``` Parameter to save them:
```powershell
Set-AxisCredential -StoreCredential
```
> The module stores these credentials in the Windows Credential Manager. You can overwrite them by running the command again.

### Module Configuration Options

```powershell
Set-AxisPSConfig -DefaultTimeout 30 -LogLevel Verbose
```

### Certificates

AxisPowershell can replace the camera's self-signed HTTPS certificate with one issued by your own certificate authority, and keep it renewed. The private key is generated **on the camera** and never leaves it; only the CSR travels to the CA. The flow for every device is:

1. Create a key and CSR on the camera (`New-AxisCertificateRequest`)
2. Submit the CSR to the configured CA
3. Install the certificate and the CA chain (`Install-AxisCertificate`)
4. Bind the certificate to the web server (HTTPS)
5. Enforce HTTPS-only (`System.BoaGroupPolicy.*=https`, on by default, see the template)

On renewal the new certificate is installed under a new alias (`<Alias>-<timestamp>`), verified on port 443, and only then is the old certificate removed from the device and revoked on the CA (reason `Superseded`). Firmware 11.6+ uses the JSON certificate API (with SAN); older firmware falls back to SOAP without SAN (see the compatibility notes above).

#### Certificate authorities

An authority is stored in the module configuration with `New-AxisCertificateAuthority`. A template (AD CS template name, EST label, or a token in your command) is always required so the CA controls the certificate profile. Passwords and tokens are not written to the configuration file; they are stored in the Windows Credential Manager under `AxisPowershell-CA-<Name>`. The authority is tested before it is saved unless `-SkipTest` is given.

| Type      | What you need                                                                                 | Revocation                                   |
| --------- | --------------------------------------------------------------------------------------------- | -------------------------------------------- |
| WindowsCA | Microsoft AD CS. `-CAConfig "host\CA Name"` (as shown by `certutil -dump`) and `-Template`. Windows only (ICertRequest2/ICertAdmin2 COM). The caller needs Enroll permission on the template and Request permission on the CA. Pending (CA manager approval) requests are polled until `-TimeoutSec`. | ✅ ICertAdmin2                                |
| Dogtag    | Dogtag PKI / FreeIPA with the EST subsystem. `-Server https://host:8443`, `-Template` (EST label), `-Credential` or `-ClientCertThumbprint`. | ✅ CA REST API (`-RevokeCredential` for a separate agent account) |
| EST       | Any RFC 7030 server (OpenXPKI, EJBCA, ...). `-Server`, `-Template` (EST label, may be empty), `-Credential` or `-ClientCertThumbprint`. Optional `-CAThumbprint` pin and `-SkipCertificateCheck`. | ❌ EST has no revocation; supply `-RevokeCommand` if needed |
| Command   | Any command line CA such as `openssl ca`, run locally or over SSH (`-SshHost`, `-SshUser`, `-SshKeyFile`). `-SignCommand` with tokens `{CsrFile} {CertFile} {Device} {Subject} {Template}`; optional `-TestCommand`. | ✅ with `-RevokeCommand` (tokens `{Serial} {Reason}`) |

`-KeyTypes` restricts the key algorithms offered to a CA (for example `RSA-2048,RSA-4096` for an RSA-only AD CS template); the camera's strongest key type within that list is used. `-Default` makes the authority the default for `Request-AxisCertificate` and provisioning.

```powershell
# Microsoft AD CS
New-AxisCertificateAuthority -Name CorpCA -Type WindowsCA -CAConfig "pki01.example.com\Example Issuing CA" -Template AxisCamera -Default

# Dogtag PKI (EST subsystem)
New-AxisCertificateAuthority -Name Dogtag -Type Dogtag -Server https://pki.example.com:8443 -Template cameras -Credential (Get-Credential)

# Generic EST server
New-AxisCertificateAuthority -Name EstCA -Type EST -Server https://est.example.com -Template cameras -Credential (Get-Credential) -CAThumbprint 0F...

# Command line CA over SSH
New-AxisCertificateAuthority -Name LabCA -Type Command -Template server_cert -SshHost ca.lab -SshUser ca -SignCommand 'openssl ca -batch -config /etc/pki/ca/openssl.cnf -extensions {Template} -in {CsrFile} -out {CertFile}' -RevokeCommand 'openssl ca -config /etc/pki/ca/openssl.cnf -revoke /etc/pki/ca/newcerts/{Serial}.pem -crl_reason {Reason}'
```

List or remove authorities with `Get-AxisPSCertificateAuthority` and `Remove-AxisPSCertificateAuthority -Name LabCA` (removing also deletes the stored credential; issued certificates are not affected).

#### Certificate template

The template controls how certificates are requested for every device. Show it with `Get-AxisPSCertificateTemplate` and change it with `Set-AxisPSCertificateTemplate` (only the parameters supplied are changed).

| Setting          | Default          | Notes                                                                                                   |
| ---------------- | ---------------- | ------------------------------------------------------------------------------------------------------- |
| DefaultAuthority |                  | Authority used when none is specified                                                                   |
| SubjectTemplate  | `CN={FQDN}`      | Tokens: `{Hostname}` `{DNSSuffix}` `{FQDN}` `{IP}` `{Serial}` `{MAC}` `{Model}`                          |
| SanTemplate      | `DNS:{FQDN}`     | Additional SAN entries, prefixed with `DNS:` or `IP:`. The SAN always contains the DNS name used as CN  |
| IncludeIP        | `False`          | `-IncludeIP` adds `IP:{IP}` to the SAN, `-ExcludeIP` removes it again                                   |
| KeyType          | `Auto`           | Strongest key the camera (and the CA's `-KeyTypes`) supports, in the order NIST-P384, NIST-P256, RSA-4096, RSA-3072, RSA-2048 |
| Keystore         | `Auto`           | Prefers hardware (TPM0/SE0); or TEE, SOFTWARE0                                                          |
| Alias            | `AxisPowershell` | Certificate alias/ID on the camera                                                                       |
| HttpsOnly        | `True`           | `-EnableHttpsOnly` (default) / `-DisableHttpsOnly` leaves HTTP enabled after install                    |
| RenewWithinDays  | `30`             | Renew certificates expiring within this many days                                                       |

```powershell
Set-AxisPSCertificateTemplate -SubjectTemplate "CN={FQDN},O=Example Inc" -IncludeIP -KeyType RSA-2048
```

#### Single device

`Request-AxisCertificate` runs the whole lifecycle for one device. If the device already has a CA-issued AxisPowershell certificate outside the renewal window, nothing is done (`Action = Current`) unless `-Force` is given. `-NoHttpsOnly` leaves HTTP enabled for this run and `-NoRevoke` keeps the superseded certificate valid on the CA.

```powershell
Request-AxisCertificate -Device 192.168.1.100
Request-AxisCertificate -Device cam-lobby.example.com -CertificateAuthority CorpCA -Force
```

The lower level cmdlets are available too: `Get-AxisCertificate` (`-CA` for the trust store), `New-AxisCertificateRequest`, `Install-AxisCertificate -AssignToHttps -HttpsOnly` and `Remove-AxisCertificate`.

#### Mass apply and renew

`Invoke-AxisCertificateDeployment` runs `Request-AxisCertificate` against many devices in parallel (`-ThrottleLimit`, default 10 to keep the CA responsive). Devices come from `-IP`, `-InputFile` (one device per line, or a CSV with an `IP` or `Device` column) or `-InterfaceIP` (discovery on the local subnet). `-Mode Auto` (default) issues where missing and renews where expiring; `Apply` only touches devices without a CA-issued certificate; `Renew` only devices that already have one. Devices whose certificate is still valid are reported as `Current` and left alone, so the command is safe to run on a schedule for lifecycle management. One result row per device is returned (Device, Action, Alias, Subject, Serial, NotAfter, Thumbprint, HttpsVerified, RevokedSerial, Authority, Message) and `-ReportPath` writes the same rows to a CSV file.

```powershell
Invoke-AxisCertificateDeployment -IP 192.168.1.10,192.168.1.11 -CertificateAuthority CorpCA
Invoke-AxisCertificateDeployment -InputFile .\cameras.csv -Mode Renew -ReportPath .\renewals.csv
```

For example, a weekly scheduled task running `Invoke-AxisCertificateDeployment -InputFile .\cameras.csv -ReportPath .\certs-$(Get-Date -Format yyyyMMdd).csv` renews every certificate within its `RenewWithinDays` window and leaves the rest untouched. Per-device log files are written when logging is enabled (`Set-AxisPSConfig -EnableLogging`).

#### Provisioning

The provisioning job can deploy a certificate as stage 5/8 (after the network stage, so the DNS hostname exists for the subject). It is opt-in and uses the default authority:

```powershell
Set-AxisPSConfig -EnableCertificateProvisioning
Set-AxisPSConfig -DisableCertificateProvisioning
```

On firmware that does not support the certificate API the stage is skipped with a warning and the rest of the job continues.

#### EST hand-off (AXIS OS 12.9+)

Cameras on AXIS OS 12.9 or later can enroll and renew with an EST server by themselves (`/config/rest/cert-est/v1`); the device re-enrolls at 50% of validity. The `Set-`, `Get-` and `Remove-AxisCertificateEnrollment` cmdlets configure that native profile so the camera takes over its own lifecycle and AxisPowershell no longer needs to run renewals. Pre-load the EST server's root CA on the device: the camera trusts the `/cacerts` answer on first contact.

#### Not yet verified on hardware

- SOAP CSR path on firmware older than 11.6 (`tds:GetPkcs10Request`, no SAN)
- Dogtag PKI: implemented from the Dogtag source and docs, no live test yet
- Microsoft AD CS: implemented against the ICertRequest2/ICertAdmin2 documentation, no live test yet

## Usage

Here are some basic commands to try:

```powershell
Get-AxisDeviceInfo -IpAddress 192.168.1.100


Architecture   : aarch64
ProdNbr        : M3088-V
HardwareID     : 932.6
ProdFullName   : AXIS M3088-V Network Camera
Version        : 10.12.91
ProdType       : Network Camera
Soc            : Ambarella CV25
SerialNumber   : B8A44F000000
ProdShortName  : AXIS M3088-V
FWBuildDate    : Aug 15 2022 17:29
NumberofLenses : 1
```

```powershell
Get-AxisSDCardStatus 192.168.1.100


Id          : SD_DISK
Group       : S0
Status      : failed
MaxAge      : 7
TotalSizeGB : 0
FreeSizeGB  : 0
```

## Documentation
Further documentation can be found within Powershell's standard help facilities.
You can get a list of commands by running Get-Command:
```powershell
Get-Command -module AxisPowershell


CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Function        Add-AxisParameter                                  1.2.0      AxisPowershell
Function        Disable-AxisUnusedViews                            1.2.0      AxisPowershell
Function        Enable-AxisDNSUpdate                               1.2.0      AxisPowershell
...
```
Documentation for each command can be found using Get-Help:
```powershell
Get-Help Get-AxisDeviceInfo

NAME
    Get-AxisDeviceInfo

SYNOPSIS
    Retrieves device information from an Axis camera.


SYNTAX
    Get-AxisDeviceInfo [-Device] <String> [<CommonParameters>]


DESCRIPTION
    The Get-AxisDeviceInfo function retrieves device information from an Axis camera using the Axis web API.

```

> This section is not updated with new commands. It is always best to check the module help.

## Requirements

- PowerShell 5.1 or PowerShell 7
- Network access to Axis devices
- Windows for the WindowsCA certificate authority type (AD CS is reached through COM); the other authority types work wherever PowerShell runs

## Contributing

Contributions are welcome! Please open issues or submit pull requests.

## License

This project is licensed under the GPL3 License.

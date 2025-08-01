# AxisPowershell

AxisPowershell is a PowerShell module designed to simplify and automate interactions with Axis network devices. This repository provides cmdlets and scripts for device management, configuration, and monitoring.

## Features

- Session or persistent credential cache
- Retrieve and update basic configurations such as IP, DSCP, NTP, and Date/Time
- Create and use recording profiles with onboard SD cards
- Workflow for mass provisioning of devices

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

Retrieve information about a specific device:



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
Function        Add-AxisParameter                                  0.11.1     AxisPowershell
Function        Disable-AxisUnusedViews                            0.11.1     AxisPowershell
Function        Enable-AxisDNSUpdate                               0.11.1     AxisPowershell
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

- PowerShell 5.1 or later
- Network access to Axis devices

## Contributing

Contributions are welcome! Please open issues or submit pull requests.

## License

This project is licensed under the GPL3 License.
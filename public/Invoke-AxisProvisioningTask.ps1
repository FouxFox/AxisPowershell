<#
.SYNOPSIS
Provisions an Axis device with various configuration options.

.DESCRIPTION
The Provision-AxisDevice function is used to provision a factory default Axis device with various configuration options. 
It supports:
 - Setting the device's password
 - Updating firmware
 - Configuring network settings
 - Enabling DHCP
 - Updating DNS settings
 - Configuring security settings
 - Formatting the SD card.

.PARAMETER Device
Specifies the name or IP address of the Axis device to provision.

.PARAMETER FactoryPrep
Indicates whether to perform factory preparation on the device. If specified, the device's DNS settings and security settings will be updated.

.PARAMETER NewPassword
Specifies the new password to set for the device.

.PARAMETER DHCP
Indicates whether to enable DHCP on the device. If specified and DHCP is not already enabled, the device's IP address will be set to obtain an IP address automatically.

.PARAMETER DNS
Indicates whether to set up Dynamic DNS updates on the device. If specified or FactoryPrep is specified, the device will dynamically update DNS entries.

.PARAMETER SecuritySettings
Indicates whether to configure the security settings on the device. If specified or FactoryPrep is specified, the device's security settings will be configured to best practices.

.PARAMETER SDCard
Indicates whether to format the SD card on the device.

.PARAMETER FirmwareFile
Specifies the path to the firmware file to update on the device.

.EXAMPLE
Provision-AxisDevice -Device "192.168.1.100" -NewPassword "MyNewPassword" -DHCP -DNS -SecuritySettings -SDCard
Provisions the Axis device with the specified IP address, sets a new password, enables DHCP, updates DNS settings, configures security settings, and formats the SD card.

.EXAMPLE
Provision-AxisDevice -Device "AxisDevice01" -FactoryPrep
Provisions the Axis device with the specified name and performs factory preparation, which updates DNS settings and configures security settings.

#>
function Invoke-AxisProvisioningTask {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [String]$MacAddress
    )

    ###########
    ## Begin ##
    ###########
    Write-Log -ID $MacAddress -Message "Starting Job"

    #Get Plaintext password for use in provisioning
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Config.Credential.Password)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

    ##############################
    ## Stage 1: Update Firmware ##
    ##############################
    Write-Verbose "Update Firmware"
    $ProgParam = @{
        Activity = "Perfroming Factory Preparation on $Device..."
        Status = "Stage 1/7: Updating Firmware" 
        PercentComplete = 0
    }
    Write-Progress @ProgParam
    Write-Log -ID $MacAddress -Message "Updating Firmware"
    Try {
        Update-AxisDevice -Device $Device -FactoryDefault -Force
        Write-Log -ID $MacAddress -Message "Successfully Updated Device"
    } Catch {
        Write-Log -ID $MacAddress -Message "Failed to Update Device"
        Write-Log -ID $MacAddress -Message $_.Exception.Message
        Throw $_
    }

    ###########################
    ## Stage 2: Set Password ##
    ###########################
    Write-Verbose "New Password"
    $ProgParam = @{
        Activity = "Perfroming Factory Preparation on $Device..."
        Status = "Stage 2/7: Setting Password" 
        PercentComplete = 16
    }
    Write-Progress @ProgParam
    Write-Log -ID $MacAddress -Message "Checking Device State"

    #Check Device state
    $PasswordAlreadySet = $false
    Try {
        $PasswordAlreadySet = (Get-AxisDeviceStatus -Device $Device).Status -eq "Ready"
        Write-Log -ID $MacAddress -Message "Device has already had password set"
    } Catch {
        Write-Log -ID $MacAddress -Message "Device in Factory default state"
    }

    #Set password if not already set
    if(!$PasswordAlreadySet) {
        #Send to device
        Try {
            Initialize-AxisDevice -Device $Device -NewPassword $PlainPassword
            Write-Log -ID $MacAddress -Message "Successfully set password"
        } Catch {
            Write-Log -ID $MacAddress -Message "Failed to set password"
            Write-Log -ID $MacAddress -Message $_.Exception.Message
            Throw $_
        }
    }

    #################################
    ## Stage 3: Set Network Config ##
    #################################
    Write-Verbose "Set Network Settings"
    $ProgParam = @{
        Activity = "Perfroming Factory Preparation on $Device..."
        Status = "Stage 3/7: Set Network Configuration" 
        PercentComplete = 33
    }
    Write-Progress @ProgParam
    Write-Log -ID $MacAddress -Message "Setting DNS Hostname"
    Try {
        Enable-AxisDNSUpdate -Device $Device
        Write-Log -ID $MacAddress -Message "Successfully set DNS Hostname"
    } Catch {
        Write-Log -ID $MacAddress -Message "Failed to set DNS Hostname"
        Write-Log -ID $MacAddress -Message $_.Exception.Message
        Throw $_
    }

    Write-Log -ID $MacAddress -Message "Setting DSCP values"
    Try {
        Set-AxisDSCP -Device $Device
        Write-Log $MacAddress -Message "Successfully set DSCP values"
    } Catch {
        Write-Log -ID $MacAddress -Message "Failed to set DSCP values"
        Write-Log -ID $MacAddress -Message $_.Exception.Message
        Throw $_
    }

    ##################################
    ## Stage 4: Set Security Config ##
    ##################################
    Write-Verbose "Applying Security Best Practices"
    $ProgParam = @{
        Activity = "Perfroming Factory Preparation on $Device..."
        Status = "Stage 4/7: Applying Security Best Practices" 
        PercentComplete = 50
    }
    Write-Progress @ProgParam
    Write-Log -ID $MacAddress -Message "Setting Security Settings"
    Try {
        Set-AxisServices -Device $Device
        Write-Log -ID $MacAddress -Message "Successfully set security settings"
    } Catch {
        Write-Log -ID $MacAddress -Message "Failed to set security settings"
        Write-Log -ID $MacAddress -Message $_.Exception.Message
        Throw $_
    }

    #############################
    ## Stage 5: Format SD Card ##
    #############################
    Write-Verbose "Formatting SD Card"
    $ProgParam = @{
        Activity = "Perfroming Factory Preparation on $Device..."
        Status = "Stage 5/7: Formatting SD Card" 
        PercentComplete = 67
    }
    Write-Progress @ProgParam
    Write-Log -ID $MacAddress -Message "Formatting SD Card"
    Try {
        Format-AxisSDCard -Device $Device -Wait -NoProgress -EncryptionKey $PlainPassword
        Write-Log -ID $MacAddress -Message "Successfully formatted SD Card"
    } Catch {
        Write-Log -ID $MacAddress -Message "Failed to format SD Card"
        Write-Log -ID $MacAddress -Message $_.Exception.Message
        Throw $_
    }

    Start-Sleep -Seconds 10

    Write-Log -ID $MacAddress -Message "setting retention"
    Try {
        Set-AxisStorageOptions -Device $Device
        Write-Log -ID $MacAddress -Message "Successfully set retention"
    } Catch {
        Write-Log -ID $MacAddress -Message "Failed to set retention"
        Write-Log -ID $MacAddress -Message $_.Exception.Message
        Throw $_
    }

    #################################
    ## Stage 6: Set Edge Recording ##
    #################################
    Write-Verbose "Creating Edge Recording Profile"
    $ProgParam = @{
        Activity = "Perfroming Factory Preparation on $Device..."
        Status = "Stage 6/7: Creating Edge Recording Profile" 
        PercentComplete = 84
    }
    Write-Progress @ProgParam
    Write-Log -ID $MacAddress -Message "Creating Edge Recording Profile"

    Try {
        $StreamParams = "videocodec=h265&videozstrength=20&videozgopmode=dynamic&videozprofile=storage"
        New-AxisStreamProfile -Device $Device -Name "EdgeRecording" -Parameters $StreamParams
        Write-Log -ID $MacAddress -Message "Successfully created Stream Profile"
    } Catch {
        Write-Log -ID $MacAddress -Message "Failed to create Stream Profile"
        Write-Log -ID $MacAddress -Message $_.Exception.Message
        Throw $_
    }

    Try {
        New-AxisRecordingProfile -Device $Device -StreamProfile "EdgeRecording"
        Write-Log -ID $MacAddress -Message "Successfully created Continuious Recording Profile"
    } Catch {
        Write-Log -ID $MacAddress -Message "Failed to create Continuious Recording Profile"
        Write-Log -ID $MacAddress -Message $_.Exception.Message
        Throw $_
    }

    ###############################
    ## Stage 7: Getting Snapshot ##
    ###############################
    Write-Verbose "Getting snapshot from camera"
    $ProgParam = @{
        Activity = "Perfroming Factory Preparation on $Device..."
        Status = "Stage 7/7: Getting Snapshot from camera" 
        PercentComplete = 84
    }
    Write-Progress @ProgParam
    Write-Log -ID $MacAddress -Message "Getting Snapshot from camera"
    Try {
        Get-AxisSnapshot -Device $Device -Path $Config.ProvisioningSnapshotPath -FileName $MacAddress
        Write-Log -ID $MacAddress -Message "Successfully created snapshot from camera"
    } Catch {
        Write-Log -ID $MacAddress -Message "Failed to create snapshot from camera"
        Write-Log -ID $MacAddress -Message $_.Exception.Message
        Throw $_
    }

    ##############
    ## Complete ##
    ##############
    $ProgParam = @{
        Activity = "Perfroming Factory Preparation on $Device..."
        Status = "Done" 
        PercentComplete = 100
    }
    Write-Progress @ProgParam
    Write-Log -ID $MacAddress -Message "Provisioning Complete"

    #Dealloc sensitive data
    Remove-Variable -Name PlainPassword -ErrorAction SilentlyContinue
}
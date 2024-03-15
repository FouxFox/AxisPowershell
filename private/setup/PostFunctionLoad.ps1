#Content here runs after all functions are loaded
$Cache = @{}

if($Env:ModuleTools_TestMode -ne 1) {
    $ModuleVersion = $Script:ModuleData.ModuleVersion
    $SchemaVersion = Get-ModuleSchemaVersion -Version $ModuleVersion -ErrorAction Stop
    $Script:ConfigLocation = "$($env:APPDATA)\.powershell\AxisPowershell\config.json"
    $Script:BackupConfigLocation = $Script:ConfigLocation.Replace('.json','.1.json')
    $script:Config = $null
    $FirstRun = $false

    $DefaultConfig = Get-Content -Path "$PSScriptRoot\config.default.json" | ConvertFrom-Json | ConvertTo-HashTable
        
    if(!(Test-Path -Path $Script:ConfigLocation.Replace('\config.json',''))) {
        Try {
            New-Item -ItemType Directory -Path $Script:ConfigLocation.Replace('\config.json','')
        }
        Catch {
            Throw $_
        }
    }
    if (!(Test-Path -Path $Script:ConfigLocation)) {
        #Config file is missing, Write a new one.
        Try {
            $Script:Config = $DefaultConfig
            Write-ModuleConfiguration
            $FirstRun = $true
        }
        Catch {
            Throw $_
        }
    }

    #Load Config File
    $ConfigLoaded = $false
    $BackupConfig
    if ((Test-Path -Path $ConfigLocation)) {
        Try {
            Read-ModuleConfiguration
            $ConfigLoaded = $true
        }
        Catch {
            Write-Warning "ERROR: Primary Configuration file is corrupt!"
            Write-Warning "Retrieving safemode child program parameters..."
        }
    }

    if(!$ConfigLoaded) {
        Try {
            Read-ModuleConfiguration -ConfigFilePath $Script:BackupConfigLocation
            Write-Warning "Retrieved."

            $Message = "The Primary Configuration located at '{0}' is corrupt. Answering 'Yes' will overwrite the the Primary SPMT Configuration file with the configuration file located at '{1}'. Answering 'No' will leave the files intact and finish loading the module."
            $OverwriteMessage = $Message -f $Script:ConfigLocation,$Script:BackupConfigLocation
            Write-SPMTConfiguration -OverwriteMessage $OverwriteMessage
            $ConfigLoaded = $true
        }
        Catch {
            Write-Warning "ERROR: Secondary Configuration file could not be loaded!"
            Write-Warning "ERROR: Module Load failed!"
            Throw "Could not load configuration file. Please remove/repair configuration files stored at $($Script:ConfigLocation.Replace('config.json',''))"
        }
    }

    #Check if Schema version has changed
    $SchemaUpdateCondition = (
        !$Script:Config.ContainsKey('SchemaVersion') -or 
        $Script:Config.SchemaVersion -lt $SchemaVersion
    )
    if($SchemaUpdateCondition) {
        Update-ModuleConfiguration
    }

    Try {
        $Script:Config.Credential = Get-StoredCredential -Target "AxisPowershell"
    }
    Catch {
        Write-Verbose "No stored credentials found."
    }
    #Turn off certificate checking
    #Moved this to Invoke-AxisWebApi
    #Set-CertificateValidation -Disable
}

# Cleanup
$OnRemoveScript = {}
$ExecutionContext.SessionState.Module.OnRemove += $OnRemoveScript
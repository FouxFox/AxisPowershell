Function Write-ModuleConfiguration {
    [cmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact='high'
    )] 
    Param(
        [Parameter(Mandatory=$false)]
        [string]$ConfigFilePath=$Script:ConfigLocation,

        [Parameter(Mandatory=$false)]
        [string]$OverwriteMessage
    )

    #Message Setup
    $SPDescription = "Configuration Modification"
    $SPWarning = "Are you sure you want to do this?"
    $SPCaption = $OverwriteMessage

    #In certain situations it may be necessary to overwrite a configuration file when a user is not
    # expecting to do this. '-OverwriteMessage' allows us to run with ShouldProcess
    # and ask the user if this is something we want to do.
    #If '-OverwriteMessage' is not specified, the configuration is saved normally.
    $Answer = $false
    if($OverwriteMessage) {
        $Answer = $PSCmdlet.ShouldProcess($SPDescription,$SPWarning,$SPCaption)
    }

    if(!$OverwriteMessage -or $Answer) {
        #Sanatize the Credential
        $ConfigToWrite = Copy-Config
        if($ConfigToWrite.ContainsKey('Credential')) {
            $ConfigToWrite.Credential = ''
        }
        $ConfigToWrite | ConvertTo-Json -Depth 5 | Out-File -FilePath $ConfigFilePath -Force -Confirm:$false
    }
}
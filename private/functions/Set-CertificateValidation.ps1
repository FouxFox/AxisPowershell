function Set-CertificateValidation {
    [cmdletbinding()]
    Param(
        #[Parameter(Mandatory,ParameterSetName='Enable')]
        #[Switch]$Enable,

        [Parameter(Mandatory,ParameterSetName='Disable')]
        [Switch]$Disable
    )

    if ($Enabled) {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    }
    if ($Disabled) {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$false}
    }
}
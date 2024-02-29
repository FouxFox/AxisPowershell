#Lovingly borrowed from https://github.com/PowerShell/PowerShellGet
Function ThrowError {
    Param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionMessage,

        [System.Object]
        $ExceptionObject,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorCategory]
        $ErrorCategory
    )

    $Exception = New-Object $ExceptionName $ExceptionMessage;
    $ErrorRecord = New-Object System.Management.Automation.ErrorRecord $Exception, $ErrorId, $ErrorCategory, $ExceptionObject
    $CallerPSCmdlet.ThrowTerminatingError($ErrorRecord)
}
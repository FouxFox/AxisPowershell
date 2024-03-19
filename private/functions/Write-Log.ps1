function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ID,

        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    if(!$Config.LogEnabled) {
        return
    }

    $LogPath = $Config.LogPath
    $LogMessage = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - [$ID] $Message"
    Add-Content -Path $LogPath -Value $LogMessage
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ID,

        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [string]$LogPath = $Config.LogPath
    )

    if(!$Config.LogEnabled) {
        return
    }

    $LogMessage = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - [$ID] $Message"
    Add-Content -Path "$((Resolve-Path $LogPath).Path)\$($ID).txt" -Value $LogMessage
}

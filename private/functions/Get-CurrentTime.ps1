function Get-CurrentTime {
    [cmdletBinding()]
    Param()

    Try {
        $utcTimeString = (Invoke-RestMethod -Uri "https://www.timeapi.io/api/Time/current/zone?timeZone=UTC").dateTime
        return [datetime]::Parse($utcTimeString)
    } Catch {
        Write-Warning "Unable to get current time from timeapi.io; using system time instead."
        return (Get-Date).ToUniversalTime()
    }
}
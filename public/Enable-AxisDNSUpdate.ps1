function Enable-AxisDNSUpdate {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$true)]
        [String]$Hostname
    )

    #Update Configuration
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=update&Network.DNSUpdate.DNSName=$Hostname&Network.DNSUpdate.Enabled=yes"
    }

    Write-Host "$($Device): Setting Configuration..." -NoNewline
    Try {
        $null = Invoke-AxisWebApi @Param 
        Write-Host -ForegroundColor Green "OK!"
    } Catch {
        Write-Host -ForegroundColor Red "Failed!"
        Throw
    }
    
    #Force DNS Update
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/dnsupdate.cgi?add=$Hostname&hdgen=yes"
        Method = "Get"
    }
    
    Write-Host "$($Device): Forcing DNS Update..." -NoNewline
    Try {
        $null = Invoke-AxisWebApi @Param 
        Write-Host -ForegroundColor Green "OK!"
    } Catch {
        Write-Host -ForegroundColor Red "Failed!"
        Throw
    }
}
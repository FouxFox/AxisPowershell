$AxisSecurityParamGroups = @(
    'Network'
    'WebService.DiscoveryMode.Discoverable'
    'WebService.UsernameToken.ReplayAttackProtection'
    'RemoteService.Enabled'
    'System.EditCgi'
    'System.PreventDoSAttack'
    'System.AccessLog'
    'System.BoaProtViewer'
    'System.BoaGroupPolicy'
    'System.HTTPServerTokens'
    'HTTPS'
    'PTZ.BoaProtPTZOperator'
    'System.WebInterfaceDisabled'
    #'Audio.A*.Enabled'
    #'Storage.S0.Enabled'
)

$AxisSecuritySettings = [ordered]@{
    #Default
    "Brute Force Protection" = @{
        Parameters = @(
            @{
                Name = "System.PreventDoSAttack.ActivatePasswordThrottling"
                HardenedValue = 'on'
            }
            @{
                Name = "System.PreventDoSAttack.DoSBlockingPeriod"
                HardenedValue = '10'
            }
            @{
                Name = "System.PreventDoSAttack.DoSPageCount"
                HardenedValue = '20'
            }
            @{
                Name = "System.PreventDoSAttack.DoSPageInterval"
                HardenedValue = '1'
            }
            @{
                Name = "System.PreventDoSAttack.DoSSiteCount"
                HardenedValue = '20'
            }
            @{
                Name = "System.PreventDoSAttack.DoSSiteInterval"
                HardenedValue = '1'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Default'
    }
    "ONVIF Replay Protection" = @{
        Parameters = @(
            @{
                Name = "WebService.UsernameToken.ReplayAttackProtection"
                HardenedValue = 'yes'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Default'
    }
    "Disable Anonymous Access" = @{
        Parameters = @(
            @{
                Name = "Network.RTSP.ProtViewer"
                HardenedValue = 'password'
            }
            @{
                Name = "System.BoaProtViewer"
                HardenedValue = 'password'
            }
            @{
                Name = "PTZ.BoaProtPTZOperator"
                HardenedValue = 'password'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Default'
    }
    "CGI Editor" = @{
        Parameters = @(
            @{
                Name = "System.EditCgi"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Basic'
    }
    "Web Access Protocol" = @{
        Parameters = @(
            @{
                Name = "System.BoaGroupPolicy.admin" #https|http|both
                HardenedValue = 'https'
            }
            @{
                Name = "System.BoaGroupPolicy.operator" #https|http|both
                HardenedValue = 'https'
            }
            @{
                Name = "System.BoaGroupPolicy.viewer" #https|http|both
                HardenedValue = 'https'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Default'
    }

    #Basic
    "Access Log" = @{
        Parameters = @(
            @{
                Name = "System.AccessLog"
                HardenedValue = 'On'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Basic'
    }
    "Arp/Ping" = @{
        Parameters = @(
            @{
                Name = "Network.ARPPingIPAddress.Enabled"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Basic'
    }
    "Bonjour" = @{
        Parameters = @(
            @{
                Name = "Network.Bonjour.Enabled"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Basic'
    }
    "Disable Web UI" = @{
        Parameters = @(
            @{
                Name = "System.WebInterfaceDisabled"
                HardenedValue = 'yes'
            }
        )   
        SecuritySet = 'Aggressive'
        AxisHardeningSet = 'Basic'
    }
    "FTP" = @{
        Parameters = @(
            @{
                Name = "Network.FTP.Enabled"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Basic'
    }
    "O3C" = @{
        Parameters = @(
            @{
                Name = "RemoteService.Enabled"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Basic'
    }
    "Server Headers" = @{
        Parameters = @(
            @{
                Name = "System.HTTPServerTokens"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Basic'
    }
    "SSH" = @{
        Parameters = @(
            @{
                Name = "Network.SSH.Enabled"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Basic'
    }
    "TLS Versions" = @{
        Parameters = @(
            @{
                Name = "HTTPS.AllowSSLV3"
                HardenedValue = 'no'
            }
            @{
                Name = "HTTPS.AllowTLS1"
                HardenedValue = 'no'
            }
            @{
                Name = "HTTPS.AllowTLS11"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Basic'
    }
    "UPnP" = @{
        Parameters = @(
            @{
                Name = "Network.UPnP.Enabled"
                HardenedValue = 'no'
            }
            @{
                Name = "Network.UPnP.NATTraversal.Enabled"
                HardenedValue = 'no'
            }
        )  
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Basic'
    }
    "WS-Discovery" = @{
        Parameters = @(
            @{
                Name = "WebService.DiscoveryMode.Discoverable"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Basic'
    }
    "ZeroConf" = @{
        Parameters = @(
            @{
                Name = "Network.ZeroConf.Enabled"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Basic'
    }

    #Extended
    "RTSPS" = @{
        Parameters = @(
            @{
                Name = "Network.RTSPS.AllowClientTransportSettings"
                HardenedValue = 'yes'
            }
            @{
                Name = "Network.RTSPS.Enabled"
                HardenedValue = 'yes'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Extended'
    }
    #Moving HTTPS Ciphers to it's own set of commmands due to amount of information that can be stored.
    <#
    HttpsCiphers = @{
        Parameters = @(
            @{
                Name = "HTTPS.Ciphers"
                HardenedValue = 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305'
            }
        )   
        SecuritySet = 'Standard'
        AxisHardeningSet = 'Basic'
    }
    #>
}
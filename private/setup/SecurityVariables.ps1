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

enum SecuritySet {
    Standard  = 1
    DoNotUse = 99 #Ensures that we don't apply these settings as part of module best practices
}

enum AxisHardeningTier {
    Default  = 0
    Basic    = 1
    Extended = 2
}

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
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Default'
    }
    "ONVIF Replay Protection" = @{
        Parameters = @(
            @{
                Name = "WebService.UsernameToken.ReplayAttackProtection"
                HardenedValue = 'yes'
            }
        )   
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Default'
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
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Default'
    }
    "CGI Editor" = @{
        Parameters = @(
            @{
                Name = "System.EditCgi"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Basic'
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
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Default'
    }

    #Basic
    "Access Log" = @{
        Parameters = @(
            @{
                Name = "System.AccessLog"
                HardenedValue = 'On'
            }
        )   
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Basic'
    }
    "Arp/Ping" = @{
        Parameters = @(
            @{
                Name = "Network.ARPPingIPAddress.Enabled"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Basic'
    }
    "Bonjour" = @{
        Parameters = @(
            @{
                Name = "Network.Bonjour.Enabled"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Basic'
    }
    "FTP" = @{
        Parameters = @(
            @{
                Name = "Network.FTP.Enabled"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Basic'
    }
    "O3C" = @{
        Parameters = @(
            @{
                Name = "RemoteService.Enabled"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Basic'
    }
    "Server Headers" = @{
        Parameters = @(
            @{
                Name = "System.HTTPServerTokens"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Basic'
    }
    "SSH" = @{
        Parameters = @(
            @{
                Name = "Network.SSH.Enabled"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Basic'
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
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Basic'
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
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Basic'
    }
    #Web UI has it's own set of commands
    "Web UI Disabled" = @{
        Parameters = @(
            @{
                Name = "System.WebInterfaceDisabled"
                HardenedValue = 'yes'
            }
        )   
        SecuritySet = [SecuritySet]'DoNotUse'
        AxisHardeningSet = [AxisHardeningTier]'Basic'
    }
    "WS-Discovery" = @{
        Parameters = @(
            @{
                Name = "WebService.DiscoveryMode.Discoverable"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Basic'
    }
    "ZeroConf" = @{
        Parameters = @(
            @{
                Name = "Network.ZeroConf.Enabled"
                HardenedValue = 'no'
            }
        )   
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Basic'
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
        SecuritySet = [SecuritySet]'Standard'
        AxisHardeningSet = [AxisHardeningTier]'Extended'
    }

    #Moving HTTPS Ciphers to it's own set of commmands due to amount of information that can be stored.
    
    "Https Ciphers" = @{
        Parameters = @(
            @{
                Name = "HTTPS.Ciphers"
                HardenedValue = 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305'
            }
        )   
        SecuritySet = [SecuritySet]'DoNotUse'
        AxisHardeningSet = [AxisHardeningTier]'Basic'
    }    
}